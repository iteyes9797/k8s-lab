**요약:**
컨테이너 이미지와 파일시스템의 취약점을 찾아내는 보안 스캐너 **Grype** 구축 가이드입니다. Grype는 ArgoCD나 SonarQube처럼 화면(UI)이 있는 서비스가 아니라, 터미널에서 실행하는 **CLI(Command Line Interface) 도구**입니다. 따라서 인프라 마스터 서버에 직접 설치하거나, 나중에 구축할 **Jenkins CI/CD 파이프라인**의 한 단계로 포함시켜 사용합니다.

---

# 🛡️ Stage 11: Grype - 컨테이너 이미지 취약점 스캐너 구축 가이드

## 1. 개요

* **역할:** 컨테이너 이미지 내부에 설치된 패키지들의 보안 취약점(CVE)을 스캔합니다.
* **특징:** 매우 빠르며, 나중에 설치할 **Harbor(이미지 저장소)**나 **Jenkins(빌드 도구)**와 연동하여 "취약점이 있는 이미지는 배포 금지"와 같은 보안 정책을 세울 때 핵심 역할을 합니다.

---

## 2. 마스터 서버 설치 (Binary Install)

Grype는 별도의 K8s 배포보다는 마스터 서버(`k8s-master01`)에 설치해서 명령어로 바로 사용하는 것이 가장 일반적입니다.

```bash
# 1. 관리자 권한으로 설치 스크립트 실행
# /usr/local/bin 에 grype 실행 파일을 설치합니다.
curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin

# 2. 설치 확인
grype version

```

---

## 3. 실전 사용법 (이미지 스캔)

설치가 끝났다면, 현재 우리 클러스터에서 돌고 있는 이미지들을 바로 스캔해볼 수 있습니다.

```bash
# 1. 특정 이미지 스캔 (예: 아까 설치한 아르고CD 이미지)
# 최초 실행 시 취약점 DB를 다운로드하느라 시간이 조금 걸릴 수 있습니다.
grype quay.io/argoproj/argocd:v2.10.1

# 2. 심각도(Severity)가 높은 것만 필터링해서 보기
grype quay.io/argoproj/argocd:v2.10.1 --fail-on high

```

---

## 4. [심화] K8s Job으로 실행하기

만약 Grype를 K8s 내부에서 정기적으로 실행하고 싶다면, 아래와 같은 **Job** 형태의 YAML을 사용합니다.

**`grype-job.yaml` 생성 및 적용:**

```yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: grype-scan-job
  namespace: default
spec:
  template:
    spec:
      containers:
      - name: grype
        image: anchore/grype:latest
        args: ["nginx:latest"] # 스캔할 대상 이미지
      restartPolicy: Never
  backoffLimit: 4

```

```bash
kubectl apply -f grype-job.yaml

```

---

## 🚨 핵심 삽질 포인트

### 📍 삽질 1: "취약점 DB 업데이트 실패"

* **증상:** `failed to update vulnerability database` 에러 발생.
* **원인:** Azure VM의 아웃바운드 인터넷 설정이 막혀있거나, 프록시 환경에서 DB 서버(`toolbox-data.anchore.io`)에 접속하지 못할 때 발생합니다.
* **해결:** 마스터 서버에서 외부 인터넷 통신이 원활한지 확인하고, 일시적인 서버 점검일 수 있으니 잠시 후 다시 시도하세요.

### 📍 삽질 2: "Private Registry(Harbor) 인증 에러"

* **상황:** 나중에 설치할 **Harbor**에 저장된 개인 이미지를 스캔할 때 권한 에러 발생.
* **해결:** `docker login`이 선행되어야 하거나, Grype 실행 시 환경 변수로 ID/PW를 넘겨줘야 합니다.
```bash
GRYPE_REGISTRY_AUTH_AUTHORITY=myharbor.com \
GRYPE_REGISTRY_AUTH_USERNAME=admin \
GRYPE_REGISTRY_AUTH_PASSWORD=password \
grype myharbor.com/my-project/my-image:latest

```



### 📍 삽질 3: "너무 많은 결과값"

* **상황:** 결과가 수백 줄이 나와서 정작 중요한 걸 놓침.
* **해결:** `-o json` 옵션을 사용해 결과를 파일로 저장하거나, 위에서 설명한 `--fail-on` 옵션으로 심각한 취약점만 골라내는 습관이 중요합니다.

---