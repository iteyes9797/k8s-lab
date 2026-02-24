# Azure Terraform Infrastructure for Kubernetes Lab

This directory contains Terraform configuration files to provision the infrastructure described in the root `README.md`.

## Resources Created

- **Resource Group**: `k8s-lab-rg`
- **Virtual Network**: `192.168.0.0/16`
- **Subnet**: `192.168.0.0/24`
- **Virtual Machines**:
  - `k8s-master01` (192.168.0.106)
  - `k8s-master02` (192.168.0.107)
  - `k8s-master03` (192.168.0.108)
  - `k8s-worker01` (192.168.0.111)
  - `k8s-worker02` (192.168.0.112)
  - `nfs` (192.168.0.109) + 100GB Data Disk
  - `lb-proxy` (192.168.0.110)
  - `jumpbox` (192.168.0.5)

## 파일 구성  
provider.tf: Azure Provider 설정 (azurerm)
variables.tf: 기본 변수 설정 (Region, RG Name, Admin User 등)
variables_vms.tf: 서버 목록 및 고정 IP 설정 (Master 3대, Worker 2대, LB, NFS, Jumpbox)
network.tf: VNet(192.168.0.0/16), Subnet(192.168.0.0/24), NSG 생성
compute.tf: 각 노드별 VM 생성 로직 (Ubuntu 22.04 LTS), Public IP 및 NIC 할당
storage.tf: NFS 서버용 100GB 데이터 디스크 생성 및 연결
outputs.tf: 생성된 VM들의 Public IP 및 Private IP 출력 설정

## VM서버 CPU Memory 사양

**옵션 1: 일반적인 Lab 사양 (선택)**
크기: Standard_D2s_v3
사양: 2 vCPU, 8 GiB RAM
특징: 대부분의 학습용 파드와 가벼운 빌드 작업에 충분합니다. 
선택 이유 : 워커노드를 Standard_D4s_v3 (4 vCPU, 16 GiB RAM) 로 설정한 이유는 이 Lab 환경에서 Argo CD와 Argo Workflows(CI), 그리고 Java 빌드 등 리소스를 많이 사용하는 작업이 원활하게 돌아가도록 넉넉하게 잡은 권장 사양입니다.

**옵션 2: 최소 사양 (비용 최적화)**
크기: Standard_B2s
사양: 2 vCPU, 4 GiB RAM
특징: 기본적인 파드 실행은 가능하지만, Java 빌드나 무거운 앱 실행 시 메모리 부족(OOM)이 발생할 수 있습니다.

**옵션 3: 추천 사양**
Worker Node (w1, w2): 8 vCPU, 32 GiB RAM (Standard_D8s_v3)
이유: 여러 개의 Pod와 Java 애플리케이션, 그리고 CI/CD 빌드 작업이 동시에 돌아갈 때 메모리 부족(OOM) 방지. 실제 운영 환경에 가까운 스펙입니다.
Master Node (m1, m2, m3): 4 vCPU, 16 GiB RAM (Standard_D4s_v3)
이유: etcd와 컨트롤 플레인 컴포넌트의 안정성 확보. 노드가 많아지거나 요청이 많을 때 API 서버의 응답 속도 유지.

## Prerequisites (사전 요구 사항)

이 Terraform 스크립트를 실행하기 전에 다음 도구들이 설치되어 있어야 합니다.

### 1. Azure CLI 설치 및 로그인
윈도우, macOS, Linux에서 Azure 리소스를 관리하기 위해 Azure CLI가 필요합니다.

