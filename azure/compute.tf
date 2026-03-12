# resource "azurerm_public_ip" "pip" {
#   for_each            = var.vms
#   name                = "${each.value.name}-pip"
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   allocation_method   = "Dynamic"
# }

# resource "azurerm_network_interface" "nic" {
#   for_each            = var.vms
#   name                = "${each.value.name}-nic"
#   location            = azurerm_resource_group.rg.location
#   resource_group_name = azurerm_resource_group.rg.name

#   ip_configuration {
#     name                          = "internal"
#     subnet_id                     = azurerm_subnet.k8s_subnet.id
#     private_ip_address_allocation = "Static"
#     private_ip_address            = each.value.ip
#     public_ip_address_id          = azurerm_public_ip.pip[each.key].id
#   }
# }

# resource "azurerm_linux_virtual_machine" "vm" {
#   for_each            = var.vms
#   name                = each.value.name
#   resource_group_name = azurerm_resource_group.rg.name
#   location            = azurerm_resource_group.rg.location
#   size                = each.value.size
#   admin_username      = var.admin_username
#   network_interface_ids = [
#     azurerm_network_interface.nic[each.key].id,
#   ]

#   admin_ssh_key {
#     username   = var.admin_username
#     public_key = file(pathexpand(var.ssh_public_key_path))
#   }

#   os_disk {
#     caching              = "ReadWrite"
#     storage_account_type = "Standard_LRS"
#   }

#   source_image_reference {
#     publisher = "Canonical"
#     offer     = "0001-com-ubuntu-server-jammy"
#     sku       = "22_04-lts"
#     version   = "latest"
#   }
# }
