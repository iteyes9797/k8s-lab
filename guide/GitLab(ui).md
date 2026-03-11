**요약:**
소스 코드 관리부터 빌드, 배포까지 한곳에서 처리하는 '데브옵스의 심장' **GitLab** 구축 가이드입니다. 깃랩은 단순한 코드 저장소를 넘어 자체적인 CI/CD 기능과 컨테이너 레지스트리를 포함한 올인원 도구입니다. 리소스 소모가 매우 크기 때문에 **최적화 설정**이 필수이며, 운영 표준인 **Ingress-Nginx**와 **cert-manager**를 통해 `https` 환경으로 구축합니다. (사실 확인 완료: 깃랩은 최소 4GB 이상의 여유 RAM을 요구하며, 클러스터 내부의 여러 컴포넌트(PostgreSQL, Redis, Gitaly 등)가 동시에 뜨기 때문에 설치 후 서비스 안정화까지 5~10분 정도의 시간이 소요됩니다.)

---

# 🦊 Stage 19: GitLab - 올인원 형상 관리 및 CI 플랫폼 구축 가이드

## 1. 개요

* **역할:** 소스 코드 관리(Git), 코드 리뷰, 이슈 트래킹, CI/CD 파이프라인을 하나의 플랫폼에서 제공합니다.
* **특징:** 자체적인 컨테이너 레지스트리를 가지고 있어 Harbor 대신 사용할 수도 있으며, Jenkins 없이도 강력한 빌드 자동화가 가능합니다.

---

## 2. Helm 설정 파일 생성 (`gitlab-values.yaml`)

깃랩은 매우 무겁습니다. 현재 실습 환경(DS2_v2, 7GB RAM)을 고려하여 **불필요한 기능을 끄고 메모리를 쥐어짜는 최적화**가 핵심입니다.

```yaml
# gitlab-values.yaml
global:
  hosts:
    domain: 20.196.204.108.nip.io # [🔥본인의 공인IP로 수정]
  ingress:
    configureCertmanager: true
    class: nginx
    annotations:
      cert-manager.io/cluster-issuer: "letsencrypt-prod"

# [🔥핵심] 리소스 최적화 - 안 쓰는 기능 끄기
certmanager:
  install: false # 이미 설치했으므로 false
nginx-ingress:
  install: false # 이미 설치했으므로 false
prometheus:
  install: false # 이미 설치했으므로 false (Stage 1에서 이미 설치됨)

# 깃랩 코어 설정
gitlab:
  webservice:
    workerProcesses: 2 # 프로세스 수를 줄여 메모리 절약
  sidekiq:
    concurrency: 5
  gitlab-shell:
    enabled: true

# 데이터 보존을 위한 스토리지
postgresql:
  persistence:
    size: 10Gi
gitaly:
  persistence:
    size: 20Gi

```

---

## 3. GitLab 설치 (Helm 실행)

깃랩은 설치 과정에서 많은 리소스를 생성하므로 인내심이 필요합니다.

```bash
# 1. 헬름 레포지토리 추가 및 업데이트
helm repo add gitlab https://charts.gitlab.io/
helm repo update

# 2. 설치 (네임스페이스: gitlab)
helm install gitlab gitlab/gitlab \
  --namespace gitlab --create-namespace \
  -f gitlab-values.yaml \
  --timeout 600s # 설치 시간이 길어질 수 있어 타임아웃 연장

```

---

## 4. 최종 접속 및 초기 비밀번호

1. **접속 주소:** `https://gitlab.20.196.204.108.nip.io`
2. **초기 root 비밀번호 확인:**
```bash
kubectl get secret -n gitlab gitlab-gitlab-initial-root-password -o jsonpath="{.data.password}" | base64 -d; echo

```


3. **로그인:** 아이디 `root`와 위에서 확인한 비밀번호로 로그인합니다.

---

## 🚨 핵심 삽질 포인트 (Deep-Dive)

### 📍 삽질 1: "메모리 부족으로 인한 무한 Crash"

* **증상:** 설치 후 `kubectl get pods -n gitlab`을 쳤을 때 여러 파드가 `CrashLoopBackOff`나 `Pending`에 빠짐.
* **원인:** 깃랩은 최소 4GB RAM을 점유합니다. 이미 ELK, SonarQube, Nexus 등이 떠 있다면 DS2_v2 VM의 메모리는 이미 한계입니다.
* **해결:** 실습을 위해 **이전에 설치한 도구들의 리플리카를 0으로 줄여** 메모리를 확보한 뒤 깃랩을 띄우세요.
```bash
kubectl scale deployment <기존도구> -n <네임스페이스> --replicas=0

```



### 📍 삽질 2: "SSH 포트 충돌"

* **상황:** Git Clone을 SSH로 하려고 하는데 연결이 안 됨.
* **원인:** K8s 노드(VM) 자체가 이미 22번 포트를 사용 중이라, 깃랩의 SSH와 충돌이 납니다.
* **해결:** 인그레스 설정에서 SSH 포트를 다른 포트(예: 2222)로 포워딩하거나, 실습 환경에서는 마음 편하게 **HTTP/HTTPS Clone**을 사용하세요.

### 📍 삽질 3: "Gitaly 파드 대기"

* **상황:** 모든 게 다 떴는데 프로젝트 생성이 안 됨.
* **원인:** 깃 저장소를 담당하는 `Gitaly` 파드가 완전히 준비되지 않았기 때문입니다.
* **해결:** `kubectl logs -f`로 Gitaly 로그를 확인하고 "Successfully started" 메시지가 나올 때까지 기다리세요.

---