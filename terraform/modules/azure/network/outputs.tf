output "vnet_name" {
  description = "생성된 가상 네트워크의 이름입니다."
  value       = azurerm_virtual_network.vnet.name
}

output "public_subnet_id" {
  description = "Bastion 호스트가 위치할 공용 서브넷의 ID입니다."
  value       = azurerm_subnet.public.id
}

output "private_subnet_id" {
  description = "K8s 노드(Master, Worker 등)가 위치할 사설 서브넷의 ID입니다."
  value       = azurerm_subnet.private.id
}

# 💡 팁: 기존 코드와의 호환성을 위해 subnet_id를 남겨두되, 
# 기본적으로 사설망 ID를 바라보게 설정합니다. -> 추후 제거 가능
output "subnet_id" {
  description = "기본 서브넷 ID (사설망 보호를 위해 private_subnet_id를 반환)"
  value       = azurerm_subnet.private.id
}