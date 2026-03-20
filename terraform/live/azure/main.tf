resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

module "network" {
  source = "../../modules/azure/network"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  vnet_cidr           = var.vnet_cidr
  public_subnet_cidr  = "10.0.1.0/24"  
  private_subnet_cidr = "10.0.2.0/24"  
}

module "vm" {
  source = "../../modules/azure/vm"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  subnet_id           = module.network.private_subnet_id
  ssh_public_key      = var.ssh_public_key

  nodes = var.nodes
  node_ips = var.node_ips

  assign_public_ip = false
}

module "bastion" {
  source = "../../modules/azure/bastion"

  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  
  subnet_id      = module.network.public_subnet_id
  ssh_public_key = var.ssh_public_key

  depends_on = [azurerm_resource_group.rg]
}

# 1. Ansible용 인벤토리 파일 생성
resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../../inventory.tpl", 
    {
      bastion_ip = module.bastion.public_ip 
      
      master1    = lookup(module.vm.internal_ips, "master1", "")
      master2    = lookup(module.vm.internal_ips, "master2", "")
      master3    = lookup(module.vm.internal_ips, "master3", "")
      worker1    = lookup(module.vm.internal_ips, "worker1", "")
      worker2    = lookup(module.vm.internal_ips, "worker2", "")
      nfs        = lookup(module.vm.internal_ips, "nfs", "")
      lb         = lookup(module.vm.internal_ips, "lb", "")   
    }
  )
  filename = "${path.module}/../../inventory.ini"
}

# 2. 로컬 PC 접속용 SSH 설정 파일 생성
resource "local_file" "ssh_config" {
  content = templatefile("${path.module}/../../ssh_config.tpl", {
    bastion_ip = module.bastion.public_ip
    
    master1    = lookup(module.vm.internal_ips, "master1", "")
    master2    = lookup(module.vm.internal_ips, "master2", "")
    master3    = lookup(module.vm.internal_ips, "master3", "")
    worker1    = lookup(module.vm.internal_ips, "worker1", "")
    worker2    = lookup(module.vm.internal_ips, "worker2", "")
    nfs        = lookup(module.vm.internal_ips, "nfs", "")
    lb         = lookup(module.vm.internal_ips, "lb", "")
  })
  filename = "${path.module}/../../ssh_config"
}

# 3. 로드밸런서 모듈 호출
module "loadbalancer" {
  source = "../../modules/azure/loadbalancer"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
}

# 4. 워커 노드들을 로드밸런서 백엔드 풀에 연결 (연결 고리)
resource "azurerm_network_interface_backend_address_pool_association" "k8s_workers" {
  # var.nodes 맵에서 키 이름에 "worker"가 포함된 노드만 골라냅니다.
  for_each = { for k, v in var.nodes : k => v if length(regexall("worker", k)) > 0 }

  network_interface_id    = module.vm.nic_ids[each.key]
  ip_configuration_name   = "internal" # modules/azure/vm/main.tf 내 ip_configuration 이름
  backend_address_pool_id = module.loadbalancer.backend_pool_id
}

# 5. 로드밸런서 공인 IP 출력
output "load_balancer_public_ip" {
  value = module.loadbalancer.public_ip
}