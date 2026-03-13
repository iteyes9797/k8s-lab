#!/bin/bash
set -e

# 프로젝트 루트 경로 설정
PROJECT_ROOT=$(pwd)
KUBECONFIG_PATH="$PROJECT_ROOT/k8s_configs/admin.conf"

echo "===================================================="
echo "    K8S-LAB Automated Setup & Provisioning"
echo "===================================================="

# 0. 사전 환경 체크 및 파일 정리
echo ">>> [STEP 0] 사전 환경 준비"
[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
[ ! -f "$PROJECT_ROOT/.vault_pass" ] && echo "iteyes7979!@" > "$PROJECT_ROOT/.vault_pass"
chmod 600 "$PROJECT_ROOT/.vault_pass"

# 1. Terraform 단계: 인프라 배포 및 IP 자동 갱신
echo ">>> [STEP 1] Terraform 리소스 배포"
cd "$PROJECT_ROOT/terraform/live/azure"
terraform init
terraform apply -auto-approve -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

BASTION_IP=$(terraform output -raw bastion_public_ip)
MASTER_IP=$(terraform output -json vm_internal_ips | jq -r '.master1')
echo ">>> Detected IPs - Bastion: $BASTION_IP, Master: $MASTER_IP"

# 2. SSH Config 동적 생성
echo ">>> SSH 관리 환경 자동 동기화 중..."

mkdir -p ~/.ssh
cat <<EOF > ~/.ssh/config
# Bastion Host (대문)
Host bastion
    HostName ${BASTION_IP}
    User azureuser
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null

# 내부 사설망 노드들 (SSH Tunneling 설정)
# k8s-master01 등의 이름으로 접속 시 자동으로 bastion을 경유하도록 함
Host k8s-master* k8s-worker* k8s-lb* k8s-nfs*
    User azureuser
    ProxyJump bastion
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
EOF

chmod 600 ~/.ssh/config
echo ">>> SSH Config가 Bastion IP(${BASTION_IP})로 업데이트되었습니다."

# 인벤토리 파일 내 Bastion IP 자동 갱신 (Ansible용)
sed -i "s/bastion_ip = .*/bastion_ip = $BASTION_IP/g" "$PROJECT_ROOT/ansible/inventories/production/hosts"

# 2. Ansible 단계: K8s 기본 클러스터 구축
echo ">>> [STEP 2] Ansible 클러스터 구축"
cd "$PROJECT_ROOT/ansible"
export ANSIBLE_CONFIG="$PROJECT_ROOT/ansible/ansible.cfg"

python3 -m ansible playbook \
  -i "$PROJECT_ROOT/ansible/inventories/production/hosts" \
  site.yaml \
  --vault-password-file "$PROJECT_ROOT/.vault_pass" \
  --extra-vars "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -W %h:%p -q azureuser@$BASTION_IP\"'"

# 3. Kubeconfig 및 터널링 설정
echo ">>> [STEP 3] 관리 환경 설정 및 인증서 동기화 (Kubeconfig & SSH Tunnel)"

# 기존 터널 정리
TARGET_PID=$(sudo lsof -t -i :6443 || true)
[ ! -z "$TARGET_PID" ] && sudo kill -9 $TARGET_PID && sleep 1

# 1) SSH 터널 재생성
ssh -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -o ServerAliveInterval=60 \
    -f -N -L 6443:${MASTER_IP}:6443 azureuser@${BASTION_IP}

# 2) 서버의 최신 admin.conf 강제 복사 (자동화의 핵심)
# 앤서블이 복사해둔 위치(~/.kube/config)에서 가져옵니다.
mkdir -p "$PROJECT_ROOT/k8s_configs"
scp -o StrictHostKeyChecking=no -o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p azureuser@$BASTION_IP" \
    azureuser@$MASTER_IP:~/.kube/config "$KUBECONFIG_PATH"

# 3) 가져온 파일 자동 최적화
# 서버 IP를 로컬 터널 주소(127.0.0.1)로 변경
sed -i "s/server: https:\/\/[0-9.]*:6443/server: https:\/\/127.0.0.1:6443/g" "$KUBECONFIG_PATH"

# TLS 체크 해제 및 인증서 데이터 삭제 (동적 환경 대응)
sed -i '/certificate-authority-data:/d' "$KUBECONFIG_PATH"
if ! grep -q "insecure-skip-tls-verify: true" "$KUBECONFIG_PATH"; then
    sed -i '/server:/a \    insecure-skip-tls-verify: true' "$KUBECONFIG_PATH"
fi

chmod 600 "$KUBECONFIG_PATH"
export KUBECONFIG="$KUBECONFIG_PATH"

echo ">>> [SUCCESS] 인증서 동기화 및 터널링 완료!"

# 4. 네트워크 및 필수 서비스 설치 (NFS & ArgoCD)
echo ">>> [STEP 4] 네트워크 패치 및 서비스 설치"

# Azure 환경용 Calico MTU 패치 (가장 먼저 수행)
kubectl patch installation default --type=merge -p '{"spec": {"calicoNetwork": {"mtu": 1400}}}' || echo "Calico patch skipped"

# NFS Provisioner 설치
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
helm upgrade --install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  -f "$PROJECT_ROOT/helm/nfs-values.yaml" --namespace nfs-provisioner --create-namespace --wait

# 노드 Ready 대기 및 ArgoCD 설치
kubectl wait --for=condition=Ready nodes --all --timeout=300s
helm repo add argo https://argoproj.github.io/argo-helm
helm upgrade --install argocd argo/argo-cd --namespace argocd --create-namespace --set server.service.type=NodePort --wait

# ArgoCD App 적용
kubectl apply -f "$PROJECT_ROOT/argoCd/main-app.yaml" --namespace argocd

# 5. 파이프라인 연동 및 Harbor 설정 (오늘 추가된 핵심 로직)
echo ">>> [STEP 5] Argo Workflow & Harbor 연동 설정"

# Harbor용 시크릿 생성 (Harbor IP: 10.0.1.12)
kubectl -n argo create secret docker-registry harbor-creds \
  --docker-server=10.0.1.12 \
  --docker-username='admin' \
  --docker-password='iteyes7979!@' \
  --dry-run=client -o yaml | kubectl apply -f -

# SA 권한 부여
kubectl -n argo patch sa argo-workflow -p '{"imagePullSecrets": [{"name": "harbor-creds"}]}'

# 다이어트 버전 Workflow 템플릿 등록
echo ">>> Registering Diet-version Workflow Templates..."
kubectl apply -f "$PROJECT_ROOT/ci-kaniko-workflowtemplate.yaml"
kubectl apply -f "$PROJECT_ROOT/argo-workflow-ci-ver3.yaml"

# 결과 출력
ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}')
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

echo "===================================================="
echo ">>> [SUCCESS] 전체 인프라 배포 완료!"
echo ">>> ArgoCD URL: https://${MASTER_IP}:${ARGOCD_PORT}"
echo ">>> ArgoCD ID: admin"
echo ">>> ArgoCD Password: ${ARGOCD_PWD}"
echo ">>> [Notice] 6443 터널 유지 중. 종료 시 'pkill -f ssh'"
echo "===================================================="