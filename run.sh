#!/bin/bash
set -e

PROJECT_ROOT=$(pwd)

echo "===================================================="
echo "    K8S-LAB Clean-Setup & Provisioning"
echo "===================================================="

# 사전 환경 체크
echo ">>> [Check] 실행 환경 및 필수 키 확인"

# SSH 키가 없으면 자동 생성
[ ! -f ~/.ssh/id_rsa ] && ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# .vault_pass 파일이 없으면 생성
[ ! -f "$PROJECT_ROOT/.vault_pass" ] && echo "iteyes7979!@" > "$PROJECT_ROOT/.vault_pass"

# .vault_pass가 실행 파일로 인식되는 에러 방지
if [ -f "$PROJECT_ROOT/.vault_pass" ]; then
    echo ">>> [Fix] .vault_pass 실행 권한 강제 해제"
    chmod -x "$PROJECT_ROOT/.vault_pass" 
    chmod 600 "$PROJECT_ROOT/.vault_pass" 
fi

# 1. Terraform 단계
echo ">>> [STEP 1] Terraform 리소스 배포"
cd "$PROJECT_ROOT/terraform/live/azure"
terraform init
terraform apply -auto-approve -var="ssh_public_key=$(cat ~/.ssh/id_rsa.pub)"

BASTION_IP=$(terraform output -raw bastion_public_ip)
echo ">>> Detected Bastion IP: $BASTION_IP"

# 2. Ansible 단계
echo ">>> [STEP 2] Ansible 클러스터 구축"
cd "$PROJECT_ROOT/ansible"
export ANSIBLE_CONFIG="$PROJECT_ROOT/ansible/ansible.cfg"

python3 -m ansible playbook \
  -i "$PROJECT_ROOT/ansible/inventories/production/hosts" \
  site.yaml \
  --vault-password-file "$PROJECT_ROOT/.vault_pass" \
  --extra-vars "ansible_ssh_common_args='-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ProxyCommand=\"ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -W %h:%p -q azureuser@$BASTION_IP\"'"

# 3. Kubeconfig 및 Helm 단계
echo ">>> [STEP 3] k8s 관리 환경 설정 및 스토리지 설치"

# 1) 마스터 IP 추출 (LB IP인 110이 아닌 실제 마스터 IP 10을 가져오는지 확인)
MASTER_IP=$(cd "$PROJECT_ROOT/terraform/live/azure" && terraform output -json vm_internal_ips | jq -r '.master1' 2>/dev/null)
echo ">>> Detected Master IP: $MASTER_IP"

# 2-1) 마스터 노드 상태 체크 및 필요 시 초기화
echo ">>> 마스터 노드 설정 확인 중"
ssh -o StrictHostKeyChecking=no -o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p azureuser@$BASTION_IP" \
    azureuser@$MASTER_IP "
    if sudo [ ! -f /etc/kubernetes/admin.conf ]; then 
        echo '!!! admin.conf가 없습니다. 클러스터 초기화를 강제 실행합니다.';
        sudo kubeadm reset -f && \
        sudo kubeadm init --pod-network-cidr=10.244.0.0/16 --cri-socket unix:///var/run/crio/crio.sock;
    else
        echo '>>> admin.conf 확인됨. 초기화를 건너뜁니다.';
    fi
    sudo chmod 644 /etc/kubernetes/admin.conf
    "

# 2-2) SSH 터널링 생성
echo ">>> 6443 포트 점유 확인 및 정리 중"

# 6443 포트를 쓰는 PID가 있다면 강제로 kill
TARGET_PID=$(sudo lsof -t -i :6443 || true)

if [ ! -z "$TARGET_PID" ]; then
    echo ">>> 기존 터널 발견 (PID: $TARGET_PID). 종료 중..."
    sudo kill -9 $TARGET_PID || true
    sleep 1
fi

echo ">>> SSH 터널 생성 시작"
ssh -o StrictHostKeyChecking=no -o ExitOnForwardFailure=yes -o ServerAliveInterval=60 \
    -f -N -L 6443:${MASTER_IP}:6443 azureuser@${BASTION_IP}
echo ">>> 터널 생성 완료!"

