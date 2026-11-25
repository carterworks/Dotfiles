import {
  to = truenas_network_config.this
  id = "network_config"
}

resource "truenas_network_config" "this" {
  hostname    = "herodotus"
  domain      = "local"
  domains     = []
  hosts       = []
  httpproxy   = ""
  ipv4gateway = "192.168.4.1"
  ipv6gateway = ""
  nameserver1 = "1.1.1.1"
  nameserver2 = "1.0.0.1"
  nameserver3 = "9.9.9.9"
  service_announcement = {
    mdns    = true
    netbios = true
    wsd     = true
  }
}

import {
  to = truenas_network_interface.enp6s18
  id = "enp6s18"
}

# Prostagma mounts NFS from fleet.lan.truenas, one of these aliases.
resource "truenas_network_interface" "enp6s18" {
  name        = "enp6s18"
  type        = "PHYSICAL"
  description = ""
  ipv4_dhcp   = false
  ipv6_auto   = true
  mtu         = 1500
  aliases = [
    { type = "INET", address = "192.168.7.58", netmask = 22 },
    { type = "INET", address = var.fleet.lan.truenas, netmask = 22 },
  ]

  # Deleting the interface takes the NAS off the network.
  lifecycle {
    prevent_destroy = true
  }
}
