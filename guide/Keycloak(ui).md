**요약:**
모든 도구의 통합 로그인(SSO)과 권한 관리를 담당하는 **Keycloak** 구축 가이드입니다. Keycloak은 Java 기반의 무거운 도구이므로 PostgreSQL 데이터베이스와 함께 배포되며, 운영 표준인 **Ingress-Nginx**를 통해 `https` 환경으로 노출하는 것이 필수입니다. (사실 확인 완료: Keycloak 20 이상 버전은 Quarkus 기반으로 동작하며, 프록시 환경에서 `proxy: edge` 설정과 `hostname` 관련 옵션을 정확히 지정해야 인그레스 접속 시 'HTTPS 리다이렉트 무한 루프' 에러를 방지할 수 있습니다.)

---

# 🔑 Stage 13: Keycloak - 통합 인증 및 권한 관리(IAM) 구축 가이드

## 1. 개요

* **역할:** 사용자가 한 번의 로그인으로 ArgoCD, Grafana, Jenkins 등을 모두 이용하게 해주는 **SSO(Single Sign-On)**의 핵심 엔진입니다.
* **특징:** OAuth2, OIDC, SAML 같은 표준 보안 프로토콜을 완벽하게 지원합니다.

---

## 2. Helm 설정 파일 생성 (`keycloak-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다.

```yaml
# keycloak-values.yaml
auth:
  adminUser: admin
  adminPassword: "password123" # [🔥중요] 실제로는 더 복잡하게 설정하세요.

# [🔥핵심] 프록시(Ingress) 환경 설정
proxy: edge # 인그레스가 TLS를 처리할 때 사용하는 모드
hostname: keycloak.20.196.204.108.nip.io # [본인의 공인IP로 수정]

# 내부 데이터베이스(PostgreSQL) 설정
postgresql:
  enabled: true
  auth:
    database: keycloak
    username: bn_keycloak
    password: "db-password"

# 운영 표준 인그레스 설정
ingress:
  enabled: true
  ingressClassName: nginx
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    # Keycloak은 보안상 https로 들어오는 것을 확인해야 합니다.
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
  hostname: keycloak.20.196.204.108.nip.io
  tls: true

```

---

## 3. Keycloak 설치 (Helm 실행)

Bitnami 차트가 설정이 직관적이어서 실무에서 많이 쓰입니다.

```bash
# 1. 헬름 레포지토리 추가
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update

# 2. 설치 (네임스페이스: keycloak)
helm install keycloak bitnami/keycloak \
  --namespace keycloak --create-namespace \
  -f keycloak-values.yaml

```

---

## 4. 최종 접속 및 초기 설정

1. **접속 주소:** `https://keycloak.20.196.204.108.nip.io`
2. **관리자 로그인:** `admin` / `password123` (설정한 비번)
3. **다음 작업:**
* **Realm 생성:** 서비스 그룹(예: 'MyCompany') 생성.
* **Client 생성:** ArgoCD, Grafana 등을 클라이언트로 등록.



---

## 🚨 핵심 삽질 포인트

### 📍 삽질 1: "HTTPS 리다이렉트 무한 루프"

* **증상:** 주소를 치면 무한 로딩 후 '리다이렉트가 너무 많습니다' 에러 발생.
* **원인:** Keycloak은 기본적으로 HTTPS 보안을 강조하는데, 인그레스에서 넘겨주는 신호(`X-Forwarded-Proto`)를 제대로 해석하지 못할 때 발생합니다.
* **해결:** `proxy: edge` 옵션과 인그레스의 `tls: true` 설정이 세트로 맞아야 합니다.

### 📍 삽질 2: "메모리 부족으로 인한 DB 커넥션 에러"

* **상황:** 파드 로그에 `Connection refused`가 뜨면서 Keycloak이 계속 꺼짐.
* **원인:** PostgreSQL이 뜰 때까지 Keycloak이 기다려야 하는데, DS2_v2 사양에서 DB가 뜨는 속도가 느리면 타임아웃이 납니다.
* **해결:** `kubectl get pods -n keycloak -w`로 관찰하며 DB가 먼저 `Running`이 되는지 확인하세요.

### 📍 삽질 3: "비밀번호 분실"

* **상황:** 관리자 비밀번호를 잊어버림.
* **해결:** 헬름으로 설치했다면 Secret에 저장되어 있을 수 있습니다.
```bash
kubectl get secret -n keycloak keycloak -o jsonpath="{.data.admin-password}" | base64 -d; echo

```



---