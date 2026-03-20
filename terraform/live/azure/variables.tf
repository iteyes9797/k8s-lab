variable "resource_group_name" {
  type        = string
  description = "리소스가 생성될 Azure 리소스 그룹의 이름입니다."
  default     = "ite-k8s-rg"
}

variable "location" {
  type        = string
  description = "리소스가 배치될 Azure 리전(Region)입니다."
  default     = "koreacentral"
}

variable "vnet_cidr" {
  type        = string
  description = "가상 네트워크(VNet)에서 사용할 IP 주소 대역입니다."
  default     = "10.0.0.0/16"
}

# Public Subnet (Bastion 전용)
variable "public_subnet_cidr" {
  type        = string
  description = "Bastion 호스트가 배치될 외부 노출용 서브넷 대역입니다."
  default     = "10.0.1.0/24"
}

# Private Subnet (K8s 노드 전용)
variable "subnet_cidr" {
  type        = string
  description = "K8s 노드들이 배치될 사설 서브넷의 기본 CIDR입니다."
  default     = "10.0.2.0/24"
}

variable "admin_username" {
  type        = string
  description = "VM에 접속할 관리자 계정 이름입니다."
  default     = "azureuser"
}

variable "ssh_public_key" {
  type        = string
  description = "RSA 공개키 파일의 경로입니다." 
  default     = "~/.ssh/id_rsa.pub"
}

variable "nodes" {
  type        = map(string)
  description = "노드별 VM 인스턴스 크기 정의"
  default = {
    # bastion = "Standard_B1s"        # 가장 작은 단위 (1 vCPU, 1GB RAM - 비용 절감)
    master1 = "Standard_D2s_v3"
    master2 = "Standard_D2s_v3"
    master3 = "Standard_D2s_v3"
    worker1 = "Standard_D4s_v3"     # D2s보다 높은 D4s_v3 (4 vCPU, 16GB RAM)
    worker2 = "Standard_D4s_v3"     # Worker 성능 대폭 강화
    nfs     = "Standard_D2s_v3"
    lb      = "Standard_D2s_v3"
  }
}

variable "node_ips" {
  type        = map(string)
  description = "고정 IP 할당 정보"
  default = {
    # bastion = "10.0.1.10"           # Public 대역
    master1 = "10.0.2.10"           # 이하 Private 대역
    master2 = "10.0.2.11"
    master3 = "10.0.2.12"
    worker1 = "10.0.2.21"
    worker2 = "10.0.2.22"
    nfs     = "10.0.2.30"
    lb      = "10.0.2.110"
  }
}