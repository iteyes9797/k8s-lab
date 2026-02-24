resource "ncloud_vpc" "vpc" {
  name            = var.vpc_name
  ipv4_cidr_block = var.vpc_cidr
}

resource "ncloud_subnet" "k8s_subnet" {
  vpc_no         = ncloud_vpc.vpc.vpc_no
  subnet         = var.subnet_cidr
  zone           = var.zone
  network_acl_no = ncloud_vpc.vpc.default_network_acl_no
  subnet_type    = "PUBLIC"
  usage_type     = "GEN"
  name           = var.subnet_name
}
