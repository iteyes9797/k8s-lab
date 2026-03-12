output "public_ip" {
  description = "외부에서 Bastion에 접속할 때 사용할 공인 IP 주소입니다."
  value       = azurerm_public_ip.bastion_pip.ip_address
}

output "bastion_id" {
  description = "생성된 Bastion VM의 리소스 ID입니다."
  value       = azurerm_linux_virtual_machine.bastion.id
}