# K8S-LAB: All-in-One Infrastructure & GitOps Platform

인프라 생성부터 애플리케이션 배포까지 **단 한 줄의 명령어로 완성하는
통합 자동화 프로젝트**

이 프로젝트는 **Terraform, Ansible, Helm, ArgoCD, Argo Workflows**를
유기적으로 결합하여\
Azure 클라우드 환경에서 **IaC(Infrastructure as Code)** 기반의
Kubernetes 및 CI/CD 플랫폼을 구축하는 표준 모델을 제공합니다.

------------------------------------------------------------------------

# 1. Project Overview

## 1.1 목적

본 프로젝트는 다음 목표를 위해 설계되었습니다.

-   **Kubernetes 클러스터 자동 구축**
-   **IaC 기반 인프라 관리**
-   **GitOps 기반 배포**
-   **CI/CD 자동화**
-   **클라우드 네이티브 아키텍처 표준화**

## 1.2 주요 구성 기술

  영역                사용 기술
  ------------------- -------------------------
  Infrastructure      Terraform
  Configuration       Ansible
  Container Runtime   CRI-O
  Kubernetes          K8s v1.32
  CI                  Argo Workflows + Kaniko
  CD                  ArgoCD
  Registry            Harbor
  Storage             NFS Provisioner

------------------------------------------------------------------------

# 2. Key Highlights

## 2.1 Full‑Stack Automation

`run.sh` 실행 한 번으로 다음 작업이 자동 수행됩니다.

-   VM 생성 (Terraform)
-   Kubernetes 클러스터 구축 (Ansible)
-   Harbor Registry 설치
-   Argo Workflows CI 환경 구성
-   ArgoCD GitOps 배포

------------------------------------------------------------------------

## 2.2 Security First

보안 강화를 위해 **Bastion Host 기반 SSH 터널링 구조**를 적용했습니다.

구성 특징

-   외부에서 직접 Worker 접근 불가
-   Bastion을 통한 내부 접근
-   SSH Key 자동 생성
-   인증 자동화

------------------------------------------------------------------------

## 2.3 Zero‑Configuration Connection

Terraform → Ansible 자동 연동

-   inventory 자동 생성
-   IP 수동 입력 제거
-   Bastion 터널 자동 설정

------------------------------------------------------------------------

## 2.4 Path Independence

프로젝트 실행 위치와 관계없이 동작하도록 설계

    PROJECT_ROOT=$(pwd)

WSL 내부 경로를 자동 인식합니다.

------------------------------------------------------------------------

## 2.5 Environment Self-Healing Script

실행 환경을 자동으로 진단합니다.

자동 수행 항목

-   SSH Key 생성
-   Vault Password 생성
-   Azure CLI 체크
-   필수 패키지 검사

------------------------------------------------------------------------

# 3. Quick Start

## 3.1 WSL2 활성화

Windows 환경에서 실행 시 먼저 WSL2를 활성화합니다.

PowerShell(관리자)

    wsl --install

설치 후 **PC 재부팅 필수**

------------------------------------------------------------------------

## 3.2 프로젝트 환경 구축

WSL 내부 경로에서 실행해야 권한 문제가 발생하지 않습니다.

### Step1 프로젝트 복사 및 환경 연결
WSL 환경에서 파일을 관리하는 두 가지 방법 중 하나를 선택하세요.

방법 A: 프로젝트 복사 (안전한 격리 환경)
윈도우 드라이브와 완전히 분리된 WSL 내부 저장소에 파일을 복사합니다.

``` bash
# 1. 현재 윈도우 위치 정보를 동적으로 가져오기
TARGET_PATH=$(pwd)

# 2. 기존 폴더 삭제 및 재생성
rm -rf ~/k8s-lab && mkdir -p ~/k8s-lab

# 3. 현재 위치의 파일들을 WSL 홈으로 복사
# (변수를 반드시 큰따옴표로 감싸서 공백 문제를 방지합니다)
cp -rv "$TARGET_PATH/." ~/k8s-lab/

# 4. 이동 및 확인
cd ~/k8s-lab && ls
```

