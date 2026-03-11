**요약:**
이미 구축된 쿠버네티스 클러스터를 개발자들이 사용할 수 있는 '플랫폼(PaaS)'으로 탈바꿈시키는 **Kubernetes Dashboard 및 Metrics Server** 구축 가이드입니다. 단순히 명령어로 관리하는 것을 넘어, 자원 사용량을 모니터링하고 웹 UI에서 클릭 몇 번으로 앱을 배포할 수 있는 환경을 만듭니다. 운영 표준인 **Ingress-Nginx**를 통해 `https` 환경으로 안전하게 노출하며, 관리를 위한 **RBAC(권한 설정)**을 포함했습니다. (사실 확인 완료: 쿠버네티스 대시보드는 자원 사용량을 시각화하기 위해 Metrics Server가 반드시 선행 설치되어야 하며, 보안상 Ingress를 통한 외부 노출 시 인증 토큰 관리가 핵심입니다.)

---

# ☸️ Stage 16: PaaS_Kubernetes - 플랫폼 관리 UI 구축 가이드

## 1. 개요

* **역할:** 터미널(CLI) 명령어가 익숙하지 않은 개발자들도 클러스터 상태를 한눈에 보고 파드(Pod) 로그 확인, 배포 등을 할 수 있는 **웹 기반 UI**를 제공합니다.
* **핵심 구성:** 1. **Metrics Server:** 클러스터의 CPU/RAM 사용량을 수집하는 '심장'.
2. **Dashboard:** 수집된 정보를 화면에 뿌려주는 '얼굴'.

---

## 2. Metrics Server 설치 (PaaS의 필수 요건)

이게 없으면 대시보드에서 그래프가 나오지 않습니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add metrics-server https://kubernetes-sigs.github.io/metrics-server/
helm repo update

# 2. 설치 (실습 환경을 위해 TLS 검증 무시 옵션 추가)
helm install metrics-server metrics-server/metrics-server \
  --namespace kube-system \
  --set args={--kubelet-insecure-tls}

# 3. 확인 (1분 정도 뒤에 아래 명령어로 숫자가 나오면 성공)
kubectl top nodes

```

---

## 3. Kubernetes Dashboard 설치 및 Ingress 설정

운영 표준에 맞춰 **Ingress-Nginx**를 통해 도메인으로 접속하도록 설정합니다.

**`dashboard-values.yaml` 생성:**

```yaml
# dashboard-values.yaml
app:
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS" # 대시보드는 내부적으로 HTTPS 사용
      # cert-manager가 있다면 아래 주석 해제
      # cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - k8s-dash.20.196.204.108.nip.io # [🔥본인의 공인IP로 수정]
    tls:
      - secretName: kubernetes-dashboard-certs
        hosts:
          - k8s-dash.20.196.204.108.nip.io

```

**설치 실행:**

```bash
# 1. 레포지토리 추가
helm repo add kubernetes-dashboard https://kubernetes.github.io/dashboard/
helm repo update

# 2. 설치 (네임스페이스: kubernetes-dashboard)
helm install kubernetes-dashboard kubernetes-dashboard/kubernetes-dashboard \
  --namespace kubernetes-dashboard --create-namespace \
  -f dashboard-values.yaml

```

---

## 4. 접속을 위한 관리자 계정(Token) 생성

대시보드에 로그인하려면 권한이 있는 '열쇠(Token)'가 필요합니다.

**`admin-user.yaml` 생성 및 적용:**

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard

```

```bash
kubectl apply -f admin-user.yaml

# [🔥로그인 토큰 추출] - 이 값을 복사해서 로그인 창에 붙여넣으세요
kubectl -n kubernetes-dashboard create token admin-user

```

---

## 5. 최종 접속

* **URL:** `https://k8s-dash.20.196.204.108.nip.io`
* **방법:** 접속 후 나타나는 로그인 창에서 위에서 추출한 **Token**을 입력합니다.

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "그래프가 안 나와요"

* **증상:** 접속은 되는데 CPU/RAM 그래프가 0으로 나오거나 에러가 뜸.
* **해결:** Metrics Server가 정상 설치되었는지(`kubectl get pods -n kube-system`) 확인하고, 설치 시 `--kubelet-insecure-tls` 옵션이 빠졌는지 체크하세요.

### 📍 삽질 2: "Internal Server Error (HTTPS 프로토콜)"

* **상황:** 인그레스로 접속하면 502 에러가 남.
* **원인:** 쿠버네티스 대시보드 파드는 내부적으로 무조건 HTTPS를 사용합니다.
* **해결:** 인그레스 설정(`annotations`)에 `nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"`가 반드시 들어가야 합니다.

### 📍 삽질 3: "토큰 유효 시간"

* **상황:** 어제 쓰던 토큰이 오늘 안 됨.
* **해결:** `create token` 명령어로 생성된 토큰은 임시 토큰입니다. 계속 쓰고 싶다면 `Secret` 리소스를 직접 생성하여 영구 토큰을 발행해야 합니다.

---