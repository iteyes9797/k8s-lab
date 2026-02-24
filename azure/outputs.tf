output "vm_public_ips" {
  value = { for k, v in azurerm_public_ip.pip : k => v.ip_address }
}

output "vm_internal_ips" {
  value = { for k, v in azurerm_network_interface.nic : k => v.private_ip_address }
}
