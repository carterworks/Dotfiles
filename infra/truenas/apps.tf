import {
  to = truenas_app.tailscale
  id = "tailscale"
}

# TrueNAS's tailnet node, which scylla's SMB mounts and OpenTofu reach it
# through. The provider reads back only the values listed here, so the auth
# key stays out of this configuration and the state. The version is pinned:
# the default, "latest", would upgrade the app on the next apply.
resource "truenas_app" "tailscale" {
  name        = "tailscale"
  catalog_app = "tailscale"
  train       = "community"
  version     = "1.4.27"
  values = jsonencode({
    TZ        = "America/Denver"
    labels    = []
    network   = { host_network = true }
    resources = { limits = { cpus = 2, memory = 4096 } }
    storage = {
      additional_storage = []
      state = {
        type             = "ix_volume"
        ix_volume_config = { acl_enable = false, dataset_name = "state" }
      }
    }
    tailscale = {
      hostname            = "herodotus"
      advertise_exit_node = true
      advertise_routes    = []
      accept_routes       = false
      accept_dns          = true
      userspace           = true
      auth_once           = true
      reset               = false
      extra_args          = []
      tailscaled_args     = []
      additional_envs     = []
    }
  })

  # Uninstalling it takes TrueNAS off the tailnet.
  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = truenas_app_registry.docker_hub
  id = "1"
}

resource "truenas_app_registry" "docker_hub" {
  name                = "Docker Hub"
  uri                 = "https://index.docker.io/v1/"
  username            = var.dockerhub_username
  password_wo         = var.dockerhub_password
  password_wo_version = 1
}
