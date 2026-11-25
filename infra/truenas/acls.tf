locals {
  # NFSv4 permission sets that TrueNAS writes for UNIX mode bits; the provider
  # treats permissions that are not listed as false.
  mode_perms = {
    rwx_owner = {
      READ_DATA       = true, WRITE_DATA = true, APPEND_DATA = true, EXECUTE = true, DELETE_CHILD = true,
      READ_ATTRIBUTES = true, WRITE_ATTRIBUTES = true, READ_NAMED_ATTRS = true, WRITE_NAMED_ATTRS = true,
      READ_ACL        = true, WRITE_ACL = true, WRITE_OWNER = true, SYNCHRONIZE = true,
    }
    rwx = {
      READ_DATA       = true, WRITE_DATA = true, APPEND_DATA = true, EXECUTE = true, DELETE_CHILD = true,
      READ_ATTRIBUTES = true, READ_NAMED_ATTRS = true, READ_ACL = true, SYNCHRONIZE = true,
    }
    rx = {
      READ_DATA       = true, EXECUTE = true,
      READ_ATTRIBUTES = true, READ_NAMED_ATTRS = true, READ_ACL = true, SYNCHRONIZE = true,
    }
    none = {
      READ_ATTRIBUTES = true, READ_NAMED_ATTRS = true, READ_ACL = true, SYNCHRONIZE = true,
    }
  }

  ace_flags = {
    inherit        = { BASIC = "INHERIT" }
    noinherit      = { BASIC = "NOINHERIT" }
    inherit_only   = { FILE_INHERIT = true, DIRECTORY_INHERIT = true, INHERIT_ONLY = true }
    inherited      = { FILE_INHERIT = true, DIRECTORY_INHERIT = true, INHERITED = true }
    inherited_only = { FILE_INHERIT = true, DIRECTORY_INHERIT = true, INHERITED = true, INHERIT_ONLY = true }
  }

  # apps is prostagma's service user (fleet.nasIds); humans and admins are
  # TrueNAS's. builtin_users is every SMB user, including service accounts
  # such as homeassistant and proxmox, so it may only read.
  media_groups = [
    # rx is what the MODIFY-to-READ rewrite left on every file; TrueNAS's
    # BASIC READ lacks SYNCHRONIZE and would not match it.
    { who = "builtin_users", perms = local.mode_perms.rx },
    { who = "builtin_administrators", perms = { BASIC = "FULL_CONTROL" } },
    { who = "humans", perms = { BASIC = "FULL_CONTROL" } },
    { who = "admins", perms = { BASIC = "FULL_CONTROL" } },
    { who = "apps", perms = { BASIC = "FULL_CONTROL" } },
  ]

  mode_770 = [
    { tag = "owner@", type = "ALLOW", perms = local.mode_perms.rwx_owner, flags = local.ace_flags.noinherit },
    { tag = "group@", type = "ALLOW", perms = local.mode_perms.rwx, flags = local.ace_flags.noinherit },
    { tag = "everyone@", type = "ALLOW", perms = local.mode_perms.none, flags = local.ace_flags.noinherit },
  ]

  media_acl = concat(
    [
      { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherit_only },
      { tag = "group@", type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherit_only },
    ],
    [for g in local.media_groups : { tag = "GROUP", type = "ALLOW", who = g.who, perms = g.perms, flags = local.ace_flags.inherit }],
    local.mode_770,
  )

  # Child datasets kept the ACL inherited from media when they were created;
  # some (with the explicit mode entries) were chmod'ed afterwards.
  media_child_acl = concat(
    [
      { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited },
      { tag = "group@", type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherited },
    ],
    [for g in local.media_groups : { tag = "GROUP", type = "ALLOW", who = g.who, perms = g.perms, flags = local.ace_flags.inherited }],
  )

  media_child_chmod_acl = concat(
    [
      { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited_only },
      { tag = "group@", type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherited_only },
    ],
    [for g in local.media_groups : { tag = "GROUP", type = "ALLOW", who = g.who, perms = g.perms, flags = local.ace_flags.inherited }],
    local.mode_770,
  )

  nfs4_acls = {
    "/mnt/reservoir/media" = { gid = var.fleet.nasIds.media, entries = local.media_acl }

    "/mnt/reservoir/media/audiobooks"   = { gid = var.fleet.nasIds.media, entries = local.media_child_acl }
    "/mnt/reservoir/media/comics"       = { gid = var.fleet.nasIds.media, entries = local.media_child_acl }
    "/mnt/reservoir/media/ebooks"       = { gid = var.fleet.nasIds.media, entries = local.media_child_acl }
    "/mnt/reservoir/media/games"        = { gid = var.fleet.nasIds.media, entries = local.media_child_acl }
    "/mnt/reservoir/media/movies"       = { gid = var.fleet.nasIds.media, entries = local.media_child_acl }
    "/mnt/reservoir/media/music"        = { gid = var.fleet.nasIds.media, entries = local.media_child_acl }
    "/mnt/reservoir/media/ripped-discs" = { gid = var.fleet.nasIds.media, entries = local.media_child_acl }
    "/mnt/reservoir/media/tvshows"      = { gid = var.fleet.nasIds.media, entries = local.media_child_acl }

    "/mnt/reservoir/media/photos"         = { gid = var.fleet.nasIds.media, entries = local.media_child_chmod_acl }
    "/mnt/reservoir/media/photos/immich"  = { gid = var.fleet.nasIds.media, entries = local.media_child_chmod_acl }
    "/mnt/reservoir/media/youtube-videos" = { gid = var.fleet.nasIds.media, entries = local.media_child_chmod_acl }

    "/mnt/reservoir/users" = {
      gid = 0
      entries = [
        { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherit },
        { tag = "group@", type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherit },
        # Every SMB user lists users/ to reach its own home; not inherited, so
        # a new home directory does not open itself to every other user.
        { tag = "GROUP", type = "ALLOW", who = "builtin_users", perms = local.mode_perms.rx, flags = local.ace_flags.noinherit },
        { tag = "GROUP", type = "ALLOW", who = "builtin_administrators", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherit },
        { tag = "GROUP", type = "ALLOW", who = "admins", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherit },
        # TrueNAS refuses to set a home directory's owner unless its group
        # can traverse users/; users/carter's group is humans.
        { tag = "GROUP", type = "ALLOW", who = "humans", perms = { BASIC = "TRAVERSE" }, flags = local.ace_flags.noinherit },
      ]
    }

    # Mode 750 owned by carter:humans. The NFS export squashes every client to
    # carter, so prostagma's apps user writes here as the owner.
    "/mnt/reservoir/users/carter" = {
      uid = truenas_user.this["carter"].uid
      gid = var.fleet.nasIds.humans
      entries = [
        { tag = "owner@", type = "ALLOW", perms = local.mode_perms.rwx_owner, flags = local.ace_flags.noinherit },
        { tag = "group@", type = "ALLOW", perms = local.mode_perms.rx, flags = local.ace_flags.noinherit },
        { tag = "everyone@", type = "ALLOW", perms = local.mode_perms.none, flags = local.ace_flags.noinherit },
      ]
    }

    # Kept the ACL inherited from users/.
    "/mnt/reservoir/users/whitley" = {
      uid = truenas_user.this["whitley"].uid
      gid = 0
      entries = [
        { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited },
        { tag = "group@", type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherited },
        { tag = "GROUP", type = "ALLOW", who = "builtin_administrators", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited },
        { tag = "GROUP", type = "ALLOW", who = "admins", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited },
      ]
    }

    "/mnt/reservoir/users/homeassistant" = { uid = 3002, gid = 3002, entries = local.mode_700 }
    "/mnt/reservoir/users/proxmox"       = { uid = 3004, gid = 3003, entries = local.mode_700 }
  }

  mode_700 = [
    { tag = "owner@", type = "ALLOW", perms = local.mode_perms.rwx_owner, flags = local.ace_flags.noinherit },
    { tag = "group@", type = "ALLOW", perms = local.mode_perms.none, flags = local.ace_flags.noinherit },
    { tag = "everyone@", type = "ALLOW", perms = local.mode_perms.none, flags = local.ace_flags.noinherit },
  ]
}

