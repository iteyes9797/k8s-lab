variable "vms" {
  description = "Map of VMs to create"
  type = map(object({
    name = string
    ip   = string
    size = string
  }))
  default = {
    jb = {
      name = "jumpbox"
      ip   = "192.168.0.5"
      size = "Standard_B1s" # 1 vCPU, 1 GiB RAM
    }
    m1 = {
      name = "k8s-master01"
      ip   = "192.168.0.106"
      size = "Standard_D2s_v3" # 2 vCPU, 8 GiB RAM
    }
    m2 = {
      name = "k8s-master02"
      ip   = "192.168.0.107"
      size = "Standard_D2s_v3" # 2 vCPU, 8 GiB RAM
    }
    m3 = {
      name = "k8s-master03"
      ip   = "192.168.0.108"
      size = "Standard_D2s_v3" # 2 vCPU, 8 GiB RAM
    }
    w1 = {
      name = "k8s-worker01"
      ip   = "192.168.0.111"
      size = "Standard_D4s_v3" # 4 vCPU, 16 GiB RAM
    }
    w2 = {
      name = "k8s-worker02"
      ip   = "192.168.0.112"
      size = "Standard_D4s_v3" # 4 vCPU, 16 GiB RAM
    }
    nfs = {
      name = "nfs"
      ip   = "192.168.0.109"
      size = "Standard_B2s" # 2 vCPU, 4 GiB RAM
    }
    lb = {
      name = "lb-proxy"
      ip   = "192.168.0.110"
      size = "Standard_B1s" # 1 vCPU, 1 GiB RAM
    }
  }
}
