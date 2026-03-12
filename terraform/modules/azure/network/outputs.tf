output "subnet_id" {
  description = "생성된 서브넷의 고유 ID입니다. 다른 모듈에서 NIC 연결 시 사용합니다."
  value       = azurerm_subnet.subnet.id
}

output "vnet_name" {
  description = "생성된 가상 네트워크의 이름입니다."
  value       = azurerm_virtual_network.vnet.name
}