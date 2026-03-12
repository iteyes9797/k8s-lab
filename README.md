# K8S-LAB: All-in-One Infrastructure & GitOps Platform

> **인프라 생성부터 애플리케이션 배포까지, 단 한 줄의 명령어로 완성하는 통합 자동화 프로젝트**

본 프로젝트는 수동 설정 중심의 기존 방식(AS-IS)을 탈피하여, **Terraform, Ansible, Helm, ArgoCD**를 유기적으로 결합한 **IaC(Infrastructure as Code) 및 GitOps 표준 모델**을 제시합니다.

---

## 핵심 개선 사항 (Key Highlights)

* **Zero-Touch Provisioning**: `run.sh` 하나로 Azure 리소스 생성 및 K8s 클러스터 완전 자동 구축을 지원합니다.
* **Security First**: **Bastion 호스트**를 통한 SSH 터널링 구조를 도입하여 내부 노드 보안을 강화하고 인증을 자동화했습니다.
* **Environment Independence**: 실행 환경(WSL2 등)을 스스로 진단하고 필수 키와 비밀번호를 자동 생성하는 자가 치유형 스크립트를 적용했습니다.
* **Declarative GitOps**: ArgoCD를 통해 `argoCd/` 폴더 내 애플리케이션 상태를 실시간으로 동기화합니다.

---

## 퀵 스타트 (Quick Start)

신규 환경에서 프로젝트 워크플로우를 실행하기 위한 가이드입니다. **파일 권한 문제 및 실행 오류 방지를 위해 반드시 WSL 내부 경로 사용을 준수하십시오.**

### 0. WSL2 활성화 (Windows 최초 실행 시)
Windows 환경에서 리눅스 커널을 사용하기 위한 필수 선행 단계입니다.
* **PowerShell(관리자)**에서 실행: `wsl --install`
* 설치 완료 후 **PC를 반드시 재부팅**하십시오.

### 1. 프로젝트 환경 구축 (WSL 내부 경로 이동)
* 윈도우 드라이브와 WSL 간의 파일 권한(Permission) 충돌을 방지하기 위해 프로젝트를 WSL 홈 디렉토리로 복사하여 진행합니다.

#### 1) 프로젝트 폴더를 WSL 내부로 복사 및 이동
cp -rv "Windows에서 설치된 경로/." ~/k8s-lab/
cd ~/k8s-lab

#### 2) 윈도우에서 넘어온 잘못된 실행 권한 초기화
##### 모든 파일의 실행 권한을 제거한 뒤, 필요한 스크립트만 다시 부여합니다.
find . -type f -exec chmod -x {} +
chmod +x run.sh
chmod 600 .vault_pass

### 2. 호스트 환경 준비 (WSL2 / Ubuntu 기준)
WSL 터미널을 열고 아래 명령어를 입력하여 필수 도구를 설치합니다.

#### * 필수 유틸리티 및 Azure CLI 설치
sudo apt update && sudo apt install -y git python3-pip unzip curl jq
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

#### * Helm 설치 (K8s 패키지 매니저)
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

#### * ArgoCD CLI 설치 (GitOps 제어용)
curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd && rm argocd-linux-amd64

### 3. 클라우드 인증 및 초기화
* **Azure 로그인**: `az login` (명령어 입력 시, 브라우저 인증 창이 뜹니다.)
* **권한 부여**: 로그인이 완료되면 다시 WSL 터미널로 돌아와 프로젝트 폴더 위치를 확인합니다.

### 4. 통합 배포 프로세스 실행 (One-Click)
* **명령어**: `./run.sh`
* **동작 방식**: 스크립트가 실행되면 아래 과정이 **자동**으로 진행됩니다.
    > **SSH Key 생성** → **Terraform 인프라 프로비저닝** → **Ansible 클러스터 구축** → **Helm/ArgoCD 서비스 배포**

---

## 시스템 아키텍처 (Architecture)

* **Infrastructure**: Azure VM(Master, Worker, NFS), VNet/Subnet 구성을 Terraform으로 자동화합니다.
* **Configuration**: K8s 클러스터(v1.32.0) 및 CRI-O 컨테이너 런타임을 Ansible로 구축합니다.
* **Storage**: NFS Subdir External Provisioner를 통해 동적 PV/PVC 관리를 자동화합니다.
* **GitOps**: `argoCd/` 폴더 내 매니페스트를 ArgoCD로 동기화하여 서비스를 배포합니다.

---

## 프로젝트 표준 구조 (Standard Directory)

- **argoCd/**: GitOps Application 설정 및 매니페스트
- **ansible/**: K8s 구축을 위한 Role 기반 플레이북 (Bastion 터널링 포함)
- **terraform/**: IaC 모듈 및 Azure Live 환경 설정
- **helm/**: NFS 및 주요 서비스용 Helm Values
- **docker/**: 빌드 및 실행 환경 표준화를 위한 Dockerfiles
- **run.sh**: 통합 자동화 실행 스크립트
- **ARCHITECTURE_REVIEW.md**: 아키텍처 개선 상세 리포트

---

## 🔗 상세 문서 안내

본 프로젝트의 기술적 의사결정 과정과 개선 내역은 아래 문서에서 확인하실 수 있습니다.

### 👉 [ARCHITECTURE_REVIEW.md](./ARCHITECTURE_REVIEW.md)
* **AS-IS vs TO-BE 상세 비교**: 과거 수동 구축 대비 개선된 자동화/보안 아키텍처 분석
* **보안 강화**: Bastion 기반 보안 관문 일원화 및 SSH 자동 주입 로직 설명
* **기술 표준**: Terraform 모듈화 및 Ansible Role 체계화 근거 제시
* **부채 제거**: 중복 코드 및 구형 설정 파일 정리 내역

### 👉 [TROUBLE_SHOOTING.md](./TROUBLE_SHOOTING.md)
* **핵심 해결 사례**: 앤서블 터널링, Kubeadm 인증서 오류, NFS IP 동적 주입 등 실제 구축 과정에서 해결한 기술적 난제 기록

### 👉 [CONTRIBUTING.md](./CONTRIBUTING.md)
* **협업 및 브랜치 전략**: `main`과 `setup` 브랜치를 활용한 Git 작업 흐름 및 PR(Pull Request) 정책 안내