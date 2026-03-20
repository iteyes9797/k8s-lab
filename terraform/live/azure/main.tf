resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

module "network" {
  source = "../../modules/azure/network"

  resource_group_name = azurerm_resource_group.rg.name
  location            = var.location
  vnet_cidr           = var.vnet_cidr
  public_subnet_cidr  = "10.0.2.0/24"  
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