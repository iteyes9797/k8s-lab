variable "location" {
  description = "The Azure Region in which all resources in this example should be created."
  default     = "Korea Central"
}

variable "resource_group_name" {
  description = "The name of the Resource Group in which all resources in this example should be created."
  default     = "k8s-lab-rg"
}

variable "admin_username" {
  description = "The user name to use for the VMs"
  default     = "azureuser"
}

variable "admin_password" {
  description = "The password to use for the VMs"
  default     = "P@ssw0rd1234!"
}

variable "ssh_public_key_path" {
  description = "Path to SSH public key used for VM provisioning"
  default     = "~/.ssh/id_rsa.pub"
}
