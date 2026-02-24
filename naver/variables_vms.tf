variable "vms" {
  description = "Map of VMs to create"
  type = map(object({
    name      = string
    ip        = string
    spec_code = string
  }))

  default = {
    jb = {
      name      = "jumpbox"
      ip        = "192.168.0.5"
      spec_code = "s2-g3"
    }
    m1 = {
      name      = "k8s-master01"
      ip        = "192.168.0.106"
      spec_code = "s2-g3"
    }
    m2 = {
      name      = "k8s-master02"
      ip        = "192.168.0.107"
      spec_code = "s2-g3"
    }
    m3 = {
      name      = "k8s-master03"
      ip        = "192.168.0.108"
      spec_code = "s2-g3"
    }
    w1 = {
      name      = "k8s-worker01"
      ip        = "192.168.0.111"
      spec_code = "s2-g3"
    }
    w2 = {
      name      = "k8s-worker02"
      ip        = "192.168.0.112"
      spec_code = "s2-g3"
    }
    nfs = {
      name      = "nfs"
      ip        = "192.168.0.109"
      spec_code = "s2-g3"
    }
    lb = {
      name      = "lb-proxy"
      ip        = "192.168.0.110"
      spec_code = "s2-g3"
    }
  }
}
