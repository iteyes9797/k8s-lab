resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

module "network" {
  source = "../../modules/azure/network"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  vnet_cidr           = var.vnet_cidr
  subnet_cidr         = var.subnet_cidr
}

module "vm" {
  source = "../../modules/azure/vm"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  subnet_id           = module.network.subnet_id
  ssh_public_key      = var.ssh_public_key

  nodes = var.nodes
  node_ips = var.node_ips
}

module "bastion" {
  source = "../../modules/azure/bastion"

  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  
  subnet_id      = module.network.subnet_id
  ssh_public_key = var.ssh_public_key

  # 리소스 그룹이 완전히 생성된 후에 Bastion을 시작하도록 명시적 의존성 추가
  depends_on = [azurerm_resource_group.rg]
}

resource "local_file" "ansible_inventory" {
  content = templatefile("${path.module}/../../inventory.tpl", 
    {
      master1    = lookup(module.vm.internal_ips, "k8s-master01", "")
      master2    = lookup(module.vm.internal_ips, "k8s-master02", "")
      master3    = lookup(module.vm.internal_ips, "k8s-master03", "")
      worker1    = lookup(module.vm.internal_ips, "k8s-worker01", "")
      worker2    = lookup(module.vm.internal_ips, "k8s-worker02", "")
      nfs        = lookup(module.vm.internal_ips, "k8s-nfs01", "")
      lb         = lookup(module.vm.internal_ips, "k8s-lb01", "")
      
      bastion_ip = module.bastion.public_ip 
    }
  )
  filename = "${path.module}/../../inventory.ini"
}