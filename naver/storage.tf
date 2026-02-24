resource "ncloud_block_storage" "nfs_disk" {
  name               = "nfs-data-disk"
  size               = tostring(var.nfs_disk_size_gb)
  server_instance_no = ncloud_server.vm["nfs"].id
}
