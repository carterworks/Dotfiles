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

  # apps (568) is prostagma's service user; humans and admins are TrueNAS's.
  media_groups = [
    { who = "builtin_users", perms = "MODIFY" },
    { who = "builtin_administrators", perms = "FULL_CONTROL" },
    { who = "humans", perms = "FULL_CONTROL" },
    { who = "admins", perms = "FULL_CONTROL" },
    { who = "apps", perms = "FULL_CONTROL" },
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
    [for g in local.media_groups : { tag = "GROUP", type = "ALLOW", who = g.who, perms = { BASIC = g.perms }, flags = local.ace_flags.inherit }],
    local.mode_770,
  )

  # Child datasets kept the ACL inherited from media when they were created;
  # some (with the explicit mode entries) were chmod'ed afterwards.
  media_child_acl = concat(
    [
      { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited },
      { tag = "group@", type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherited },
    ],
    [for g in local.media_groups : { tag = "GROUP", type = "ALLOW", who = g.who, perms = { BASIC = g.perms }, flags = local.ace_flags.inherited }],
  )

  media_child_chmod_acl = concat(
    [
      { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited_only },
      { tag = "group@", type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherited_only },
    ],
    [for g in local.media_groups : { tag = "GROUP", type = "ALLOW", who = g.who, perms = { BASIC = g.perms }, flags = local.ace_flags.inherited }],
    local.mode_770,
  )

  nfs4_acls = {
    "/mnt/reservoir/media" = { gid = 3004, entries = local.media_acl }

    "/mnt/reservoir/media/audiobooks"   = { gid = 3004, entries = local.media_child_acl }
    "/mnt/reservoir/media/comics"       = { gid = 3004, entries = local.media_child_acl }
    "/mnt/reservoir/media/ebooks"       = { gid = 3004, entries = local.media_child_acl }
    "/mnt/reservoir/media/games"        = { gid = 3004, entries = local.media_child_acl }
    "/mnt/reservoir/media/movies"       = { gid = 3004, entries = local.media_child_acl }
    "/mnt/reservoir/media/music"        = { gid = 3004, entries = local.media_child_acl }
    "/mnt/reservoir/media/ripped-discs" = { gid = 3004, entries = local.media_child_acl }
    "/mnt/reservoir/media/tvshows"      = { gid = 3004, entries = local.media_child_acl }

    "/mnt/reservoir/media/photos"         = { gid = 3004, entries = local.media_child_chmod_acl }
    "/mnt/reservoir/media/photos/immich"  = { gid = 3004, entries = local.media_child_chmod_acl }
    "/mnt/reservoir/media/youtube-videos" = { gid = 3004, entries = local.media_child_chmod_acl }

    "/mnt/reservoir/users" = {
      gid = 0
      entries = [
        { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherit },
        { tag = "group@", type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherit },
        { tag = "GROUP", type = "ALLOW", who = "builtin_users", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherit },
        { tag = "GROUP", type = "ALLOW", who = "builtin_administrators", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherit },
        { tag = "GROUP", type = "ALLOW", who = "admins", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherit },
        { tag = "GROUP", type = "ALLOW", who = "apps", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherit },
      ]
    }

    # Mode 750 owned by root:humans, which keeps carter (and the all-squashed
    # NFS export) from creating entries at the top of the home directory.
    "/mnt/reservoir/users/carter" = {
      gid = 3000
      entries = [
        { tag = "owner@", type = "ALLOW", perms = local.mode_perms.rwx_owner, flags = local.ace_flags.noinherit },
        { tag = "group@", type = "ALLOW", perms = local.mode_perms.rx, flags = local.ace_flags.noinherit },
        { tag = "everyone@", type = "ALLOW", perms = local.mode_perms.none, flags = local.ace_flags.noinherit },
      ]
    }

    # Kept the ACL inherited from users/ and is owned by root, not whitley.
    "/mnt/reservoir/users/whitley" = {
      gid = 0
      entries = [
        { tag = "owner@", type = "ALLOW", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited },
        { tag = "group@", type = "ALLOW", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherited },
        { tag = "GROUP", type = "ALLOW", who = "builtin_users", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherited },
        { tag = "GROUP", type = "ALLOW", who = "builtin_administrators", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited },
        { tag = "GROUP", type = "ALLOW", who = "admins", perms = { BASIC = "FULL_CONTROL" }, flags = local.ace_flags.inherited },
        { tag = "GROUP", type = "ALLOW", who = "apps", perms = { BASIC = "MODIFY" }, flags = local.ace_flags.inherited },
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
  uid  = 568
  gid  = 568
  entries = jsonencode([
    { tag = "USER_OBJ", default = false, perms = { READ = true, WRITE = true, EXECUTE = true } },
    { tag = "GROUP_OBJ", default = false, perms = { READ = true, WRITE = true, EXECUTE = true } },
    { tag = "OTHER", default = false, perms = { READ = true, WRITE = false, EXECUTE = true } },
  ])

  lifecycle {
    prevent_destroy = true
  }
}
