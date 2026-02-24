output "vm_public_ips" {
  value = { for k, v in ncloud_public_ip.pip : k => v.public_ip }
}

output "vm_internal_ips" {
  value = { for k, v in ncloud_server.vm : k => v.private_ip }
}
