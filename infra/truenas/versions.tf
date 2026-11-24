terraform {
  required_version = ">= 1.11"

  required_providers {
    truenas = {
      source  = "truenas/truenas"
      version = "1.9.3"
    }
  }

  encryption {
    key_provider "pbkdf2" "state" {
      passphrase = var.state_passphrase
    }

    method "aes_gcm" "state" {
      keys = key_provider.pbkdf2.state
    }

    state {
      method   = method.aes_gcm.state
      enforced = true
    }

    plan {
      method   = method.aes_gcm.state
      enforced = true
    }
  }
}

provider "truenas" {
  endpoint = "wss://truenas.dropbear-tortoise.ts.net/api/current"
  # TrueNAS still serves its self-signed "localhost" certificate, so TLS cannot
  # verify the name; WireGuard on the tailnet authenticates the peer instead.
  insecure = true
}
