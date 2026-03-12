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

  # [추가] 리소스 그룹이 완전히 생성된 후에 Bastion을 시작하도록 명시적 의존성 추가
  depends_on = [azurerm_resource_group.rg]
}
