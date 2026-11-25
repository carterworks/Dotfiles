import {
  to = truenas_certificate.default
  id = "1"
}

# TrueNAS's self-signed certificate for the web interface (ui_certificate in
# system.tf). Its PEM and private key are left out of the configuration; the
# provider still reads the key into the (encrypted) state.
resource "truenas_certificate" "default" {
  name                 = "truenas_default"
  create_type          = "CERTIFICATE_CREATE_IMPORTED"
  add_to_trusted_store = false

  lifecycle {
    prevent_destroy = true
  }
}

locals {
  # Which groups hold each builtin privilege; keys are the row IDs.
  privileges = {
    "1" = {
      name      = "Local Administrator"
      roles     = ["FULL_ADMIN"]
      web_shell = true
      groups = [
        data.truenas_group.builtin["builtin_administrators"].gid,
        truenas_group.this["admins"].gid,
      ]
    }
    "2" = {
      name      = "Read-Only Administrator"
      roles     = ["READONLY_ADMIN"]
      web_shell = false
      groups    = [data.truenas_group.builtin["truenas_readonly_administrators"].gid]
    }
    "3" = {
      name      = "Sharing Administrator"
      roles     = ["SHARING_ADMIN"]
      web_shell = false
      groups    = [data.truenas_group.builtin["truenas_sharing_administrators"].gid]
    }
  }

  # Share-level ACLs only cap what the filesystem ACLs (acls.tf) allow; both
  # shares let everyone (S-1-1-0) through, since homeassistant writes its
  # backups through the users share.
  smb_share_acls = {
    users = [{ ae_who_sid = "S-1-1-0", ae_type = "ALLOWED", ae_perm = "FULL" }]
    media = [{ ae_who_sid = "S-1-1-0", ae_type = "ALLOWED", ae_perm = "FULL" }]
  }
}

import {
  for_each = local.privileges
  to       = truenas_privilege.this[each.key]
  id       = each.key
}

resource "truenas_privilege" "this" {
  for_each = local.privileges

  name         = each.value.name
  roles        = each.value.roles
  web_shell    = each.value.web_shell
  local_groups = each.value.groups
  ds_groups    = []

  # Losing Local Administrator locks every administrator out.
  lifecycle {
    prevent_destroy = true
  }
}

import {
  for_each = local.smb_share_acls
  to       = truenas_smb_share_acl.this[each.key]
  id       = each.key
}

resource "truenas_smb_share_acl" "this" {
  for_each = local.smb_share_acls

  share_name = truenas_smb_share.this[each.key].name
  share_acl  = each.value

  lifecycle {
    prevent_destroy = true
  }
}
