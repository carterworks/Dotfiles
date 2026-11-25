locals {
  # Keys are pool names; `id` is the row ID, used only to import. Device names
  # may change between boots; the provider matches disks by identity.
  pools = {
    reservoir = {
      id       = 1
      autotrim = false
      data     = [{ type = "RAIDZ1", disks = ["sdc", "sdd", "sdb"] }]
    }
    # A single NVMe disk: no redundancy for vm-data and the apps.
    river-rapid = {
      id       = 2
      autotrim = true
      data     = [{ type = "STRIPE", disks = ["nvme0n1"] }]
    }
  }
}

import {
  for_each = local.pools
  to       = truenas_pool.this[each.key]
  id       = each.value.id
}

# The provider refuses any change to a pool's name or topology instead of
# replacing it, and refuses to destroy a pool that holds anything unless
# force_destroy is set; never set it here.
resource "truenas_pool" "this" {
  for_each = local.pools

  name          = each.key
  autotrim      = each.value.autotrim
  checksum      = "ON"
  deduplication = "OFF"
  force_destroy = false
  topology = {
    data  = each.value.data
    cache = []
    log   = []
    spare = []
  }

  lifecycle {
    prevent_destroy = true
  }
}
