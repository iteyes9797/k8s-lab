resource "azurerm_managed_disk" "nfs_disk" {
  name                 = "nfs-data-disk"
  location             = azurerm_resource_group.rg.location
  resource_group_name  = azurerm_resource_group.rg.name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = 100
}

resource "azurerm_virtual_machine_data_disk_attachment" "nfs_disk_attach" {
  managed_disk_id    = azurerm_managed_disk.nfs_disk.id
  virtual_machine_id = azurerm_linux_virtual_machine.vm["nfs"].id
  lun                = 10
  caching            = "ReadWrite"
}
