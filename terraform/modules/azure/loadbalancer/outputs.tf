# 1. 백엔드 풀 ID (워커 노드들을 연결할 때 사용)
output "backend_pool_id" {
  description = "로드밸런서 백엔드 주소 풀의 ID"
  value       = azurerm_lb_backend_address_pool.pool.id
}

# 2. 로드밸런서 공인 IP (접속 확인 및 외부 노출용)
output "public_ip" {
  description = "로드밸런서의 공인 IP 주소"
  value       = azurerm_public_ip.lb_pip.ip_address
}

# 3. 로드밸런서 ID (관리용)
output "lb_id" {
  description = "생성된 로드밸런서의 리소스 ID"
  value       = azurerm_lb.main.id
}