locals {
  # Prostagma is the only NFS client; its DHCP address is also assumed by
  # nix/hosts/prostagma/tv-screensaver.nix.
  nfs_clients = ["192.168.4.29/32"]

  # Keys are export paths; `id` is the middleware's row ID, used only to import.
  # Prostagma mounts these (nix/hosts/prostagma/default.nix, fileSystems).
  nfs_shares = {
    "/mnt/reservoir/media"                = { id = 3 }
    "/mnt/river-rapid/vm-data"            = { id = 4 }
    "/mnt/reservoir/media/photos"         = { id = 5, comment = "photos" }
    "/mnt/reservoir/media/photos/immich"  = { id = 6, comment = "immich" }
    "/mnt/reservoir/media/movies"         = { id = 7, comment = "movies" }
    "/mnt/reservoir/media/music"          = { id = 8, comment = "music" }
    "/mnt/reservoir/media/tvshows"        = { id = 9, comment = "tvshows" }
    "/mnt/reservoir/media/random-videos"  = { id = 10, comment = "random-videos" }
    "/mnt/reservoir/media/audiobooks"     = { id = 11, comment = "audiobooks" }
    "/mnt/reservoir/media/youtube-videos" = { id = 12, comment = "youtube-videos" }
    "/mnt/reservoir/media/comics"         = { id = 14, comment = "comics" }
    "/mnt/reservoir/media/games"          = { id = 15, comment = "games" }
    "/mnt/reservoir/media/ebooks"         = { id = 16, comment = "ebooks" }

    # Every client is squashed to carter, so prostagma's apps user can read
    # the home directory without an ID that matches TrueNAS's.
    "/mnt/reservoir/users/carter" = {
      id           = 13
      mapall_user  = "carter"
      mapall_group = "humans"
    }
  }

  # Scylla mounts these (nix/hosts/scylla/default.nix, mkTruenasMount).
  smb_shares = {
    users = { id = 3, path = "/mnt/reservoir/users" }
    media = { id = 14, path = "/mnt/reservoir/media" }
  }
}

import {
  for_each = local.nfs_shares
  to       = truenas_nfs_share.this[each.key]
  id       = each.value.id
}

resource "truenas_nfs_share" "this" {
  for_each = local.nfs_shares

  path             = each.key
  comment          = try(each.value.comment, "")
  enabled          = true
  ro               = false
  hosts            = []
  networks         = local.nfs_clients
  security         = []
  expose_snapshots = false
  maproot_user     = ""
  maproot_group    = ""
  mapall_user      = try(each.value.mapall_user, "")
  mapall_group     = try(each.value.mapall_group, "")

  lifecycle {
    prevent_destroy = true
  }
}

import {
  for_each = local.smb_shares
  to       = truenas_smb_share.this[each.key]
  id       = each.value.id
}

resource "truenas_smb_share" "this" {
  for_each = local.smb_shares

  name      = each.key
  path      = each.value.path
  purpose   = "DEFAULT_SHARE"
  comment   = ""
  enabled   = true
  ro        = false
  browsable = true
  audit = {
    enable      = false
    ignore_list = []
    watch_list  = []
  }
  # Guest access exists only for LEGACY_SHARE, so pinning purpose rules it out.
  options = {
    hostsallow         = []
    hostsdeny          = []
    aapl_name_mangling = false
  }

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = truenas_nfs_config.this
  id = "nfs_config"
}

resource "truenas_nfs_config" "this" {
  protocols         = ["NFSV3", "NFSV4"]
  bindip            = []
  servers           = 0
  allow_nonroot     = false
  userd_manage_gids = false
  v4_krb            = false
  v4_domain         = ""
  rdma              = false
  mountd_port       = 0
  rpclockd_port     = 0
  rpcstatd_port     = 0
  mountd_log        = false
  statd_lockd_log   = false
}

import {
  to = truenas_smb_config.this
  id = "smb_config"
}

resource "truenas_smb_config" "this" {
  netbiosname      = "herodotus"
  netbiosalias     = []
  workgroup        = "WORKGROUP"
  description      = "TrueNAS server"
  bindip           = []
  guest            = "nobody"
  encryption       = "DEFAULT"
  minimum_protocol = ""
  ntlmv1_auth      = false
  aapl_extensions  = false
  multichannel     = false
  localmaster      = true
  admin_group      = ""
  smb_options      = ""
  filemask         = "DEFAULT"
  dirmask          = "DEFAULT"
  unixcharset      = "UTF-8"
  syslog           = false
  debug            = false
  search_protocols = []
}
