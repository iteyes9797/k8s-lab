variable "location" {
  description = "Azure region"
  type        = string
  default     = "koreacentral"
}

variable "resource_group_name" {
  description = "Resource group name"
  type        = string
  default     = "rg-k8s-lab-min"
}

variable "vm_name" {
  description = "Virtual machine name"
  type        = string
  default     = "vm-test-01"
}

variable "vm_size" {
  description = "VM size (low-cost default)"
  type        = string
  default     = "Standard_B1s"
}

variable "admin_username" {
  description = "Admin username"
  type        = string
  default     = "azureuser"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key"
  type        = string
  default     = "~/.ssh/id_rsa.pub"
}

variable "allowed_ssh_cidr" {
  description = "CIDR allowed to SSH (22). Use your public IP CIDR for safety."
  type        = string
  default     = "0.0.0.0/0"
}
