variable "state_passphrase" {
  description = "Encrypts state and plan files (fnox: TRUENAS_TOFU_STATE_PASSPHRASE)."
  type        = string
  sensitive   = true
}

variable "fleet" {
  description = "Shared values from nix/lib/fleet.nix (lan, nasIds), passed by the wrapper."
  type = object({
    lan    = object({ truenas = string, prostagma = string })
    nasIds = object({ apps = number, humans = number, media = number })
  })
}

variable "connectivity_check_url" {
  description = "healthchecks.io ping URL for the connectivity cron job (fnox: TRUENAS_CONNECTIVITY_CHECK_URL)."
  type        = string
  sensitive   = true
}

variable "snmp_community" {
  description = "SNMP community (fnox: TRUENAS_SNMP_COMMUNITY)."
  type        = string
  sensitive   = true
}

variable "dockerhub_username" {
  description = "Docker Hub login for the app registry (fnox: TRUENAS_DOCKERHUB_USERNAME)."
  type        = string
  sensitive   = true
}

variable "dockerhub_password" {
  description = "Docker Hub password for the app registry (fnox: TRUENAS_DOCKERHUB_PASSWORD)."
  type        = string
  sensitive   = true
  ephemeral   = true
}