방법 B: 심볼릭 링크 연결 (윈도우-WSL 실시간 동기화)
윈도우에서 수정하면 WSL에 즉시 반영되길 원할 때 사용합니다. (권장)

``` bash
# 1. 현재 윈도우 위치 정보를 동적으로 가져오기
TARGET_PATH=$(pwd)

# 2. 기존 폴더 삭제 및 재생성
rm -rf ~/k8s-lab && mkdir -p ~/k8s-lab

# 3. 기존 폴더/링크 삭제 후 심볼릭 링크 생성
rm -rf ~/k8s-lab
ln -s "$TARGET_PATH" ~/k8s-lab

# 4. 이동 및 확인
cd ~/k8s-lab && ls -ld ~/k8s-lab
```

------------------------------------------------------------------------

### Step2 권한 초기화

``` bash
# 모든 파일의 실행 권한을 먼저 제거 (보안 및 에러 방지)
find . -type f -exec chmod 644 {} +

# 필요한 스크립트만 실행 권한 부여
chmod +x run.sh

# Vault 패스워드 파일은 반드시 실행 권한이 없어야 함 (중요)
chmod 600 .vault_pass
```
> **Tip**: 심볼릭 링크 사용 시 `.vault_pass` 권한 에러(Exec format error)가 발생한다면, 해당 파일만 WSL 로컬 경로로 복사하여 `600` 권한을 부여한 뒤 다시 링크를 걸어주어야 합니다.

------------------------------------------------------------------------

## 3.3 필수 패키지 설치

``` bash
# 로컬 패키지 인덱스를 최신 상태로 업데이트
sudo apt update

# git: 소스 코드 버전 관리
# python3-pip: 파이썬 기반 도구(Ansible 등) 관리
# unzip: 테라폼 등 압축 파일 해제
# curl: 웹 서버로부터 데이터 전송 (설치 스크립트 다운로드용)
# jq: JSON 형식의 데이터를 커맨드라인에서 처리/가공
sudo apt install -y git python3-pip unzip curl jq
```

### Azure CLI

``` bash
# Microsoft에서 제공하는 자동 설치 스크립트를 다운로드하여 즉시 실행
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
```

### Terraform

``` bash
# GPG 키 관리 및 소프트웨어 소스 관리를 위한 필수 패키지 설치
sudo apt install -y gnupg software-properties-common

# HashiCorp 공식 GPG 키를 다운로드하여 시스템 키링에 등록 (보안 검증용)
curl -fsSL https://apt.releases.hashicorp.com/gpg \
| sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg

# HashiCorp 공식 레포지토리를 시스템 소프트웨어 소스 리스트에 추가
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
| sudo tee /etc/apt/sources.list.d/hashicorp.list

# 새로 추가된 레포지토리 정보를 반영하여 업데이트 후 테라폼 설치
sudo apt update && sudo apt install -y terraform
```

### Ansible 

``` bash
# 1. 최신 패키지 정보를 다시 확인
sudo apt update

# 2. 앤서블 핵심 패키지 및 관련 파이썬 의존성 한 번에 설치
sudo apt install -y ansible

# 3. 설치 완료 확인
ansible --version
```

### Helm

``` bash
# Helm 공식 설치 스크립트를 실행하여 최신 스테이블 버전 설치
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
```

### ArgoCD CLI

``` bash
# GitHub에서 최신 버전의 ArgoCD 리눅스 실행 파일을 다운로드
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64

# 다운로드한 파일을 실행 가능한 권한(555)으로 설정하여 시스템 경로(/usr/local/bin)에 설치
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd

# 설치 완료 후 사용한 임시 설치 파일 삭제
rm argocd-linux-amd64
```

### 기존 환경설정 파일 삭제 및 초기화

# 윈도우에서 복사해온 뒤, 꼬인 권한과 OS가 다른 바이너리들을 싹 정리
rm -rf .terraform .terraform.lock.hcl

