variable "resource_group_name" {
  type        = string
  description = "Root로부터 전달받은 리소스 그룹의 이름입니다."
}

variable "location" {
  type        = string
  description = "VM이 배치될 Azure 리전입니다."
}

variable "subnet_id" {
  type        = string
  description = "VM NIC가 연결될 네트워크 서브넷의 ID입니다."
}

variable "ssh_public_key" {
  type        = string
  description = "VM 인증에 사용할 SSH 공개키 파일의 경로입니다."
}

variable "nodes" {
  type        = map(string)
  description = "생성할 노드들의 이름과 사이즈(SKU) 맵입니다."
}

variable "node_ips" {
  type        = map(string)
  description = "각 노드에 고정(Static) 할당할 사설 IP 주소 맵입니다."
}

variable "assign_public_ip" {
  type        = bool
  default     = false
  description = "노드에 공인 IP를 할당할지 여부를 결정합니다."
}