output "internal_ips" {
  description = "생성된 각 노드(NIC)의 사설 IP 주소를 맵 형태로 출력합니다."
  value = { for k, v in azurerm_network_interface.nic : k => v.private_ip_address }
}

# 이 출력값은 비어있거나 관리용으로만 남겨둡니다.
output "public_ips" {
  description = "VM 노드들의 공인 IP (사설망 구성이므로 기본적으로 비어있음)"
  value       = { for k, v in azurerm_linux_virtual_machine.vm : k => v.public_ip_address if v.public_ip_address != null }
}