# 현재 WSL(리눅스) 환경에 맞는 깨끗한 파일을 새로 다운로드
terraform init

------------------------------------------------------------------------

# 4. Cloud Authentication

Azure 로그인

    az login

브라우저 인증 후 CLI 세션이 활성화됩니다.

------------------------------------------------------------------------

# 5. One‑Click Deployment

전체 환경을 자동 구축합니다.

    ./run.sh

실행 시 다음 단계가 자동 수행됩니다.

1️⃣ SSH Key 생성\
2️⃣ Terraform Infrastructure Provisioning\
3️⃣ Ansible Kubernetes Cluster Setup\
4️⃣ Helm 기반 서비스 설치\
5️⃣ ArgoCD GitOps 동기화

------------------------------------------------------------------------

# 6. System Architecture

## 6.1 Infrastructure Layer

Azure VM 기반 구성

-   Master Node
-   Worker Node
-   Bastion Host
-   NFS Server
-   Load Balancer

Terraform으로 자동 생성됩니다.

------------------------------------------------------------------------

## 6.2 Kubernetes Layer

Ansible을 이용해 다음 구성 요소가 설치됩니다.

-   Kubernetes
-   CRI-O Container Runtime
-   Calico CNI
-   NFS Storage Provisioner

------------------------------------------------------------------------

## 6.3 Storage Architecture

NFS Subdir External Provisioner 사용

지원 기능

-   Dynamic PVC
-   자동 PV 생성
-   Namespace 분리 스토리지

------------------------------------------------------------------------

## 6.4 CI/CD Pipeline

### CI

Argo Workflows + Kaniko

-   Docker daemon 없이 이미지 빌드
-   Harbor Registry Push

### CD

ArgoCD

-   GitOps 기반 배포
-   Git Repository 상태 자동 동기화

------------------------------------------------------------------------

# 7. Project Structure

    k8s-lab
    │
    ├ terraform/       # Azure Infrastructure IaC
    ├ ansible/         # Kubernetes Cluster Setup
    ├ helm/            # Helm Chart Values
    ├ argoCd/          # GitOps Application Manifest
    ├ docker/          # Container Build Environment
    │
    ├ run.sh           # One‑Click Automation Script
    │
    └ docs/
        ├ ARCHITECTURE_REVIEW.md
        ├ TROUBLE_SHOOTING.md
        └ CONTRIBUTING.md

------------------------------------------------------------------------

# 8. Documentation

프로젝트의 상세 기술 설명과 구축 과정에서 발생한 문제 해결 기록은 아래 문서에서 확인할 수 있습니다.

👉 [ARCHITECTURE_REVIEW.md](ARCHITECTURE_REVIEW.md)

AS-IS → TO-BE 아키텍처 개선 분석

포함 내용

- Bastion 기반 보안 아키텍처
- Terraform 모듈화 설계
- Ansible Role 구조 설계
- Legacy 구성 제거 및 리팩토링

---

👉 [TROUBLE_SHOOTING.md](TROUBLE_SHOOTING.md)

실제 구축 과정에서 해결한 주요 기술 문제 기록

예시

- Ansible SSH 터널링 문제
- kubeadm 인증서 오류
- NFS IP 동적 주입 문제
- Calico MTU 이슈

---

👉 [CONTRIBUTING.md](CONTRIBUTING.md)

협업 및 Git 전략

- `main` : 안정 버전
- `setup` : 환경 구축 브랜치
- Pull Request 기반 협업

------------------------------------------------------------------------

# Future Roadmap

향후 확장 예정

-   Istio Service Mesh
-   Keycloak Identity Provider
-   Observability Stack
    -   Prometheus
    -   Grafana
    -   Loki
    -   OpenTelemetry
-   GitOps Multi Cluster

------------------------------------------------------------------------

# Author

Cloud Native / DevOps Infrastructure Template

Terraform + Ansible + Kubernetes + GitOps 기반 표준 플랫폼 구축 프로젝트
