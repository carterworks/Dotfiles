locals {
  # Keys are TrueNAS group names; `id` is the middleware's row ID, used only to
  # import. humans and media take their GIDs from fleet.nasIds, shared with
  # prostagma; the others exist only on TrueNAS.
  groups = {
    truenas_admin = { id = 109, gid = 950 }
    humans        = { id = 110, gid = var.fleet.nasIds.humans, smb = true }
    admins        = { id = 111, gid = 3001, sudo_commands = ["ALL"] }
    homeassistant = { id = 112, gid = 3002 }
    proxmox       = { id = 115, gid = 3003 }
    media         = { id = 116, gid = var.fleet.nasIds.media }
  }

  users = {
    truenas_admin = {
      id             = 70
      uid            = 950
      full_name      = "Local Administrator"
      group          = "truenas_admin"
      builtin_groups = ["builtin_administrators"]
      home           = "/home/truenas_admin"
      shell          = "/usr/bin/zsh"
      smb            = false
      sudo_commands  = ["ALL"]
      sshpubkey      = ""
    }
    carter = {
      id            = 71
      uid           = 3000
      full_name     = "Carter McBride"
      group         = "humans"
      groups        = ["media", "admins"]
      home          = "/mnt/reservoir/users/carter"
      shell         = "/usr/bin/zsh"
      smb           = true
      sudo_commands = ["ALL"]
      sshpubkey     = file("${path.module}/carter.authorized_keys")
    }
    whitley = {
      id        = 72
      uid       = 3001
      full_name = "whitley"
      group     = "humans"
      home      = "/mnt/reservoir/users/whitley"
    }
    homeassistant = {
      id        = 73
      uid       = 3002
      full_name = "Home Assistant"
      group     = "homeassistant"
      home      = "/mnt/reservoir/users/homeassistant"
      # Its TrueNAS integration logs in with this user's API key and only
      # reads.
      builtin_groups = ["truenas_readonly_administrators"]
    }
    proxmox = {
      id        = 75
      uid       = 3004
      full_name = "proxmox"
      group     = "proxmox"
      home      = "/mnt/reservoir/users/proxmox"
    }
  }

  user_defaults = {
    groups         = []
    builtin_groups = []
    shell          = "/usr/sbin/nologin"
    smb            = true
    sudo_commands  = []
    sshpubkey      = ""
  }
}

data "truenas_group" "builtin" {
  for_each = toset(["builtin_administrators", "truenas_readonly_administrators", "truenas_sharing_administrators"])
  name     = each.key
}

# The resource hides members whose primary group this is; the data source
# lists every member.
data "truenas_group" "admins" {
  name = "admins"
}

import {
  for_each = local.groups
  to       = truenas_group.this[each.key]
  id       = each.value.id
}

resource "truenas_group" "this" {
  for_each = local.groups

  name                   = each.key
  gid                    = each.value.gid
  smb                    = try(each.value.smb, false)
  sudo_commands          = try(each.value.sudo_commands, [])
  sudo_commands_nopasswd = []

  lifecycle {
    prevent_destroy = true
  }
}

import {
  for_each = local.users
  to       = truenas_user.this[each.key]
  id       = each.value.id
}

# Email addresses are left unmanaged so that they stay out of this public
# repository.
resource "truenas_user" "this" {
  for_each = { for name, user in local.users : name => merge(local.user_defaults, user) }

  username  = each.key
  uid       = each.value.uid
  full_name = each.value.full_name
  group     = truenas_group.this[each.value.group].id
  groups = concat(
    [for g in each.value.groups : truenas_group.this[g].id],
    [for g in each.value.builtin_groups : data.truenas_group.builtin[g].id],
  )
  home                   = each.value.home
  shell                  = each.value.shell
  smb                    = each.value.smb
  locked                 = false
  password_disabled      = false
  ssh_password_enabled   = false
  sshpubkey              = each.value.sshpubkey
  sudo_commands          = each.value.sudo_commands
  sudo_commands_nopasswd = []

  lifecycle {
    prevent_destroy = true
  }
}

# The provider keeps only the groups a user's configuration lists, so a member
# added to an admin group in the web interface would never show up as drift.
check "admin_group_members" {
  assert {
    condition     = toset(data.truenas_group.builtin["builtin_administrators"].users) == toset([1, truenas_user.this["truenas_admin"].id])
    error_message = "builtin_administrators has members other than root and truenas_admin."
  }

  assert {
    condition     = toset(data.truenas_group.admins.users) == toset([truenas_user.this["carter"].id])
    error_message = "admins (sudo ALL) has members other than carter."
  }
}

# apps is a TrueNAS builtin group, so it is checked rather than managed.
data "truenas_group" "apps" {
  name = "apps"
}

check "apps_gid_matches_prostagma" {
  assert {
    condition     = data.truenas_group.apps.gid == var.fleet.nasIds.apps
    error_message = "TrueNAS's apps group no longer has the GID prostagma's services run as (fleet.nasIds.apps)."
  }
}