import {
  for_each = local.nfs4_acls
  to       = truenas_filesystem_acl.nfs4[each.key]
  id       = each.key
}

# Removing an entry from nfs4_acls is refused by prevent_destroy; deleting
# this whole block is not, and would strip every one of these ACLs.
resource "truenas_filesystem_acl" "nfs4" {
  for_each = local.nfs4_acls

  path    = each.key
  uid     = try(each.value.uid, 0)
  gid     = each.value.gid
  entries = jsonencode(each.value.entries)

  # Destroying this resource strips the path's ACL back to its mode bits.
  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = truenas_filesystem_acl.vm_data
  id = "/mnt/river-rapid/vm-data"
}

resource "truenas_filesystem_acl" "vm_data" {
  path = "/mnt/river-rapid/vm-data"
  uid  = var.fleet.nasIds.apps
  gid  = var.fleet.nasIds.apps
  entries = jsonencode([
    { tag = "USER_OBJ", default = false, perms = { READ = true, WRITE = true, EXECUTE = true } },
    { tag = "GROUP_OBJ", default = false, perms = { READ = true, WRITE = true, EXECUTE = true } },
    { tag = "OTHER", default = false, perms = { READ = true, WRITE = false, EXECUTE = true } },
  ])

  lifecycle {
    prevent_destroy = true
  }
}
