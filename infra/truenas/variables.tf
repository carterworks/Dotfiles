variable "state_passphrase" {
  description = "Encrypts state and plan files (fnox: TRUENAS_TOFU_STATE_PASSPHRASE)."
  type        = string
  sensitive   = true
}

variable "connectivity_check_url" {
  description = "healthchecks.io ping URL for the connectivity cron job (fnox: TRUENAS_CONNECTIVITY_CHECK_URL)."
  type        = string
  sensitive   = true
}
