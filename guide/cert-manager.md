**요약:**
인프라의 모든 통신에 보안(HTTPS)을 입혀주는 **cert-manager** 구축 가이드입니다. 이 도구는 인증서 발급과 갱신을 자동화하는 '디지털 보안국' 역할을 합니다. 우리가 앞서 설정한 **Ingress-Nginx**와 연동하여, `http`로 접속하던 주소를 자물쇠가 달린 `https` 주소로 업그레이드하는 것이 핵심입니다.

---

# 🔐 Stage 12: cert-manager - 자동 TLS 인증서 관리자 구축 가이드

## 1. 개요

* **역할:** Let's Encrypt 같은 인증 기관으로부터 무료 SSL/TLS 인증서를 자동으로 받아오고 관리합니다.
* **핵심 이점:** 인증서 만료 90일마다 사람이 수동으로 갱신할 필요 없이, 로봇이 알아서 연장해 줍니다.

---

## 2. cert-manager 설치 (Helm 실행)

cert-manager는 고유의 리소스(CRD)가 많으므로 전용 네임스페이스에 설치하는 것이 좋습니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add jetstack https://charts.jetstack.io
helm repo update

# 2. 설치 (CRD 설치 옵션 필수!)
helm install cert-manager jetstack/cert-manager \
  --namespace cert-manager --create-namespace \
  --set installCRDs=true

# 3. 설치 확인 (3개의 로봇이 Running 인지 확인)
kubectl get pods -n cert-manager

```

---

## 3. ClusterIssuer 생성 (인증서 발급 소 지정)

인증서를 어디서 발급받을지 결정하는 단계입니다. 실습용으로 가장 많이 쓰는 **Let's Encrypt (Staging/Prod)** 설정을 만듭니다.

**`cluster-issuer.yaml` 생성 및 적용:**

```yaml
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    # 인증서 관련 알림을 받을 본인의 이메일을 적으세요
    email: user@example.com
    server: https://acme-v02.api.letsencrypt.org/directory
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx

```

```bash
kubectl apply -f cluster-issuer.yaml

```

---

## 4. [실전] ArgoCD에 HTTPS 적용하기

기존에 만든 아르고CD 인그레스 설정을 수정하여 '자물쇠'를 달아줍니다.

**`argocd-ingress-tls.yaml` 수정:**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: argo
  annotations:
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    # [🔥핵심] cert-manager에게 인증서 발급을 요청하는 어노테이션
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - argocd.20.196.204.108.nip.io
    secretName: argocd-server-tls # 인증서가 저장될 이름
  rules:
  - host: argocd.20.196.204.108.nip.io
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: argocd-server
            port:
              number: 80

```

```bash
kubectl apply -f argocd-ingress-tls.yaml

```

---

## 🚨 핵심 삽질 포인트

### 📍 삽질 1: "인증서 무한 대기 (Pending)"

* **증상:** `kubectl get certificate -n argo`를 쳤는데 `READY`가 `False`임.
* **원인:** Let's Encrypt가 본인의 서버(80 포트)에 접속해서 "진짜 주인 맞니?"라고 확인(Challenge)해야 하는데, Azure NSG에서 80 포트가 막혀있거나 `nip.io` 주소가 올바르지 않을 때 발생합니다.
* **해결:** `kubectl describe challenge` 명령어로 에러 메시지를 확인하고 80 포트 개방 여부를 체크하세요.

### 📍 삽질 2: "Let's Encrypt 발급 제한"

* **상황:** 테스트한다고 너무 여러 번 지웠다 깔았다 하면 Let's Encrypt 서버에서 1주일간 차단당합니다.
* **해결:** 처음 테스트할 때는 `letsencrypt-staging` 서버를 먼저 사용하여 성공 여부를 확인한 뒤, 최종적으로 `prod`를 사용하는 것이 안전합니다.

### 📍 삽질 3: "CRD 설치 누락"

* **상황:** `ClusterIssuer`를 적용하려는데 그런 리소스가 없다고 나옴.
* **해결:** Helm 설치 시 `--set installCRDs=true` 옵션을 빠뜨린 것입니다. 헬름 업그레이드 명령어로 다시 설치하세요.

---