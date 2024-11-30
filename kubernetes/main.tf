terraform {
  required_providers {
    lxd = {
      source = "terraform-lxd/lxd"
    }
  }
}

provider "lxd" {
}

resource "lxd_project" "homelab" {
  name = "homelab"
  config = {
    "features.profiles": true
  }
}

resource "lxd_storage_pool" "local" {
  project = lxd_project.homelab.name
  name   = "local"
  driver = "lvm"
  source = "/dev/sda4"
  config = {
    "lvm.vg_name": "lxc-vg"
    "lvm.thinpool_name": "lxc-lv"
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
    kube-1 = "192.168.68.21"
    kube-2 = "192.168.68.22"
    kube-3 = "192.168.68.23"
  }
}

resource "lxd_instance" "kube_instances" {
  for_each = local.kube_instances
  depends_on = [
    lxd_profile.default,
    lxd_storage_pool.local
  ]
  name  = each.key
  type = "virtual-machine"
  image = "ubuntu-daily:24.04"
  project = lxd_project.homelab.name

  config = {
    "boot.autostart" = true
    "user.network-config" = templatefile("${path.module}/templates/netplan.yml", {
      ip_address = each.value
      gateway    = "192.168.68.1"
    })
    "user.user-data" = file("${path.module}/templates/user_data.yml")
  }

  device {
    name = "enp5s0"
    type = "nic"
    properties = {
      nictype   = "bridged"
      parent    = "br0"
    }
  }

  limits = {
    cpu = 1
  }

}

locals {
  worker_instances = {
    worker-1 = "192.168.68.31"
    worker-2 = "192.168.68.32"
  }
}

resource "lxd_instance" "worker_instances" {
  for_each = local.worker_instances
  depends_on = [
    lxd_profile.default,
    lxd_storage_pool.local
  ]
  name  = each.key
  type = "virtual-machine"
  image = "ubuntu-daily:24.04"
  project = lxd_project.homelab.name

  config = {
    "boot.autostart" = true
    "user.network-config" = templatefile("${path.module}/templates/netplan.yml", {
      ip_address = each.value
      gateway    = "192.168.68.1"
    })
    "user.user-data" = file("${path.module}/templates/user_data.yml")
  }

  device {
    name = "enp5s0"
    type = "nic"
    properties = {
      nictype   = "bridged"
      parent    = "br0"
    }
  }

  limits = {
    cpu = 2
  }

}