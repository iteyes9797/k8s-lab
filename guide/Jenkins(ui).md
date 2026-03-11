**요약:**
CI/CD 파이프라인의 조상님이자 여전히 현역인 **Jenkins** 구축 가이드를 정리했습니다. Jenkins는 코드를 빌드하고, 테스트하고, 도커 이미지를 만들어 저장소에 푸시하는 '공장장' 역할을 합니다. 특히 쿠버네티스 환경에 맞게 **Jenkins Agent(Slave)**를 파드 형태로 동적 생성하도록 설정하며, 운영 표준인 **Ingress-Nginx**를 통해 포트 번호 없이 접속하도록 구성했습니다.

---

# 🏗️ Stage 14: Jenkins - 자동화 빌드 및 배포 엔진 구축 가이드

## 1. 개요

* **역할:** 소스 코드의 변경을 감지하여 빌드, 테스트, 배포 과정을 자동화하는 **CI(Continuous Integration)**의 핵심 도구입니다.
* **특징:** 수천 개의 플러그인을 통해 거의 모든 도구(GitLab, SonarQube, Harbor 등)와 연동됩니다.

---

## 2. Helm 설정 파일 생성 (`jenkins-values.yaml`)

젠킨스는 설정이 복잡하므로, 실습 사양(DS2_v2)과 인그레스 환경에 맞춘 핵심 설정만 추렸습니다.

```yaml
# jenkins-values.yaml
controller:
  # [🔥실무 설정] 젠킨스 관리자 비밀번호
  adminPassword: "adminpassword123"
  
  # 운영 표준 인그레스 설정
  ingress:
    enabled: true
    ingressClassName: nginx
    annotations:
      nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
      # cert-manager가 설치되어 있다면 아래 주석 해제
      # cert-manager.io/cluster-issuer: "letsencrypt-prod"
    hostName: jenkins.20.196.204.108.nip.io # [본인의 공인IP로 수정]

  # [🔥핵심] 필수 플러그인 자동 설치
  installPlugins:
    - kubernetes:4029.v5712230ccb_f8
    - workflow-aggregator:596.v8c21c963d92d
    - git:5.2.1
    - configuration-as-code:1777.v10c9f5633820
    - blueocean:1.27.10
    - sonar:2.17.2

# 데이터 보존을 위한 스토리지 설정
persistence:
  enabled: true
  size: 20Gi

```

---

## 3. Jenkins 설치 (Helm 실행)

젠킨스는 공식 레포지토리가 잘 관리되고 있습니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add jenkins https://charts.jenkins.io
helm repo update

# 2. 설치 (네임스페이스: jenkins)
helm install jenkins jenkins/jenkins \
  --namespace jenkins --create-namespace \
  -f jenkins-values.yaml

```

---

## 4. 최종 접속 및 초기 확인

1. **접속 주소:** `http://jenkins.20.196.204.108.nip.io`
2. **로그인 정보:** * **ID:** `admin`
* **PW:** `adminpassword123` (혹은 설정한 비밀번호)


3. **비밀번호를 모를 경우:**
```bash
kubectl exec -it svc/jenkins -n jenkins -c jenkins -- /bin/cat /var/jenkins_home/secrets/initialAdminPassword

```



---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "플러그인 설치 무한 대기"

* **증상:** 설치 후 UI가 떴는데 '플러그인을 불러오는 중'에서 멈춰 있음.
* **원인:** 젠킨스 파드가 외부 인터넷(Update Center)에 접속하지 못하거나, 서버 사양 문제로 압축 해제 속도가 매우 느릴 때 발생합니다.
* **해결:** `kubectl logs -f <jenkins-pod-name> -n jenkins`로 로그를 확인하고, 타임아웃이 난다면 파드를 재시작해 보세요.

### 📍 삽질 2: "Slave(Agent) 파드가 안 떠요"

* **상황:** 빌드를 시작했는데 `Jenkins doesn't have label ...` 메시지만 뜨고 빌드가 안 됨.
* **원인:** 젠킨스가 K8s API 서버에 파드를 생성할 권한(RBAC)이 없기 때문입니다.
* **해결:** Helm 설치 시 기본적으로 생성되는 `ServiceAccount`가 클러스터 권한을 가지고 있는지 확인해야 합니다. (기본 차트 설정은 보통 해결되어 있음)

### 📍 삽질 3: "OOM (Out Of Memory) 킬러"

* **증상:** 빌드 중에 젠킨스 파드가 예고 없이 재시작됨.
* **원인:** 젠킨스는 Java 기반이라 메모리 소모가 큰데, 빌드 작업까지 겹치면 DS2_v2 VM의 메모리 한계를 넘어서게 됩니다.
* **해결:** 빌드는 젠킨스 본체(Controller)가 아닌 **Agent 파드**에서 수행하도록 Pipeline을 구성해야 합니다.

---