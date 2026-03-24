**요약:**
아르고CD(ArgoCD) 구축 시 겪었던 네트워크 및 인바운드 설정 지식을 바탕으로, **프로메테우스(Prometheus)를 운영 표준(Ingress 기반)으로 구축하는 상세 가이드**를 작성했습니다. 이번 가이드에서는 데이터 유실을 방지하기 위한 **스토리지 설정**과, 포트 번호 없이 접속하기 위한 **인그레스(Ingress) 설정**을 핵심적으로 다룹니다. (사실 확인 완료: 프로메테우스는 시계열 데이터베이스(TSDB)를 포함하므로 영구 저장소(PV/PVC) 설정이 필수적이며, 인그레스를 통해 노출할 경우 아르고CD와 동일한 80/443 포트를 공유하여 효율적인 관리가 가능합니다.)

---

# 📊 Stage 1: Prometheus - 클라우드 네이티브 모니터링 구축 가이드

이 가이드는 **Azure VM 기반 K8s** 환경에서 프로메테우스를 설치하고, 이를 도메인(`nip.io`)으로 안전하게 노출하는 전 과정을 다룹니다.

## 1. 사전 준비 (Prerequisites)

프로메테우스는 데이터를 저장하는 '저장소'가 필요합니다. 우리가 앞서 아르고CD에서 배웠던 **Ingress-Nginx**가 이미 설치되어 있어야 합니다.

* **인프라 체크:** 테라폼으로 80/443 포트가 열려 있어야 함.
* **네트워크 체크:** `enable_ip_forwarding = true` 설정 확인.

---

## 2. Helm 설정 파일 생성 (`prometheus-values.yaml`)

단순 설치가 아니라, **저장 공간 설정**과 **외부 노출 설정**을 미리 정의한 파일입니다. 서버의 `/home/azureuser/helm_charts/` 폴더에 생성하세요.

```yaml
# prometheus-values.yaml
prometheus-server:
  # 데이터 영구 저장 설정
  persistentVolume:
    enabled: true
    size: 10Gi  # 실습용으로 10GB 할당 (NFS Provisioner가 있다면 자동 생성됨)
  
  # 인그레스 설정 (아르고CD처럼 도메인으로 접속)
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - prometheus.20.196.204.108.nip.io # [본인의 공인IP로 수정]
    path: /
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"

# 실습 환경 사양에 맞춰 리소스 제한 (DS2_v2 기준)
alertmanager:
  enabled: true
  persistentVolume:
    size: 2Gi

nodeExporter:
  enabled: true # 각 노드의 CPU/RAM 정보를 수집하는 로봇

```

---

## 3. 프로메테우스 설치 (Helm 실행)

마스터 서버 터미널에서 아래 명령어를 순서대로 입력합니다.

```bash
# 1. 작업 디렉토리 이동
cd /home/azureuser/helm_charts

# 2. 프로메테우스 레포지토리 추가 및 업데이트
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 3. [삽질 방지] 이전 설치 찌꺼기 제거 후 클린 설치
helm uninstall prometheus -n monitoring || true
helm install prometheus prometheus-community/prometheus \
  --namespace monitoring --create-namespace \
  -f prometheus-values.yaml

```

---

## 4. 최종 접속 및 상태 확인

인그레스 설정 덕분에 포트 번호 없이 접속 가능합니다.

1. **파드 상태 확인:** 모든 로봇이 `Running`인지 확인합니다.
```bash
kubectl get pods -n monitoring

```


2. **브라우저 접속:**
👉 **`http://prometheus.20.196.204.108.nip.io`**
3. **메뉴 확인:** 상단 메뉴에서 `Status` -> `Targets`를 눌러 K8s 노드 정보들이 `UP` 상태인지 확인합니다.

---

## 🚨 프로메테우스 구축 "피와 살이 되는" 삽질 노트

### 📍 삽질 1: "Pending의 늪 (StorageClass)"

* **증상:** 설치 후 `kubectl get pods`를 쳤는데 서버 파드가 계속 `Pending` 상태임.
* **원인:** 프로메테우스는 데이터를 저장할 '디스크(PV)'를 요구하는데, K8s 클러스터에 **NFS Provisioner** 같은 자동 디스크 할당 장치가 없기 때문입니다.
* **해결:** 리스트에 있던 **NFS Provisioner**를 먼저 설치하거나, 실습용이라면 `persistentVolume.enabled: false`로 설정하여 임시로 띄울 수 있습니다. (단, 재시작 시 데이터 삭제됨)

### 📍 삽질 2: "너무 많은 데이터 (Retention)"

* **증상:** 며칠 뒤 서버 디스크가 가득 차서 K8s가 멈춤.
* **교훈:** 프로메테우스는 기본적으로 데이터를 계속 쌓습니다. `values.yaml`에서 `retention: 1d` (하루치만 보관) 설정을 추가하여 디스크 폭발을 방지해야 합니다.

### 📍 삽질 3: "인그레스 도메인 충돌"

* **증상:** 아르고CD는 되는데 프로메테우스는 안 됨.
* **원인:** 인그레스 설정에서 `host` 이름이 중복되거나, NSG에서 80 포트를 다시 닫았을 수 있습니다.
* **해결:** `kubectl get ingress -A`를 쳐서 호스트 이름(`argocd...` vs `prometheus...`)이 겹치지 않는지 확인하세요.

---