# 1. 노드 명명 규칙 가공을 위한 로컬 변수
locals {
  node_names = {
    for k, v in var.nodes : k => 
      k == "lb" ? "lb-proxy" : (
      length(regexall("master", k)) > 0 ? "k8s-master0${substr(k, -1, 1)}" : (
      length(regexall("worker", k)) > 0 ? "k8s-worker0${substr(k, -1, 1)}" : k))
  }
}

# 2. 네트워크 인터페이스 (NIC) 생성 - 고정 IP 할당 반영
resource "azurerm_network_interface" "nic" {
  for_each = var.nodes

  name                = "${local.node_names[each.key]}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    
    # Root variables.tf의 node_ips 맵을 사용하여 Static IP 할당
    private_ip_address_allocation = "Static"
    private_ip_address            = var.node_ips[each.key]
  }
}

# 3. 가상 머신 (VM) 생성
resource "azurerm_linux_virtual_machine" "vm" {
  for_each = var.nodes

  name                = local.node_names[each.key] # k8s-master01 등 가공된 이름
  location            = var.location
  resource_group_name = var.resource_group_name
  size                = each.value

  admin_username = "azureuser"

  network_interface_ids = [
    azurerm_network_interface.nic[each.key].id,
  ]

  admin_ssh_key {
    username   = "azureuser"
    # Root variables.tf에 정의된 경로의 키 파일을 읽어서 주입
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

# 4. Ansible Dynamic Inventory 전용 태그
tags = {
    # 1) 역할 기반 태그 (Ansible 그룹화의 핵심)
    "k8s-role" = length(regexall("master", each.key)) > 0 ? "masters" : (
                 length(regexall("worker", each.key)) > 0 ? "workers" : (
                 each.key == "nfs" ? "nfs" : (
                 each.key == "lb" ? "lb" : "others")))

    # 2) 중립적인 프로젝트 식별자
    "project"     = "k8s-automation-lab"
    "environment" = "sandbox"
    
    # 3) 관리 도구 명시
    "managed_by"  = "terraform"
  }

}