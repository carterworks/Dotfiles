import {
  to = truenas_docker_config.this
  id = "docker_config"
}

resource "truenas_docker_config" "this" {
  pool                 = "river-rapid"
  enable_image_updates = true
  nvidia               = false
  cidr_v6              = "fdd0::/64"
  registry_mirrors     = []
  address_pools = [
    { base = "172.17.0.0/12", size = 24 },
    { base = "fdd0::/48", size = 64 },
  ]
}

import {
  to = truenas_catalog_config.this
  id = "catalog_config"
}

resource "truenas_catalog_config" "this" {
  preferred_trains = ["community", "stable"]
}

import {
  to = truenas_audit_config.this
  id = "audit_config"
}

resource "truenas_audit_config" "this" {
  retention           = 7
  quota               = 0
  reservation         = 0
  quota_fill_warning  = 75
  quota_fill_critical = 95
}

import {
  to = truenas_twofactor_auth.this
  id = "twofactor_auth"
}

resource "truenas_twofactor_auth" "this" {
  enabled  = false
  window   = 0
  services = { ssh = false }
}

import {
  to = truenas_tn_connect_config.this
  id = "tn_connect_config"
}

# Enabling TrueNAS Connect starts a real cloud enrollment.
resource "truenas_tn_connect_config" "this" {
  enabled = false
}

import {
  to = truenas_truecommand_config.this
  id = "truecommand_config"
}

resource "truenas_truecommand_config" "this" {
  enabled = false
}

import {
  to = truenas_replication_config.this
  id = "replication_config"
}

resource "truenas_replication_config" "this" {
  max_parallel_replication_tasks = 5
}

import {
  to = truenas_resilver_config.this
  id = "resilver_config"
}

resource "truenas_resilver_config" "this" {
  enabled = false
  begin   = "18:00"
  end     = "09:00"
  weekday = [1, 2, 3, 4, 5, 6, 7]
}
