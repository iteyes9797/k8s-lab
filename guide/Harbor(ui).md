**요약:**
단순히 이미지를 저장하는 곳을 넘어, 취약점 스캔(Trivy)과 이미지 서명, RBAC(권한 관리) 기능을 갖춘 기업급 레지스트리 **Harbor** 구축 가이드입니다. Harbor는 우리가 빌드한 도커 이미지를 안전하게 보관하는 '무기고' 역할을 합니다. 도커 엔진과의 통신을 위해 **HTTPS(TLS)** 설정이 필수이며, 운영 표준인 **Ingress-Nginx**를 통해 외부와 통신하도록 구성했습니다. (사실 확인 완료: Harbor는 Core, Job Service, Registry, Database 등 여러 컴포넌트로 구성되어 있어 최소 4GB 이상의 여유 메모리가 필요하며, `externalURL` 설정이 정확해야 Docker Login이 성공합니다.)

---

# 🚢 Stage 17: Harbor - 기업급 컨테이너 이미지 저장소 구축 가이드

## 1. 개요

* **역할:** 빌드된 도커 이미지를 저장, 관리하며 배포 전 이미지의 보안 취약점을 자동으로 검사합니다.
* **핵심 기능:** 프로젝트별 권한 제어, 이미지 복제(Replication), 취약점 스캔(Trivy 내장).

---

## 2. Helm 설정 파일 생성 (`harbor-values.yaml`)

Harbor는 구조가 복잡하므로 `externalURL`과 `persistence` 설정을 정확히 맞추는 것이 핵심입니다.

```yaml
# harbor-values.yaml
# [🔥핵심] 외부에서 접속할 주소 (Docker Login 시 사용)
externalURL: https://harbor.20.196.204.108.nip.io

# 운영 표준 인그레스 설정
expose:
  type: ingress
  tls:
    enabled: true
    certSource: secret
    secretName: harbor-tls # cert-manager가 생성할 인증서 이름
  ingress:
    hosts:
      core: harbor.20.196.204.108.nip.io
    annotations:
      ingress.kubernetes.io/ssl-redirect: "true"
      nginx.ingress.kubernetes.io/proxy-body-size: "0" # 대용량 이미지 업로드 허용
      cert-manager.io/cluster-issuer: "letsencrypt-prod" # Stage 12에서 만든 발급자

# 데이터 보존을 위한 스토리지 설정 (NFS 필수)
persistence:
  enabled: true
  resourcePolicy: "keep"
  persistentVolumeClaim:
    registry:
      size: 50Gi # 이미지 저장 공간
    jobservice:
      size: 1Gi
    database:
      size: 5Gi
    redis:
      size: 1Gi

# [🔥실무 설정] 초기 비밀번호
harborAdminPassword: "HarborPassword123"

```

---

## 3. Harbor 설치 (Helm 실행)

Harbor는 공식 차트의 완성도가 높습니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add harbor https://helm.goharbor.io
helm repo update

# 2. 설치 (네임스페이스: harbor)
helm install harbor harbor/harbor \
  --namespace harbor --create-namespace \
  -f harbor-values.yaml

```

---

## 4. 최종 접속 및 이미지 푸시 테스트

1. **웹 UI 접속:** `https://harbor.20.196.204.108.nip.io` 접속 후 `admin` / `HarborPassword123` 로그인.
2. **프로젝트 생성:** `library` 또는 신규 프로젝트(예: `my-project`) 생성.
3. **로컬 PC에서 로그인:**
```bash
docker login harbor.20.196.204.108.nip.io

```


4. **이미지 푸시:**
```bash
docker tag nginx:latest harbor.20.196.204.108.nip.io/my-project/nginx:v1
docker push harbor.20.196.204.108.nip.io/my-project/nginx:v1

```



---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "Docker Login 실패 (certificate signed by unknown authority)"

* **증상:** `docker login` 시 인증서 에러가 나며 거부됨.
* **원인:** Docker는 보안상 HTTPS가 아니면 로그인을 허용하지 않습니다.
* **해결:** `cert-manager`를 통해 공인 인증서를 받거나, 로컬 PC 도커 설정(`daemon.json`)에 `insecure-registries` 항목으로 본인의 IP를 등록해야 합니다. (운영 환경에선 전자가 표준입니다.)

### 📍 삽질 2: "대용량 이미지 업로드 중 끊김 (413 Payload Too Large)"

* **상황:** 몇 GB짜리 무거운 이미지를 올리는데 중간에 에러 발생.
* **해결:** 인그레스 설정(`annotations`)에 `nginx.ingress.kubernetes.io/proxy-body-size: "0"`이 빠졌는지 확인하세요.

### 📍 삽질 3: "Database 파드가 Pending 상태"

* **상황:** 설치 후 `harbor-database` 파드가 뜨지 않음.
* **원인:** Harbor는 내부적으로 DB, Redis 등 많은 디스크를 요구합니다.
* **해결:** `kubectl get pvc -n harbor`를 확인하여 `Bound` 되지 않은 항목이 있는지, NFS Provisioner가 정상 작동 중인지 체크하세요.

---