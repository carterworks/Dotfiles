import {
  to = truenas_vm.devenv
  id = "3"
}

# Broken since its disk zvol was deleted and br0 stopped existing (TODO.md).
resource "truenas_vm" "devenv" {
  name                          = "devenv"
  description                   = ""
  autostart                     = true
  vcpus                         = 1
  cores                         = 4
  threads                       = 1
  memory                        = 8192
  min_memory                    = 1024
  cpu_mode                      = "HOST-PASSTHROUGH"
  cpu_model                     = ""
  cpuset                        = ""
  nodeset                       = ""
  pin_vcpus                     = false
  bootloader                    = "UEFI"
  bootloader_ovmf               = "OVMF_CODE.fd"
  enable_secure_boot            = false
  trusted_platform_module       = false
  arch_type                     = ""
  machine_type                  = ""
  command_line_args             = ""
  enable_cpu_topology_extension = false
  hide_from_msr                 = false
  hyperv_enlightenments         = false
  shutdown_timeout              = 15
  suspend_on_snapshot           = false
  time                          = "LOCAL"

  # Deleting a VM can delete its disks.
  lifecycle {
    prevent_destroy = true
  }
}

locals {
  # Keys are the middleware's device row IDs.
  vm_devices = {
    "9" = {
      order = 1002
      attributes = {
        dtype                  = "NIC"
        type                   = "VIRTIO"
        mac                    = "00:a0:98:64:25:8b"
        nic_attach             = "br0"
        trust_guest_rx_filters = false
      }
    }
    "10" = {
      order = 1000
      attributes = {
        dtype = "CDROM"
        path  = "/mnt/river-rapid/vm-data/agents/nixos-minimal-25.11.3064.64049ca74d63-x86_64-linux.iso"
      }
    }
    "11" = {
      order = 1001
      attributes = {
        dtype       = "DISK"
        type        = "VIRTIO"
        path        = "/dev/zvol/river-rapid/vm-data/agents/devenv-cq6c4"
        create_zvol = false
        iotype      = "THREADS"
        serial      = "hPPckMKg"
      }
    }
    # The SPICE password is write-only and left as it is.
    "12" = {
      order = 1003
      attributes = {
        dtype      = "DISPLAY"
        type       = "SPICE"
        bind       = "0.0.0.0"
        port       = 5900
        web        = true
        web_port   = 5901
        resolution = "1024x768"
        wait       = false
      }
    }
  }
}

import {
  for_each = local.vm_devices
  to       = truenas_vm_device.devenv[each.key]
  id       = each.key
}

resource "truenas_vm_device" "devenv" {
  for_each = local.vm_devices

  vm         = truenas_vm.devenv.id
  order      = each.value.order
  attributes = jsonencode(each.value.attributes)

  lifecycle {
    prevent_destroy = true
  }
}
