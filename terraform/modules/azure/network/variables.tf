variable "resource_group_name" {
  type        = string
  description = "네트워크 리소스가 생성될 리소스 그룹의 이름입니다."
}

variable "location" {
  type        = string
  description = "네트워크 리소스가 배치될 Azure 리전입니다."
}

variable "vnet_cidr" {
  type        = string
  description = "가상 네트워크(VNet)의 전체 IP 주소 공간입니다. (기본값: 10.0.0.0/16)"
}

variable "subnet_cidr" {
  type        = string
  description = "VM들이 배치될 서브넷의 IP 주소 공간입니다. (기본값: 10.0.1.0/24)"
}