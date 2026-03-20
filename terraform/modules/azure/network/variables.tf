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

variable "public_subnet_cidr" {
  type        = string
  description = "Bastion 호스트가 위치할 Public 서브넷의 CIDR입니다."
  default     = "10.0.2.0/24"
}

variable "private_subnet_cidr" {
  type        = string
  description = "K8s 노드들이 위치할 Private 서브넷의 CIDR입니다."
  default     = "10.0.2.0/24"
}