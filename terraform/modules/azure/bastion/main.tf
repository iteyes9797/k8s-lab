# 현재 내 공인 IP를 가져오는 데이터 소스 추가
data "http" "my_public_ip" {
  url = "https://ifconfig.me/ip"
}

# 1. Bastion 전용 공인 IP 생성
resource "azurerm_public_ip" "bastion_pip" {
  name                = "bastion-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"  
}

# 2. Bastion 네트워크 인터페이스 (NIC)
resource "azurerm_network_interface" "bastion_nic" {
  name                = "bastion-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.bastion_pip.id
  }
}

# 3. Bastion 가상 머신 생성
resource "azurerm_linux_virtual_machine" "bastion" {
  name                = "bastion-host"
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = "Standard_D2s_v3"
  admin_username      = var.admin_username
  tags = {
    "project"     = "k8s-automation-lab"
    "role"        = "bastion"
    "managed_by"  = "terraform"
  }

  network_interface_ids = [
    azurerm_network_interface.bastion_nic.id,
  ]

  admin_ssh_key {
    username   = var.admin_username
    public_key = file(var.ssh_public_key)
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# 4. Bastion 전용 NSG (Bastion NIC에만 적용)
resource "azurerm_network_security_group" "bastion_nsg" {
  name                = "bastion-nsg"
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

# 5. NIC와 NSG 연결 (VM 개별 보안)
resource "azurerm_network_interface_security_group_association" "bastion_nic_assoc" {
  network_interface_id      = azurerm_network_interface.bastion_nic.id
  network_security_group_id = azurerm_network_security_group.bastion_nsg.id
}