data "http" "my_public_ip" {
  url = "https://ifconfig.me/ip"
}

resource "azurerm_virtual_network" "vnet" {
  name                = "k8s-vnet"
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = [var.vnet_cidr]
  tags = {
    "project"     = "k8s-automation-lab"
    "environment" = "sandbox"
  }
}

# 1. Public Subnet (Bastion 전용)
resource "azurerm_subnet" "public" {
  name                 = "snet-public"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"] # Bastion 구역
}

# 2. Private Subnet (K8s Nodes 전용)
resource "azurerm_subnet" "private" {
  name                 = "snet-private"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"] # K8s 구역
}

# 3. Public NSG (Bastion용: 내 PC에서만 접속 허용)
resource "azurerm_network_security_group" "public_nsg" {
  name                = "nsg-public"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowSSHFromMyIP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "${chomp(data.http.my_public_ip.response_body)}/32"
    destination_address_prefix = "*"
  }
}

# 4. Private NSG (K8s용: Bastion 및 서브넷 내부 통신만 허용)
resource "azurerm_network_security_group" "private_nsg" {
  name                = "nsg-private"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Bastion 서브넷(10.0.2.0/24)에서 오는 모든 통신 허용
  security_rule {
    name                       = "AllowTrafficFromBastion"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }

  # 같은 서브넷 내부 통신 허용 (노드 간 통신)
  security_rule {
    name                       = "AllowInternalTraffic"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "10.0.2.0/24"
    destination_address_prefix = "*"
  }
}

# 5. 서브넷-NSG 연결
resource "azurerm_subnet_network_security_group_association" "public_assoc" {
  subnet_id                 = azurerm_subnet.public.id
  network_security_group_id = azurerm_network_security_group.public_nsg.id
}

resource "azurerm_subnet_network_security_group_association" "private_assoc" {
  subnet_id                 = azurerm_subnet.private.id
  network_security_group_id = azurerm_network_security_group.private_nsg.id
}