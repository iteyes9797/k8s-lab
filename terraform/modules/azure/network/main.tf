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

resource "azurerm_subnet" "subnet" {
  name                 = "k8s-subnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]
}

resource "azurerm_network_security_group" "k8s_nsg" {
  name                = "k8s-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # SSH(22번) 포트 허용 규칙
  security_rule {
    name                       = "AllowSSH"
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

# 2. 서브넷과 보안 그룹 연결
resource "azurerm_subnet_network_security_group_association" "k8s_nsg_assoc" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.k8s_nsg.id
}

