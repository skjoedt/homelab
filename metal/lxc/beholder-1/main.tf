variable "lxd_password" {
  type        = string
  sensitive   = true
  description = "LXD trust password"
}

terraform {
  backend "s3" {
    bucket = "csh-terraform"
    key    = "homelab-lxc"
    region = "eu-north-1"
  }
}


terraform {
  required_providers {
    lxd = {
      source = "terraform-lxd/lxd"
    }
  }
}

provider "lxd" {
  generate_client_certificates = true
  accept_remote_certificate    = true

  remote {
    name     = "myhost"
    address  = "https://10.0.0.100:443"
    password = var.lxd_password
    default  = true
  }
}

resource "lxd_project" "homelab" {
  name = "homelab"
  config = {
    "features.profiles" : true
  }
}

resource "lxd_storage_pool" "local" {
  project = lxd_project.homelab.name
  name    = "local"
  driver  = "lvm"
  source  = "/dev/sda4"
  config = {
    "lvm.vg_name" : "lxc-vg"
    "lvm.thinpool_name" : "lxc-lv"
  }
}

resource "lxd_profile" "default" {
  depends_on = [
    lxd_storage_pool.local,
    lxd_project.homelab
  ]
  name        = "default"
  project     = lxd_project.homelab.name
  description = "Managed by terraform"

  device {
    type = "disk"
    name = "root"

    properties = {
      pool = "local"
      path = "/"
    }
  }
}

locals {
  kube_instances = {
    kube-1 = "10.0.0.21"
    kube-2 = "10.0.0.22"
    kube-3 = "10.0.0.23"
  }

  # Define the number of Ceph volumes per instance
  ceph_volumes = ["ceph-1", "ceph-2", "ceph-3"]

  # Create a map of all volume combinations
  volume_matrix = {
    for pair in setproduct(keys(local.kube_instances), local.ceph_volumes) :
    "${pair[0]}-${pair[1]}" => {
      instance = pair[0]
      volume   = pair[1]
    }
  }
}

resource "lxd_instance" "kube_instances" {
  for_each = local.kube_instances
  depends_on = [
    lxd_profile.default,
    lxd_storage_pool.local
  ]
  name    = each.key
  type    = "virtual-machine"
  image   = "ubuntu-daily:24.04"
  project = lxd_project.homelab.name

  config = {
    "boot.autostart" = true
    "user.network-config" = templatefile("${path.module}/templates/netplan.yml", {
      ip_address = each.value
      gateway    = "10.0.0.1"
    })
    "user.user-data" = file("${path.module}/templates/user_data.yml")
  }

  device {
    name = "enp5s0"
    type = "nic"
    properties = {
      nictype = "bridged"
      parent  = "br0"
    }
  }

  limits = {
    cpu    = 2
    memory = "2GB"
  }

}

# resource "lxd_volume" "ceph_volumes" {
#   for_each = local.volume_matrix
#   name     = each.key
#   pool     = "local"
#   type     = "block"
#   project  = lxd_project.homelab.name
# }
