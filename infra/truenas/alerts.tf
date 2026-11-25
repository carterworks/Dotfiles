import {
  to = truenas_mail.this
  id = "mail"
}

# fromemail and fromname are a personal address and name, left unmanaged to
# keep them out of this public repository. The provider has no OAuth
# attribute, so the Gmail OAuth credentials stay only on TrueNAS.
resource "truenas_mail" "this" {
  outgoingserver = ""
  port           = 25
  security       = "PLAIN"
  smtp           = false
  user           = ""
}

import {
  to = truenas_alert_policy.this
  id = "alert_policy"
}

# No alert class overrides its default level or policy.
resource "truenas_alert_policy" "this" {
  classes = jsonencode({})
}

import {
  to = truenas_alert_service.snmp_trap
  id = "1"
}

resource "truenas_alert_service" "snmp_trap" {
  name    = "SNMP Trap"
  level   = "WARNING"
  enabled = true
  attributes = jsonencode({
    type            = "SNMPTrap"
    host            = "localhost"
    port            = 162
    v3              = false
    community       = var.snmp_community
    v3_username     = null
    v3_authkey      = null
    v3_privkey      = null
    v3_authprotocol = null
    v3_privprotocol = null
  })

  # Losing it would silently stop alerting.
  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = truenas_alert_service.email
  id = "2"
}

# An empty address sends to the mail settings' default recipient.
resource "truenas_alert_service" "email" {
  name    = "E-Mail"
  level   = "WARNING"
  enabled = true
  attributes = jsonencode({
    type  = "Mail"
    email = ""
  })

  # Losing it would silently stop alerting.
  lifecycle {
    prevent_destroy = true
  }
}
