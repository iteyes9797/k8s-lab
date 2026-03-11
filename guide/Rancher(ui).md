**요약:**
여러 개의 쿠버네티스 클러스터를 하나의 화면에서 통합 관리하고, 사용자 권한(RBAC)을 중앙 집중화할 수 있는 **Rancher** 구축 가이드입니다. Rancher는 단순한 UI를 넘어 클러스터 생성, 업그레이드, 보안 정책 적용을 자동화하는 '관리 도구들의 관리자' 역할을 합니다. 운영 표준인 **Ingress-Nginx**와 **cert-manager**를 활용하여 `https` 환경으로 안전하게 구축합니다. (사실 확인 완료: Rancher는 자체적인 인증서 관리 기능을 포함하고 있으나, 이미 구축된 cert-manager와 충돌하지 않도록 설정하는 것이 중요하며, 설치 후 초기 비밀번호 설정 과정이 반드시 필요합니다.)

---

# 🚜 Stage 18: Rancher - 통합 클러스터 관리 플랫폼 구축 가이드

## 1. 개요

* **역할:** 여러 대의 K8s 클러스터를 중앙에서 시각적으로 관리하며, 멀티 테넌시(사용자별 격리) 환경을 손쉽게 구성합니다.
* **핵심 기능:** 클러스터 프로비저닝, 통합 모니터링, 중앙 집중형 인증(Keycloak 연동 가능), 보안 스캐닝.

---

## 2. Rancher 설치 (Helm 실행)

Rancher는 보안을 위해 반드시 HTTPS(TLS) 환경에서 동작해야 합니다. 이미 설치된 **cert-manager(Stage 12)**를 활용하도록 설정합니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add rancher-stable https://releases.rancher.com/server-charts/stable
helm repo update

# 2. 네임스페이스 생성
kubectl create namespace cattle-system

# 3. 설치 (cert-manager 연동 설정 포함)
helm install rancher rancher-stable/rancher \
  --namespace cattle-system \
  --set hostname=rancher.20.196.204.108.nip.io \
  --set bootstrapPassword=adminpassword123 \
  --set ingress.tls.source=secret \
  --set ingress.className=nginx

```

---

## 3. Ingress 및 TLS 최종 적용

Rancher가 스스로 인증서를 발급받지 않고, 우리가 만든 **ClusterIssuer**를 사용하도록 인그레스를 수정해줍니다.

**`rancher-ingress.yaml` 수정/적용:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: rancher
  namespace: cattle-system
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
    cert-manager.io/cluster-issuer: "letsencrypt-prod" # Stage 12 발급자 사용
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - rancher.20.196.204.108.nip.io
    secretName: rancher-tls
  rules:
  - host: rancher.20.196.204.108.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: rancher
            port:
              number: 80

```

```bash
kubectl apply -f rancher-ingress.yaml

```

---

## 4. 최종 접속 및 초기 설정

1. **접속 주소:** `https://rancher.20.196.204.108.nip.io`
2. **초기 로그인:** 설치 시 설정한 `bootstrapPassword` (`adminpassword123`) 사용.
3. **URL 확인:** Rancher Server URL이 본인의 도메인 주소로 정확히 설정되어 있는지 확인합니다.

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "인증서 신뢰할 수 없음 (Self-signed)"

* **증상:** 브라우저 접속 시 보안 경고가 뜨거나, 다운스트림 클러스터 등록이 안 됨.
* **원인:** `cert-manager`가 인증서를 발급받는 동안 Rancher가 자체 생성한 인증서를 먼저 사용했을 때 발생합니다.
* **해결:** `letsencrypt-prod`를 통해 발급된 `rancher-tls` 시크릿이 정상적으로 생성되었는지(`kubectl get secret -n cattle-system`) 확인하세요.

### 📍 삽질 2: "Rancher Pod가 계속 Restart됨"

* **상황:** 로그에 `waiting for cert-manager to be ready` 메시지 무한 반복.
* **원인:** Rancher 파드가 뜨기 전 cert-manager가 완벽히 실행되지 않았거나, `installCRDs=true` 옵션이 빠졌을 때 발생합니다.
* **해결:** `cert-manager` 파드가 모두 `Running`인지 확인하고 Rancher를 다시 설치하세요.

### 📍 삽질 3: "메모리 부족 (OOM)"

* **상황:** Rancher 설치 후 클러스터 전체가 느려지거나 다른 파드들이 죽음.
* **교훈:** Rancher는 상당히 무거운 도구입니다. DS2_v2(메모리 7GB) 환경에서 지금까지 설치한 모든 도구를 다 띄우기는 어렵습니다.
* **해결:** 실습 중이라면 안 쓰는 도구(예: SonarQube, ELK)를 일시적으로 스케일 다운(`replicas: 0`)하여 메모리를 확보하세요.

---