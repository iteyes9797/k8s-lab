variable "access_key" {
  description = "NAVER Cloud access key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "NAVER Cloud secret key"
  type        = string
  sensitive   = true
}

variable "region" {
  description = "NAVER Cloud region code"
  type        = string
  default     = "KR"
}

variable "site" {
  description = "NAVER Cloud site"
  type        = string
  default     = "public"
}

variable "zone" {
  description = "NAVER Cloud zone code"
  type        = string
  default     = "KR-2"
}

variable "vpc_name" {
  description = "VPC name"
  type        = string
  default     = "k8s-vpc"
}

variable "vpc_cidr" {
  description = "VPC CIDR block"
  type        = string
  default     = "192.168.0.0/16"
}

variable "subnet_name" {
  description = "Subnet name"
  type        = string
  default     = "k8s-subnet"
}

variable "subnet_cidr" {
  description = "Subnet CIDR block"
  type        = string
  default     = "192.168.0.0/24"
}

variable "login_key_name" {
  description = "Login key name used by server instances"
  type        = string
  default     = "k8s-lab-login-key"
}

variable "server_image_number" {
  description = "Server image number (KVM image). Change per region/zone availability."
  type        = string
  default     = "25495367"
}

variable "nfs_disk_size_gb" {
  description = "Additional block storage size for NFS server (GB)"
  type        = number
  default     = 100
}
