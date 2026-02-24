resource "ncloud_login_key" "loginkey" {
  key_name = var.login_key_name
}

resource "ncloud_server" "vm" {
  for_each = var.vms

  subnet_no           = ncloud_subnet.k8s_subnet.id
  name                = each.value.name
  zone                = var.zone
  server_image_number = var.server_image_number
  server_spec_code    = each.value.spec_code
  login_key_name      = ncloud_login_key.loginkey.key_name
  fee_system_type_code = "MTRAT"
}

resource "ncloud_network_interface" "nic" {
  for_each = var.vms

  name                  = "${each.value.name}-nic"
  subnet_no             = ncloud_subnet.k8s_subnet.id
  private_ip            = each.value.ip
  access_control_groups = [ncloud_vpc.vpc.default_access_control_group_no]
  server_instance_no    = ncloud_server.vm[each.key].id
}

resource "ncloud_public_ip" "pip" {
  for_each = var.vms

  server_instance_no = ncloud_server.vm[each.key].id
  description        = "${each.value.name} public ip"
}
