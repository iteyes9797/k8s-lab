# variable "location" {
#   description = "The Azure Region in which all resources in this example should be created."
#   default     = "Korea Central"
# }

# variable "resource_group_name" {
#   description = "The name of the Resource Group in which all resources in this example should be created."
#   default     = "k8s-lab-rg"
# }

# variable "admin_username" {
#   description = "The user name to use for the VMs"
#   default     = "azureuser"
# }

# variable "admin_password" {
#   description = "The password to use for the VMs"
#   default     = "P@ssw0rd1234!"
# }

# variable "ssh_public_key_path" {
#   description = "Path to SSH public key used for VM provisioning"
#   default     = "~/.ssh/id_rsa.pub"
# }

variable "resource_group_name" {
  type        = string
  description = "리소스가 생성될 Azure 리소스 그룹의 이름입니다."
  default     = "k8s-lab-db-rg"
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

variable "subnet_cidr" {
  type        = string
  description = "VM들이 배치될 서브넷(Subnet)의 IP 주소 대역입니다."
  default     = "10.0.1.0/24"
}

variable "ssh_public_key" {
  type        = string
  description = "VM 관리자 계정 인증에 사용할 로컬 SSH 공개키 파일의 경로입니다."
  default     = "~/.ssh/id_rsa.pub"
}

variable "nodes" {
  type        = map(string)
  description = "Kubernetes 클러스터 노드의 이름과 각각의 VM 인스턴스 크기(SKU) 정의입니다."
  default = {
    master1 = "Standard_D2s_v3"
    master2 = "Standard_D2s_v3"
    master3 = "Standard_D2s_v3"
    worker1 = "Standard_D2s_v3"
    worker2 = "Standard_D2s_v3"
    nfs     = "Standard_D2s_v3"
    lb      = "Standard_D2s_v3"
  }
}

variable "node_ips" {
  type        = map(string)
  description = "Ansible 및 클러스터 설정의 정합성을 위해 각 노드에 고정 할당할 사설 IP 주소 매핑 정보입니다."
  default = {
    master1 = "10.0.1.10"
    master2 = "10.0.1.11"
    master3 = "10.0.1.12"
    worker1 = "10.0.1.21"
    worker2 = "10.0.1.22"
    nfs     = "10.0.1.30"
    lb      = "10.0.1.110"
  }
}