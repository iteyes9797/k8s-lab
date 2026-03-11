**요약:**
고성능 웹 서버이자 리버스 프록시인 **Nginx**를 정적 콘텐츠 배포용(WEB)으로 구축하는 가이드입니다. 단순히 서버를 띄우는 것을 넘어, **ConfigMap**을 이용해 설정을 관리하고 운영 표준인 **Ingress-Nginx** 및 **cert-manager**와 연동하여 `https` 환경에서 웹 서비스를 제공하도록 구성했습니다. (사실 확인 완료: Nginx는 가벼운 이벤트 기반 구조로 메모리 점유율이 낮아 DS2_v2 환경에 적합하며, 정적 파일 배포 시 `sendfile` 옵션을 활성화하여 성능을 극대화할 수 있습니다.)

언제 무엇을 쓰나요?
일반 Nginx를 쓸 때: * 순수하게 HTML/JS 같은 정적 웹사이트를 띄울 때.
쿠버네티스 외부(VM 등)에서 단순 프록시 서버가 필요할 때.

Ingress Nginx를 쓸 때:
쿠버네티스 클러스터에 배포된 수많은 서비스(ArgoCD, Grafana, API 등)를 **하나의 공인 IP(80/443 포트)**를 통해 도메인별로 나누어 서비스하고 싶을 때.

---

# 🌐 Stage 25: WEB_Nginx - 고성능 웹 서버 및 정적 콘텐츠 배포 가이드

## 1. 개요

* **역할:** HTML, CSS, JS 및 이미지 등 정적 파일을 빠르게 서빙하거나, 백엔드 애플리케이션 앞단의 리버스 프록시 역할을 수행합니다.
* **핵심 이점:** 매우 낮은 리소스 소비, 강력한 캐싱 기능, 유연한 설정 방식.

---

## 2. 웹 페이지 설정 (ConfigMap 생성)

서버에 올릴 `index.html` 파일을 쿠버네티스 설정 파일로 미리 만듭니다.

**`nginx-config.yaml` 생성 및 적용:**

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-web-content
  namespace: web
data:
  index.html: |
    <!DOCTYPE html>
    <html>
    <head><title>Han Yoori's Cloud Web</title></head>
    <body>
      <h1>Nginx Web Server is Running!</h1>
      <p>Provisioned by Gemini AI Collaboration.</p>
    </body>
    </html>

```

```bash
kubectl create namespace web
kubectl apply -f nginx-config.yaml

```

---

## 3. Helm 설정 파일 생성 (`nginx-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# nginx-values.yaml
replicaCount: 1

# [🔥핵심] 위에서 만든 ConfigMap을 웹 경로(/app)에 연결
extraVolumes:
  - name: web-static-content
    configMap:
      name: nginx-web-content
extraVolumeMounts:
  - name: web-static-content
    mountPath: /app

# 운영 표준 인그레스 및 TLS 설정
ingress:
  enabled: true
  hostname: www.20.196.204.108.nip.io # [본인의 공인IP로 수정]
  annotations:
    kubernetes.io/ingress.class: nginx
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  tls: true

```

---

## 4. Nginx 설치 (Helm 실행)

Bitnami 차트를 사용하여 배포합니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. 설치 (네임스페이스: web)
helm install my-nginx bitnami/nginx \
  --namespace web \
  -f nginx-values.yaml

```

---

## 5. 최종 접속 확인

* **URL:** `https://www.20.196.204.108.nip.io`
* **확인:** 브라우저에서 우리가 설정한 "Nginx Web Server is Running!" 문구가 나오는지 확인합니다.

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "403 Forbidden (권한 에러)"

* **증상:** 접속은 되는데 403 에러가 뜸.
* **원인:** Nginx 실행 계정(보안상 비루트 계정인 경우가 많음)이 마운트된 파일에 대한 읽기 권한이 없을 때 발생합니다.
* **해결:** Bitnami 차트는 기본적으로 `/app` 경로를 바라봅니다. `mountPath`를 정확히 설정했는지 확인하세요.

### 📍 삽질 2: "수정한 HTML이 반영되지 않음"

* **상황:** ConfigMap을 수정했는데 웹 페이지는 예전 그대로임.
* **원인:** ConfigMap이 업데이트되어도 실행 중인 파드 내부의 파일은 즉시 갱신되지 않거나, Nginx 프로세스가 새 설정을 불러오지 못했기 때문입니다.
* **해결:** `kubectl rollout restart deployment my-nginx -n web` 명령어로 파드를 재시작하는 것이 가장 확실합니다.

### 📍 삽질 3: "Default Ingress와의 충돌"

* **상황:** 인그레스를 설정했는데 다른 도구(ArgoCD 등)와 주소가 겹쳐서 이상한 곳으로 연결됨.
* **해결:** `hostname`을 고유하게 설정했는지(예: `www.`, `blog.`) 확인하고, 인그레스 규칙의 `path` 우선순위를 체크하세요.

---