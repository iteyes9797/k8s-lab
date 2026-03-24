**요약:**
쿠버네티스에서 동적으로 볼륨을 생성해 주는 **NFS Subdir External Provisioner** 구축 가이드입니다. 이 도구는 `PersistentVolumeClaim(PVC)` 요청이 올 때마다 NFS 서버에 자동으로 폴더를 만들고 볼륨을 연결해 주는 '창고 관리자' 역할을 합니다. (사실 확인 완료: NFS Provisioner가 없으면 모든 DB나 저장소 파드가 `Pending` 상태에서 멈추며, NFS 서버 설정 시 `/etc/exports`에 `no_root_squash` 옵션이 반드시 포함되어야 권한 에러를 방지할 수 있습니다.)

---

# 📂 Stage 23: NFS Provisioner - 동적 스토리지 프로비저닝 가이드

## 1. 사전 작업: NFS 서버 설정 (Master 노드에서 실행)

쿠버네티스 노드 중 하나(주로 마스터)를 실제 데이터가 저장될 NFS 서버로 만듭니다.

```bash
# 1. NFS 패키지 설치
sudo apt update && sudo apt install nfs-kernel-server -y

# 2. 공유 디렉토리 생성 및 권한 설정
sudo mkdir -p /srv/nfs/kubedata
sudo chown nobody:nogroup /srv/nfs/kubedata
sudo chmod 777 /srv/nfs/kubedata

# 3. NFS 설정 파일 수정 (/etc/exports)
# [🔥핵심] no_root_squash 옵션이 있어야 K8s 파드가 파일을 쓸 수 있음
echo "/srv/nfs/kubedata *(rw,sync,no_subtree_check,no_root_squash)" | sudo tee -a /etc/exports

# 4. 서비스 재시작 및 적용
sudo exportfs -ra
sudo systemctl restart nfs-kernel-server

```

---

## 2. Helm 설정 파일 생성 (`nfs-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# nfs-values.yaml
nfs:
  server: 10.0.0.4 # [🔥본인의 마스터 서버 내부 IP로 수정]
  path: /srv/nfs/kubedata
  mountOptions:
    - nfsvers=4

storageClass:
  name: nfs-client # StorageClass 이름
  defaultClass: true # 이 스토리지 클래스를 기본값으로 설정
  archiveOnDelete: false # PVC 삭제 시 데이터를 보관할지 여부

```

---

## 3. NFS Provisioner 설치 (Helm 실행)

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add nfs-subdir-external-provisioner https://kubernetes-sigs.github.io/nfs-subdir-external-provisioner/
helm repo update

# 2. 설치 (네임스페이스: nfs-provisioner)
helm install nfs-provisioner nfs-subdir-external-provisioner/nfs-subdir-external-provisioner \
  --namespace nfs-provisioner --create-namespace \
  -f nfs-values.yaml

```

---

## 4. 작동 확인 (PVC 테스트)

실제로 볼륨이 자동으로 생성되는지 확인합니다.

**`test-pvc.yaml` 생성 및 적용:**

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: test-nfs-pvc
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 1Gi

```

```bash
kubectl apply -f test-pvc.yaml
# STATUS가 'Bound'로 나오면 성공!
kubectl get pvc test-nfs-pvc

```

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "PVC가 계속 Pending 상태예요"

* **원인:** Provisioner 파드가 NFS 서버에 접속하지 못했거나, `nfs-values.yaml`의 IP 주소가 틀린 경우입니다.
* **해결:** `kubectl logs -f <provisioner-pod-name> -n nfs-provisioner`를 확인하여 `Connection refused` 에러가 있는지 체크하세요.

### 📍 삽질 2: "Permission Denied (권한 에러)"

* **원인:** NFS 서버 설정(`exports`)에서 `no_root_squash`를 빼먹었을 때 발생합니다. 쿠버네티스 파드는 보통 root 권한으로 파일을 쓰려 하기 때문에 이 옵션이 없으면 거부당합니다.
* **해결:** 마스터 서버의 `/etc/exports`를 다시 확인하고 `sudo exportfs -ra`를 실행하세요.

### 📍 삽질 3: "모든 노드에 nfs-common 설치 누락"

* **상황:** Provisioner는 잘 떴는데, 실제 앱 파드가 볼륨을 마운트할 때 에러가 남.
* **해결:** **모든 워커 노드**에 NFS 클라이언트 패키지가 설치되어 있어야 합니다.
```bash
sudo apt install nfs-common -y # 모든 노드에서 실행

```



---