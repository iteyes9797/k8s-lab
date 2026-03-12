# output "vm_public_ips" {
#   value = { for k, v in azurerm_public_ip.pip : k => v.ip_address }
# }

# output "vm_internal_ips" {
#   value = { for k, v in azurerm_network_interface.nic : k => v.private_ip_address }
# }

# Bastion Public IP: 외부에서 접속할 때 가장 먼저 확인해야 할 주소입니다.
output "bastion_public_ip" {
  description = "Bastion 서버의 공인 IP 주소입니다. SSH 접속 시 사용하세요."
  value       = module.bastion.public_ip
}

# VM Internal IPs: Ansible이 내부망에서 통신할 때 사용할 IP들입니다.
output "vm_internal_ips" {
  description = "생성된 각 노드들의 사설 IP 주소 매핑 정보입니다."
  value       = { for k, v in module.vm.internal_ips : k => v }
}

# SSH 접속 가이드 출력 - Bastion을 통한 접속 예시 명령어를 제공합니다.
output "ssh_connect_guide" {
  description = "Bastion을 통한 SSH 접속 가이드 명령어입니다."
  value       = "ssh -i ~/.ssh/id_rsa -J azureuser@${module.bastion.public_ip} azureuser@10.0.1.10"
}