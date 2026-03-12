output "internal_ips" {
  description = "생성된 각 노드(NIC)의 사설 IP 주소를 맵 형태로 출력합니다."
  # NIC 리소스의 사설 IP를 k8s-master01 등의 키와 함께 매핑합니다.
  value = { for k, v in azurerm_network_interface.nic : k => v.private_ip_address }
}

output "public_ip" {
  description = "VM에 할당된 공인 IP 주소 정보입니다 (설정된 경우)."
  value       = { for k, v in azurerm_linux_virtual_machine.vm : k => v.public_ip_address }
}