# 3) 파일 복사 준비 및 복사 시도
mkdir -p "$PROJECT_ROOT/k8s_configs"
echo ">>> admin.conf 복사 시도"
scp -o StrictHostKeyChecking=no -o ProxyCommand="ssh -o StrictHostKeyChecking=no -W %h:%p azureuser@$BASTION_IP" \
    azureuser@$MASTER_IP:/etc/kubernetes/admin.conf "$PROJECT_ROOT/k8s_configs/admin.conf"

# 4) [수정] Kubeconfig 수정 (더 정확한 정규식으로 127.0.0.1 치환)
echo ">>> admin.conf 주소 치환 중"
sed -i "s/server: https:\/\/[0-9.]*:6443/server: https:\/\/127.0.0.1:6443/g" "$PROJECT_ROOT/k8s_configs/admin.conf"
chmod 600 "$PROJECT_ROOT/k8s_configs/admin.conf"
sed -i '/certificate-authority-data:/d' "$PROJECT_ROOT/k8s_configs/admin.conf"
# insecure 설정이 중복되지 않도록 처리
if ! grep -q "insecure-skip-tls-verify: true" "$PROJECT_ROOT/k8s_configs/admin.conf"; then
    sed -i '/server:/a \    insecure-skip-tls-verify: true' "$PROJECT_ROOT/k8s_configs/admin.conf"
fi

# 5) Helm 설치 실행
export KUBECONFIG="$PROJECT_ROOT/k8s_configs/admin.conf"
echo ">>> NFS Provisioner 설치 시작"
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update
helm upgrade --install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --kubeconfig "$PROJECT_ROOT/k8s_configs/admin.conf" \
  -f "$PROJECT_ROOT/helm/nfs-values.yaml" \
  --namespace nfs-provisioner --create-namespace \
  --wait --timeout 10m0s

# 4. ArgoCD 단계
echo ">>> [STEP 4] ArgoCD 및 GitOps 활성화"

# [핵심 추가] 노드가 Ready가 될 때까지 최대 5분 대기
echo ">>> 노드가 Ready 상태가 될 때까지 대기 중..."
kubectl wait --for=condition=Ready nodes --all --timeout=300s --kubeconfig "$PROJECT_ROOT/k8s_configs/admin.conf"

# ArgoCD 설치
echo ">>> ArgoCD 설치 시작..."
helm upgrade --install argocd argo/argo-cd \
  --kubeconfig "$PROJECT_ROOT/k8s_configs/admin.conf" \
  --namespace argocd --create-namespace \
  --set server.service.type=NodePort \
  --wait --timeout 15m0s # 무거운 설치를 위해 15분 부여

# [중요] ArgoCD CRD가 생성될 때까지 루프로 체크
echo ">>> ArgoCD CRD 상태 확인 중..."
until kubectl get crd applications.argoproj.io --kubeconfig "$PROJECT_ROOT/k8s_configs/admin.conf" >/dev/null 2>&1; do
  echo ">>> CRD가 아직 생성되지 않았습니다. 5초 후 재시도..."
  sleep 5
done

# Main App 적용
echo ">>> GitOps Main Application 적용 중..."
kubectl apply -f "$PROJECT_ROOT/argoCd/main-app.yaml" \
  --kubeconfig "$PROJECT_ROOT/k8s_configs/admin.conf" \
  --namespace argocd

# 설치 완료 후 접속 정보 출력
ARGOCD_PORT=$(kubectl get svc argocd-server -n argocd -o jsonpath='{.spec.ports[?(@.name=="https")].nodePort}' --kubeconfig "$PROJECT_ROOT/k8s_configs/admin.conf")
ARGOCD_PWD=$(kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" --kubeconfig "$PROJECT_ROOT/k8s_configs/admin.conf" | base64 -d)

echo "===================================================="
echo ">>> [SUCCESS] 전체 인프라 배포 완료!"
echo ">>> ArgoCD URL: https://${MASTER_IP}:${ARGOCD_PORT}"
echo ">>> ArgoCD ID: admin"
echo ">>> ArgoCD Password: ${ARGOCD_PWD}"
echo "===================================================="

# SSH 터널은 종료하지 않고 유지
echo ">>> [Notice] 관리용 SSH 터널(6443)이 유지 중입니다. 종료하려면 'pkill -f ssh'를 입력하세요."