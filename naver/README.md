# Naver Cloud Terraform

Naver Cloud 기반 Kubernetes 랩 인프라를 생성하기 위한 Terraform 코드입니다.

## 구성 리소스

- `ncloud_vpc`: VPC 생성
- `ncloud_subnet`: Public Subnet 생성
- `ncloud_login_key`: 서버 접속용 로그인 키 생성
- `ncloud_server`: VM 생성 (Master, Worker, NFS, LB, Jumpbox)
- `ncloud_network_interface`: VM별 고정 Private IP NIC 생성
- `ncloud_public_ip`: VM별 Public IP 할당
- `ncloud_block_storage`: NFS 서버용 추가 스토리지 생성

## 파일 구조

- `provider.tf`: Terraform/Naver Provider 설정
- `network.tf`: VPC/Subnet 설정
- `compute.tf`: 로그인 키, 서버, NIC, Public IP 설정
- `storage.tf`: NFS 디스크 설정
- `variables.tf`: 공통 변수 정의
- `variables_vms.tf`: VM 목록/사양/사설 IP 정의
- `outputs.tf`: VM Public/Internal IP 출력

## tf 파일별 리소스 상세 설명

### provider.tf

- `terraform.required_providers.ncloud`: Naver Cloud Provider 소스와 버전(`~> 4.0`) 지정
- `provider "ncloud"`: 인증/리전/사이트 설정
  - `access_key`, `secret_key`: API 인증 정보
  - `region`, `site`: 리전/사이트 선택
  - `support_vpc = true`: VPC 환경 사용

### network.tf

- `resource "ncloud_vpc" "vpc"`:
  - Kubernetes 랩에서 사용할 VPC 생성
  - `var.vpc_name`, `var.vpc_cidr` 값 사용
- `resource "ncloud_subnet" "k8s_subnet"`:
  - 위 VPC에 Public Subnet 생성
  - `zone`, `subnet_cidr`, 기본 Network ACL 연결

### compute.tf

- `resource "ncloud_login_key" "loginkey"`:
  - 서버 접속용 로그인 키 리소스 생성 (`var.login_key_name`)
- `resource "ncloud_server" "vm"`:
  - `var.vms` 맵을 `for_each`로 순회하며 VM 생성
  - VM 이름/스펙/이미지/존/키를 변수로 제어
- `resource "ncloud_network_interface" "nic"`:
  - VM별 NIC 생성 및 `private_ip`를 고정 할당
  - 기본 Access Control Group 연결
- `resource "ncloud_public_ip" "pip"`:
  - 생성된 VM 각각에 Public IP 할당

### storage.tf

- `resource "ncloud_block_storage" "nfs_disk"`:
  - `nfs` VM에 추가 블록 스토리지 연결
  - 크기는 `var.nfs_disk_size_gb`로 제어

### outputs.tf

- `output "vm_public_ips"`: VM Key 기준 Public IP 맵 출력
- `output "vm_internal_ips"`: VM Key 기준 Internal IP 맵 출력

### variables_vms.tf

- `variable "vms"`:
  - VM 정의용 맵 변수
  - 각 항목에 `name`, `ip`, `spec_code` 포함
  - 기본값으로 `jumpbox`, `master(3)`, `worker(2)`, `nfs`, `lb` 구성

## variables.tf 상세 설명

- `access_key`:
  - Naver Cloud API Access Key (필수, 민감정보)
- `secret_key`:
  - Naver Cloud API Secret Key (필수, 민감정보)
- `region`:
  - 리전 코드, 기본값 `KR`
- `site`:
  - 사이트 구분, 기본값 `public`
- `zone`:
  - 존 코드, 기본값 `KR-2`
- `vpc_name`:
  - 생성할 VPC 이름, 기본값 `k8s-vpc`
- `vpc_cidr`:
  - VPC 대역, 기본값 `192.168.0.0/16`
- `subnet_name`:
  - 서브넷 이름, 기본값 `k8s-subnet`
- `subnet_cidr`:
  - 서브넷 대역, 기본값 `192.168.0.0/24`
- `login_key_name`:
  - VM에 적용할 로그인 키 리소스명, 기본값 `k8s-lab-login-key`
- `server_image_number`:
  - VM 이미지 번호, 기본값 `25495367`
  - 리전/존별 가용 이미지가 다를 수 있으므로 필요 시 변경
- `nfs_disk_size_gb`:
  - NFS 서버 추가 디스크 크기(GB), 기본값 `100`

## 사전 준비

1. Terraform 설치
2. Naver Cloud API Key 준비 (`access_key`, `secret_key`)
3. 필요한 경우 `server_image_number`, `zone`, `spec_code`를 환경에 맞게 수정

## 사용 방법

```bash
cd naver
terraform init
terraform plan -var "access_key=YOUR_ACCESS_KEY" -var "secret_key=YOUR_SECRET_KEY"
terraform apply -var "access_key=YOUR_ACCESS_KEY" -var "secret_key=YOUR_SECRET_KEY"
```

변수를 파일로 관리하려면 `terraform.tfvars`를 생성해 아래처럼 사용합니다.

```hcl
access_key = "YOUR_ACCESS_KEY"
secret_key = "YOUR_SECRET_KEY"
region     = "KR"
site       = "public"
zone       = "KR-2"
```

```bash
terraform plan
terraform apply
```

## 주요 커스터마이징 포인트

- `variables_vms.tf`의 `vms` 맵:
  - VM 개수, 이름, 고정 Private IP, 스펙(`spec_code`) 조정
- `variables.tf`:
  - `vpc_cidr`, `subnet_cidr`, `login_key_name`, `server_image_number`, `nfs_disk_size_gb` 조정

## 출력값

- `vm_public_ips`: VM별 Public IP
- `vm_internal_ips`: VM별 Internal IP

```bash
terraform output vm_public_ips
terraform output vm_internal_ips
```

## 삭제

```bash
terraform destroy -var "access_key=YOUR_ACCESS_KEY" -var "secret_key=YOUR_SECRET_KEY"
```

## 참고

- `.terraform/`, 실행 파일, 상태 파일(`*.tfstate`)은 Git에 커밋하지 않는 것을 권장합니다.
