variable "location" {
  type        = string
  description = "Bastion 서버가 생성될 Azure 리전입니다."
}

variable "resource_group_name" {
  type        = string
  description = "Bastion 서버가 소속될 리소스 그룹의 이름입니다."
}

variable "subnet_id" {
  type        = string
  description = "Bastion NIC가 연결될 네트워크 서브넷의 ID입니다."
}

variable "ssh_public_key" {
  type        = string
  description = "Bastion 접속 인증에 사용할 SSH 공개키 파일의 경로입니다."
}

variable "admin_username" {
  type        = string
  description = "Bastion 서버의 관리자 계정 이름입니다."
  default     = "azureuser"
}