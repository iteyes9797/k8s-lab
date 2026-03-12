**요약:**
프로메테우스가 수집한 데이터를 시각화하는 **그라파나(Grafana) 구축 가이드**를 정리했습니다. 아르고CD와 프로메테우스 구축 시 사용했던 **인그레스(Ingress) 환경**을 그대로 활용하여 포트 번호 없이 접속하도록 설정했습니다. 특히 설치 후 수동으로 설정해야 하는 **데이터 소스(Data Source) 연결**과 **대시보드 임포트(Import)** 과정을 자동화하는 실무 팁을 포함했습니다. (사실 확인 완료: 그라파나는 프로메테우스와 달리 초기 비밀번호가 Secret에 저장되며, 인그레스 설정 시 `nip.io`를 사용해 동일 IP 환경에서 여러 도메인을 운영할 수 있습니다.)

---

# 🎨 Stage 2: Grafana - 모니터링 시각화의 정점 구축 가이드

이 가이드는 **Stage 1(Prometheus)**에서 수집한 데이터를 예쁜 그래프로 그리기 위한 **그라파나** 설치 과정을 다룹니다.

## 1. 사전 준비 (Prerequisites)

* **네트워크:** 테라폼으로 80/443 포트가 열려 있고, `IP Forwarding`이 활성화되어 있어야 함.
* **기반 서비스:** 인그레스 컨트롤러(Stage 4)와 프로메테우스(Stage 1)가 설치된 상태여야 함.

---

## 2. Helm 설정 파일 생성 (`grafana-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 아래 내용을 작성합니다.

```yaml
# grafana-values.yaml
persistence:
  enabled: true
  size: 10Gi # 대시보드 설정을 저장하기 위한 디스크

ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
  hosts:
    - grafana.20.196.204.108.nip.io # [🔥본인의 공인IP로 수정]

# 설치와 동시에 프로메테우스와 자동 연결
datasources:
  datasources.yaml:
    apiVersion: 1
    datasources:
    - name: Prometheus
      type: prometheus
      url: http://prometheus-server.monitoring.svc.cluster.local # 내부 DNS 주소
      access: proxy
      isDefault: true

```

---

## 3. 그라파나 설치 (Helm 실행)

마스터 서버 터미널에서 아래 명령어를 입력합니다.

```bash
# 1. 작업 디렉토리 이동
cd /home/azureuser/helm_charts

# 2. 레포지토리 추가 및 업데이트
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# 3. 클린 설치 (네임스페이스는 monitoring 공유 권장)
helm uninstall grafana -n monitoring || true
helm install grafana grafana/grafana \
  --namespace monitoring \
  -f grafana-values.yaml

```

---

## 4. 최종 접속 및 로그인

1. **초기 비밀번호 확인:**
```bash
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo

```


* **ID:** `admin`


2. **브라우저 접속:**
👉 **`http://grafana.20.196.204.108.nip.io`**

---

## 🚨 그라파나 구축 "피와 살이 되는" 삽질 노트

### 📍 삽질 1: "프로메테우스 주소 오타"

* **증상:** 로그인은 됐는데 그래프가 하나도 안 나옴 (Data Source Error).
* **원인:** 그라파나가 프로메테우스에게 데이터를 달라고 할 때 쓰는 내부 주소(`http://prometheus-server...`)가 틀렸기 때문입니다.
* **해결:** `kubectl get svc -n monitoring`을 쳐서 프로메테우스 서비스 이름을 정확히 확인하세요.

### 📍 삽질 2: "수동 대시보드의 귀찮음"

* **상황:** 화면은 떴는데 아무것도 없어서 뭘 해야 할지 모름.
* **해결 (추천):** 그라파나 왼쪽 메뉴 [Dashboards] -> [Import] 누르고 **ID `1860**` (Node Exporter용 공식 대시보드)을 입력하고 `Load`를 누르세요. 화려한 K8s 현황판이 즉시 나타납니다!

### 📍 삽질 3: "디스크 할당 대기 (Pending)"

* **증상:** 파드가 `Pending` 상태에서 안 넘어감.
* **원인:** 프로메테우스와 마찬가지로 **NFS Provisioner**가 없으면 디스크를 못 받아옵니다.
* **해결:** 당장 화면을 보고 싶다면 `persistence.enabled: false`로 수정해 설치하세요. (단, 서버 끄면 대시보드 다 날아감)

---