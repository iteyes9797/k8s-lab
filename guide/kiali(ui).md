**요약:**
서비스 메시(Istio) 시각화 도구인 **Kiali** 구축 가이드입니다. Kiali는 Istio가 설치된 환경에서 작동하며, 앞서 설치한 **Prometheus, Grafana, Jaeger**와 연동하여 마이크로서비스 간의 통신 구조를 그래프로 보여줍니다. 운영 표준인 **Ingress-Nginx**를 통해 포트 번호 없이 접속하도록 설정합니다.

---

# 🕸️ Stage 4: Kiali - 서비스 메시 시각화 구축 가이드

## 1. 사전 준비 (Prerequisites)

* **Istio:** Kiali는 Istio 서비스 메시의 데이터를 시각화하므로 **Istio가 반드시 설치되어 있어야 함.**
* **Prometheus:** 트래픽 데이터를 가져오기 위해 필수 (Stage 1에서 설치 완료).

## 2. Helm 설정 파일 생성 (`kiali-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# kiali-values.yaml
auth:
  strategy: "anonymous" # 실습용 (로그인 창 없이 바로 접속)

deployment:
  ingress:
    enabled: true
    ingressClassName: nginx
    hosts:
      - kiali.20.196.204.108.nip.io # [본인의 공인IP로 수정]
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"

external_services:
  prometheus:
    url: "http://prometheus-server.monitoring.svc.cluster.local"
  grafana:
    enabled: true
    url: "http://grafana.monitoring.svc.cluster.local"
  tracing:
    enabled: true
    url: "http://jaeger-query.observability.svc.cluster.local"

```

## 3. Kiali 설치 (Helm 실행)

마스터 서버 터미널에서 실행합니다.

```bash
# 1. 레포지토리 추가
helm repo add kiali https://kiali.org/helm-charts
helm repo update

# 2. 설치 (네임스페이스: istio-system)
helm install kiali-server kiali/kiali-server \
  --namespace istio-system --create-namespace \
  -f kiali-values.yaml

```

## 4. 접속 확인

* **URL:** `http://kiali.20.196.204.108.nip.io`
* **확인:** 좌측 메뉴 [Graph]에서 실제 마이크로서비스 간의 실시간 트래픽 흐름 확인.

## 🚨 핵심 삽질 포인트

* **Istio 부재:** Istio가 설치되지 않은 상태에서 Kiali만 띄우면 아무런 그래프가 나오지 않습니다.
* **프로메테우스 연동:** `external_services.prometheus.url` 주소가 정확하지 않으면 "Could not fetch data" 에러가 발생합니다. `kubectl get svc -A`로 정확한 서비스 이름을 확인하세요.
* **Namespace 권한:** Kiali가 타 네임스페이스의 정보를 읽지 못한다면 ClusterRoleBinding 권한 이슈를 확인해야 합니다. (Helm 설치 시 기본 자동 설정됨)

---