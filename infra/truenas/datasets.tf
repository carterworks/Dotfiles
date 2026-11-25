locals {
  dataset_defaults = {
    acltype                  = "inherit"
    aclmode                  = "INHERIT"
    atime                    = "INHERIT"
    checksum                 = "INHERIT"
    compression              = "inherit"
    dedup                    = "INHERIT"
    exec                     = "INHERIT"
    readonly                 = "INHERIT"
    recordsize               = null
    snapdir                  = "INHERIT"
    special_small_block_size = null
    sync                     = "INHERIT"
  }

  pool_root = {
    acltype                  = "posix"
    aclmode                  = "DISCARD"
    atime                    = "OFF"
    checksum                 = "ON"
    compression              = "zstd"
    dedup                    = "OFF"
    exec                     = "ON"
    readonly                 = "OFF"
    recordsize               = "1M"
    snapdir                  = "HIDDEN"
    special_small_block_size = 0
    sync                     = "STANDARD"
  }

  nfsv4_restricted  = { acltype = "nfsv4", aclmode = "RESTRICTED" }
  nfsv4_passthrough = { acltype = "nfsv4", aclmode = "PASSTHROUGH" }

  datasets = {
    "reservoir"                      = local.pool_root
    "reservoir/users"                = local.nfsv4_restricted
    "reservoir/media"                = merge(local.nfsv4_passthrough, { snapdir = "HIDDEN" })
    "reservoir/media/audiobooks"     = local.nfsv4_passthrough
    "reservoir/media/comics"         = local.nfsv4_passthrough
    "reservoir/media/ebooks"         = local.nfsv4_passthrough
    "reservoir/media/games"          = local.nfsv4_passthrough
    "reservoir/media/movies"         = local.nfsv4_passthrough
    "reservoir/media/music"          = local.nfsv4_passthrough
    "reservoir/media/photos"         = {}
    "reservoir/media/photos/immich"  = {}
    "reservoir/media/ripped-discs"   = local.nfsv4_passthrough
    "reservoir/media/tvshows"        = local.nfsv4_passthrough
    "reservoir/media/youtube-videos" = {}

    "river-rapid"                                          = local.pool_root
    "river-rapid/vm-data"                                  = {}
    "river-rapid/vm-data/agents"                           = {}
    "river-rapid/vm-data/automatic-ripping-machine"        = {}
    "river-rapid/vm-data/automatic-ripping-machine/config" = {}
    "river-rapid/vm-data/automatic-ripping-machine/home"   = {}
    "river-rapid/vm-data/backrest"                         = {}
    "river-rapid/vm-data/immich"                           = {}
    "river-rapid/vm-data/immich/pgData"                    = {}
    "river-rapid/vm-data/komga"                            = {}
    "river-rapid/vm-data/open-webui"                       = {}
    "river-rapid/vm-data/pinchflat"                        = {}
    "river-rapid/vm-data/qbittorrent-vpn"                  = {}
    "river-rapid/vm-data/qbittorrent-vpn/config"           = {}
    "river-rapid/vm-data/qbittorrent-vpn/data"             = {}
    "river-rapid/vm-data/resilio-sync"                     = {}
    "river-rapid/vm-data/romm"                             = {}
    "river-rapid/vm-data/romm/config"                      = {}
    "river-rapid/vm-data/romm/resources"                   = {}
    "river-rapid/vm-data/silly-tavern"                     = {}
    "river-rapid/vm-data/tsdproxy"                         = {}
  }
}

import {
  for_each = local.datasets
  to       = truenas_dataset.this[each.key]
  id       = each.key
}

resource "truenas_dataset" "this" {
  for_each = { for name, settings in local.datasets : name => merge(local.dataset_defaults, settings) }

  name                     = each.key
  acltype                  = each.value.acltype
  aclmode                  = each.value.aclmode
  atime                    = each.value.atime
  checksum                 = each.value.checksum
  compression              = each.value.compression
  dedup                    = each.value.dedup
  exec                     = each.value.exec
  readonly                 = each.value.readonly
  recordsize               = each.value.recordsize
  snapdir                  = each.value.snapdir
  special_small_block_size = each.value.special_small_block_size
  sync                     = each.value.sync
  quota                    = 0
  refquota                 = 0
  reservation              = 0
  comments                 = ""

  lifecycle {
    prevent_destroy = true
  }
}