*   **설치 방법:**
    *   **Windows**: [MS 공식 설치 가이드](https://learn.microsoft.com/ko-kr/cli/azure/install-azure-cli-windows)를 참고하거나 PowerShell에서 `winget install -e --id Microsoft.AzureCLI` 실행
    *   **macOS**: `brew install azure-cli`
    *   **Linux**: [MS 공식 설치 가이드](https://learn.microsoft.com/ko-kr/cli/azure/install-azure-cli-linux) 참고

*   **로그인 실행:**
    터미널에서 아래 명령어를 입력하여 Azure 계정에 로그인합니다. 브라우저 창이 뜨면 로그인하세요.
    ```bash
    az login
    ```

*   **구독 확인:**
    올바른 구동이 선택되었는지 확인합니다.
    ```bash
    az account show
    ```

### 2. Terraform 설치
*   **설치 방법:** [Terraform 공식 다운로드 페이지](https://developer.hashicorp.com/terraform/downloads)에서 OS에 맞는 버전을 다운로드
*   **파일 복사 :** `terraform.exe` 실행 파일을 `azure/` 디렉토리에 복사하거나, 시스템 PATH에 추가하여 어디서든 실행할 수 있도록 설정하세요.   (예시: `azure/terraform`)
*   PATH에 등록합니다.
    *   **Windows**: 시스템 환경 변수 편집에서 `Path`에 `C:\path\to\azure` 추가
    *   **macOS/Linux**: `~/.bashrc` 또는 `~/.zshrc`에 `export PATH="$PATH:/path/to/azure"` 추가 후 터미널 재시작
*   **버전 확인:**
    ```bash
    terraform -v
    ```

## Configuration (환경 설정)

VM 접속을 위한 사용자 계정, 비밀번호, SSH 키 설정 방법입니다.

### 1. SSH 키 생성 및 설정
Terraform 스크립트는 기본적으로 로컬 사용자 홈 디렉토리의 `~/.ssh/id_rsa.pub` 키를 사용하여 VM에 주입하도록 설정되어 있습니다.

1.  **SSH 키 존재 확인:**
    ```bash
    # Windows PowerShell
    Test-Path $env:USERPROFILE\.ssh\id_rsa.pub

    # Mac/Linux
    ls ~/.ssh/id_rsa.pub
    ```

2.  **SSH 키 생성 (없는 경우):**
    키가 없다면 아래 명령어로 생성합니다. 모든 질문에 엔터(Enter)를 누르면 됩니다.
    ```bash
    # Windows PowerShell
    ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa
    # 키 내용 확인
    Get-Content "$env:USERPROFILE\.ssh\id_rsa.pub"
    
    # Mac/Linux
    ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa
    ```

3.  **Terraform 설정 확인(경로 변수화):**
        공개키 경로는 `variables.tf`의 `ssh_public_key_path` 변수로 관리됩니다.
        기본값은 `~/.ssh/id_rsa.pub`이며, 실행 환경에 따라 아래처럼 바꿔 사용할 수 있습니다.

```hcl
# variables.tf 예시
variable "ssh_public_key_path" {
    description = "Path to SSH public key used for VM provisioning"
    default     = "~/.ssh/id_rsa.pub"
}
```

- Windows PowerShell 실행 시: 기본값 그대로 사용 가능 (`~`가 사용자 홈으로 확장)
- 컨테이너/WSL 실행 시: 해당 환경의 홈 경로 기준으로 키 파일 위치를 맞춰 설정
- 필요 시 `terraform.tfvars`에서 오버라이드 가능:

```hcl
ssh_public_key_path = "~/.ssh/id_rsa.pub"
```

4.  **환경별 변수 파일 사용(권장):**
    `terraform.tfvars.template`을 복사해서 `terraform.tfvars`를 만든 뒤 환경에 맞게 수정하면, `variables.tf`를 직접 바꾸지 않고도 실행 환경을 전환할 수 있습니다.

```bash
# Windows PowerShell
Copy-Item terraform.tfvars.template terraform.tfvars

# Mac/Linux
cp terraform.tfvars.template terraform.tfvars
```

`terraform.tfvars` 예시(Windows):
```hcl
ssh_public_key_path = "~/.ssh/id_rsa.pub"
```

`terraform.tfvars` 예시(Dev Container/WSL):
```hcl
ssh_public_key_path = "/home/vscode/.ssh/id_rsa.pub"
```

### 2. 관리자 계정(Username) 및 비밀번호 수정
기본 설정된 사용자 이름과 비밀번호를 변경하려면 `variables.tf` 파일을 수정해야 합니다.

*   **파일 위치:** `azure/variables.tf`
*   **수정 항목:**
    *   `variable "admin_username"`: VM 로그인 ID (기본값: `azureuser`)
    *   `variable "admin_password"`: VM 로그인 비밀번호 (기본값: `P@ssw0rd1234!`)
    *   *주의: 비밀번호는 복잡성 요구사항(자릿수, 특수문자 등)을 충족해야 합니다.*

```hcl
# variables.tf 예시
variable "admin_username" {
  description = "The user name to use for the VMs"
  default     = "myadmin"  # <-- 원하는 ID로 변경
}

variable "admin_password" {
  description = "The password to use for the VMs"
  default     = "MyStrongPass123!" # <-- 원하는 비밀번호로 변경
}
```

## Usage

1. Initialize Terraform:
   ```bash
   terraform init
   ```

2. Validate configuration:
    ```bash
    terraform validate
    ```

3. (Optional) Create environment-specific variables file:
    ```bash
    # Windows PowerShell
    Copy-Item terraform.tfvars.template terraform.tfvars
    ```

4. Review the plan:
   ```bash
   terraform plan
   ```

5. Apply the configuration:
   ```bash
   terraform apply
   ```

6. Retrieve Public IPs:
   ```bash
   terraform output vm_public_ips
   ```

7. Configure `hosts.ini`:
   Update `../inventories/production/hosts.ini` with the new Public IPs (if connecting remotely) or use internal IPs if running Ansible from the jumpbox.

## Note
- Default admin user: `azureuser`
- Default password: `P@ssw0rd1234!`
- SSH Key: Uses `~/.ssh/id_rsa.pub` by default. Ensure you have generated one (`ssh-keygen`).
- SSH Key path variable: `ssh_public_key_path` in `variables.tf` (override via `terraform.tfvars` if needed).
- Sample vars file: `terraform.tfvars.template` (copy to `terraform.tfvars` and adjust for your environment).
- SSH Key 사용 용도 비교 : Terraform과 Ansible에서 각각 SSH 키가 어떻게 사용되는지에 대한 설명은 `SSH Key 사용 용도 비교.md` 파일을 참고하세요.
