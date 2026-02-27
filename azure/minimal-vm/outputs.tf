output "public_ip" {
  description = "Public IP of the test VM"
  value       = azurerm_public_ip.pip.ip_address
}

output "ssh_command" {
  description = "SSH command example"
  value       = "ssh ${var.admin_username}@${azurerm_public_ip.pip.ip_address}"
}
