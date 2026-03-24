**요약:**
클러스터의 '교통 관제탑'이자 서비스 메쉬의 입구인 **Istio IngressGateway** 구축 가이드입니다. 기존 Ingress-Nginx보다 훨씬 강력한 트래픽 제어(A/B 테스트, 카나리 배포)와 보안 기능을 제공합니다. 특히 Azure VM 환경의 제약(로드밸런서 없음)을 극복하기 위해 **NodePort**와 **VirtualService**를 활용한 운영 표준 설정을 적용했습니다.

---

# ⚓ Stage 22: Istio IngressGateway - 서비스 메쉬 관문 구축 가이드

## 1. 개요

* **역할:** 클러스터 외부에서 들어오는 모든 트래픽을 받고, Istio의 '지능형 라우팅' 기능을 통해 각 서비스로 전달합니다.
* **핵심 기능:** 트래픽 분할(7:3 비율 배포 등), TLS 종료, 서킷 브레이커, 분산 트레이싱 연동.

---

## 2. Istio 설치 (Istioctl 기반)

IngressGateway는 Istio의 핵심 컴포넌트입니다. `istioctl` 도구를 사용하여 설치하는 것이 가장 표준적입니다.

```bash
# 1. Istio 다운로드 및 경로 설정 (마스터 서버)
curl -L https://istio.io/downloadIstio | sh -
cd istio-1.21.0 # 버전은 설치 시점에 따라 다를 수 있습니다.
export PATH=$PWD/bin:$PATH

# 2. 'demo' 프로파일로 설치 (Gateway가 포함된 표준 실습용)
istioctl install --set profile=demo -y

# 3. 네임스페이스에 자동 사이드카 주입 설정 (애플리케이션용)
kubectl label namespace default istio-injection=enabled

```

---

## 3. Gateway 및 VirtualService 설정 (핵심)

Istio는 단순히 인그레스를 만드는 게 아니라, **문(Gateway)**과 **안내판(VirtualService)**을 각각 만들어야 합니다.

### 3-1. Gateway 생성 (포트 개방)

**`my-gateway.yaml` 생성 및 적용:**

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: Gateway
metadata:
  name: my-gateway
spec:
  selector:
    istio: ingressgateway # 기본 설치된 게이트웨이 사용
  servers:
  - port:
      number: 80
      name: http
      protocol: HTTP
    hosts:
    - "app.20.196.204.108.nip.io" # [본인의 공인IP로 수정]

```

### 3-2. VirtualService 생성 (라우팅 규칙)

**`my-virtualservice.yaml` 생성 및 적용:**

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: my-app-route
spec:
  hosts:
  - "app.20.196.204.108.nip.io"
  gateways:
  - my-gateway # 위에서 만든 게이트웨이와 연결
  http:
  - route:
    - destination:
        host: my-app-service # 실제 목적지 서비스 이름
        port:
          number: 8080

```

---

## 4. 최종 접속 확인 (Azure 환경 최적화)

Azure VM 환경에서는 `LoadBalancer`가 작동하지 않으므로, 게이트웨이 서비스의 **NodePort**를 확인해야 합니다.

```bash
# 1. 게이트웨이의 NodePort(80에 매핑된 3xxxx 포트) 확인
kubectl get svc istio-ingressgateway -n istio-system

# 2. 접속 테스트 (브라우저 또는 curl)
# 주소창에 http://app.공인IP.nip.io:NodePort 입력

```

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "404 Not Found의 늪"

* **증상:** 게이트웨이 주소로 접속했는데 Istio의 404 에러 화면이 뜸.
* **원인:** Gateway 리소스의 `hosts` 설정과 VirtualService의 `hosts` 설정이 일치하지 않거나, VirtualService에서 Gateway를 참조(`gateways:`)하지 않았을 때 발생합니다.
* **해결:** 두 리소스의 `hosts` 도메인이 정확히 일치하는지, 그리고 네임스페이스가 같은지 확인하세요.

### 📍 삽질 2: "NodePort와 NSG의 충돌"

* **상황:** 포트 번호까지 붙여서 접속했는데 응답 없음.
* **원인:** 테라폼(Stage 1)에서 30000-32767 포트를 열어두지 않았거나, Istio 설치 시 할당된 NodePort가 NSG 규칙에 포함되지 않았을 때 발생합니다.
* **해결:** `kubectl get svc`로 확인한 **정확한 NodePort**를 Azure NSG 인바운드 규칙에 추가해줘야 합니다.

### 📍 삽질 3: "Sidecar Injection 누락"

* **상황:** 모든 라우팅 설정이 맞는데 트래픽이 서비스로 전달되지 않음.
* **원인:** 목적지 서비스(Pod)에 Istio 사이드카(`istio-proxy`)가 주입되지 않으면 Istio의 지능형 라우팅이 작동하지 않습니다.
* **해결:** `kubectl get pods`를 쳤을 때 `READY`가 `2/2`인지 확인하세요. 아니라면 네임스페이스 레이블을 확인하고 파드를 재시작해야 합니다.

---