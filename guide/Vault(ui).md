**요약:**
인프라의 모든 민감 정보(비밀번호, API 키, 인증서)를 안전하게 암호화하여 저장하고 관리하는 **HashiCorp Vault** 구축 가이드입니다. 볼트는 단순한 저장소를 넘어 '동적 비밀번호 생성'과 '데이터 암호화' 기능을 제공하는 인프라의 비밀 금고입니다. 운영 표준인 **Ingress-Nginx**와 **cert-manager**를 통해 `https` 환경으로 구축하며, 초기 실행 시 반드시 거쳐야 하는 **봉인 해제(Unseal)** 과정을 포함했습니다. (사실 확인 완료: Vault는 설치 직후 '봉인(Sealed)' 상태로 시작되므로 최소 3개의 Unseal Key 중 지정된 수 이상을 입력해야 운영이 가능하며, Kubernetes와 연동 시 Sidecar Injection 기능을 통해 애플리케이션에 비밀번호를 직접 주입할 수 있습니다.)

---

# 🔐 Stage 20: Vault - 중앙 집중형 비밀 정보 관리 시스템 구축 가이드

## 1. 개요

* **역할:** 소스 코드나 설정 파일에 평문으로 노출되기 쉬운 DB 접속 정보, API 키 등을 암호화하여 관리합니다.
* **핵심 기능:** 비밀번호 자동 갱신, AWS/Azure 임시 자격 증명 발급, 애플리케이션에 비밀 값 자동 주입(Sidecar Injection).

---

## 2. Helm 설정 파일 생성 (`vault-values.yaml`)

서버의 `/home/azureuser/helm_charts/` 폴더에 생성합니다. 실습 환경의 자원을 고려하여 **Raft 통합 스토리지** 모드로 구성했습니다.

```yaml
# vault-values.yaml
server:
  # [🔥핵심] 데이터 보존을 위한 Raft 스토리지 설정
  dataStorage:
    enabled: true
    size: 10Gi

  # 운영 표준 인그레스 설정
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
      cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hosts:
      - host: vault.20.196.204.108.nip.io # [본인의 공인IP로 수정]
    tls:
      - secretName: vault-tls
        hosts:
          - vault.20.196.204.108.nip.io

  # Vault UI 활성화
  ui:
    enabled: true
    serviceType: "ClusterIP"

# 애플리케이션에 비밀번호를 주입해주는 인젝터 활성화
injector:
  enabled: true

```

---

## 3. Vault 설치 (Helm 실행)

HashiCorp 공식 레포지토리를 사용합니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add hashicorp https://helm.releases.hashicorp.com
helm repo update

# 2. 설치 (네임스페이스: vault)
helm install vault hashicorp/vault \
  --namespace vault --create-namespace \
  -f vault-values.yaml

```

---

## 4. [🔥필수] 초기화 및 봉인 해제 (Unseal)

Vault는 보안을 위해 처음 설치하면 **'봉인(Sealed)'** 상태입니다. 금고를 열기 위한 열쇠를 생성해야 합니다.

```bash
# 1. Vault 초기화 (한 번만 실행)
# 실행 후 나오는 Unseal Keys와 Initial Root Token을 반드시 메모장에 복사해두세요!
kubectl exec -it vault-0 -n vault -- vault operator init

# 2. 봉인 해제 (위에서 나온 Unseal Key 중 3개를 각각 입력해야 함)
# 아래 명령어를 3번 실행하며 서로 다른 키를 입력하세요.
kubectl exec -it vault-0 -n vault -- vault operator unseal <Unseal_Key_1>
kubectl exec -it vault-0 -n vault -- vault operator unseal <Unseal_Key_2>
kubectl exec -it vault-0 -n vault -- vault operator unseal <Unseal_Key_3>

# 3. 상태 확인 (Sealed가 false가 되면 성공)
kubectl exec -it vault-0 -n vault -- vault status

```

---

## 5. 최종 접속

1. **접속 주소:** `https://vault.20.196.204.108.nip.io`
2. **로그인 방법:** `Token` 방식을 선택하고 초기화 시 메모해둔 **Initial Root Token**을 입력합니다.

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "서버 재시작 후 접속 불가"

* **증상:** 분명히 어제까지 잘 됐는데, 오늘 접속하니 500 에러가 나거나 로그인이 안 됨.
* **원인:** Vault는 파드가 재시작될 때마다 다시 **봉인(Sealed)** 상태가 됩니다.
* **해결:** 파드가 재시작되었다면 4번 단계의 **unseal 명령어**를 다시 수행해야 합니다. (실무에서는 이 과정을 자동화하기 위해 Azure Key Vault 등을 연동하는 'Auto-unseal'을 씁니다.)

### 📍 삽질 2: "Internal Server Error (HTTPS)"

* **상황:** 인그레스로 접속하면 에러가 남.
* **원인:** Vault 서버는 내부적으로도 강력한 TLS 통신을 선호합니다.
* **해결:** 인그레스 설정(`annotations`)에 `backend-protocol: "HTTPS"`가 정확히 들어갔는지, `cert-manager`가 인증서를 정상 발급했는지 확인하세요.

### 📍 삽질 3: "토큰 분실"

* **상황:** 초기화 때 나온 Root Token을 안 적어둠.
* **해결:** Root Token은 다시 찾을 방법이 없습니다. 데이터를 다 지우고 다시 초기화하거나, Unseal Key가 있다면 새로운 Root Token을 생성해야 합니다. (초기화 시 출력되는 문구를 꼭 저장하는 습관이 중요합니다!)

---