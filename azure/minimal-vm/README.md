# Azure Minimal VM (Test)

테스트 용도로 단일 Linux VM 1대를 최소 사양으로 생성하는 Terraform 구성입니다.

## 생성 리소스

- Resource Group 1개
- Virtual Network / Subnet 각 1개
- Network Security Group 1개 (SSH 22 포트 허용)
- Public IP 1개
- Network Interface 1개
- Linux VM 1개 (`Standard_B1s`, Ubuntu 22.04 LTS)

## 비용 최소화 포인트

- VM 크기 기본값: `Standard_B1s`
- OS 디스크: `Standard_LRS` 30GB
- 추가 데이터 디스크 없음

## 사용 방법

```bash
cd azure/minimal-vm
cp terraform.tfvars.template terraform.tfvars
terraform init
terraform plan
terraform apply
```

적용 후 접속:

```bash
terraform output ssh_command
```

## 보안 권장

- `allowed_ssh_cidr`를 `0.0.0.0/0` 대신 본인 공인 IP `/32`로 제한하세요.

## 삭제

```bash
terraform destroy
```
