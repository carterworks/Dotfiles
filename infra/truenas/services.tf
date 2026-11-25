locals {
  # Whether each service starts at boot. Whether it is running at the moment
  # is not managed: a stopped service is not restarted by an apply.
  services = {
    cifs        = true
    nfs         = true
    ssh         = true
    ups         = true
    ftp         = false
    iscsitarget = false
    nvmet       = false
    snmp        = false
  }
}

import {
  for_each = local.services
  to       = truenas_service.this[each.key]
  id       = each.key
}

resource "truenas_service" "this" {
  for_each = local.services

  name    = each.key
  enabled = each.value
}

import {
  to = truenas_ssh_config.this
  id = "ssh_config"
}

resource "truenas_ssh_config" "this" {
  tcpport               = 22
  bindiface             = []
  passwordauth          = true
  password_login_groups = ["humans"]
  kerberosauth          = false
  tcpfwd                = false
  compression           = false
  weak_ciphers          = ["AES128-CBC", "NONE"]
  sftp_log_facility     = ""
  sftp_log_level        = ""
  options               = ""
}

import {
  to = truenas_ups_config.this
  id = "ups_config"
}

# The monitor password (monpwd) is write-only and left as it is.
resource "truenas_ups_config" "this" {
  mode           = "MASTER"
  identifier     = "ups"
  driver         = "usbhid-ups$CP900AVR"
  port           = "auto"
  description    = ""
  monuser        = "upsmon"
  extrausers     = ""
  remotehost     = ""
  remoteport     = 3493
  rmonitor       = true
  shutdown       = "LOWBATT"
  shutdowntimer  = 30
  shutdowncmd    = ""
  powerdown      = false
  hostsync       = 15
  nocommwarntime = 0
  options        = ""
  optionsupsd    = ""
}

import {
  to = truenas_snmp_config.this
  id = "snmp_config"
}

resource "truenas_snmp_config" "this" {
  community    = var.snmp_community
  contact      = ""
  location     = ""
  loglevel     = 3
  options      = ""
  traps        = false
  v3           = false
  v3_authtype  = "SHA"
  v3_privproto = ""
  v3_username  = ""
  zilstat      = false
}

import {
  to = truenas_ftp_config.this
  id = "ftp_config"
}

# The FTP service is disabled; its settings are TrueNAS's defaults.
resource "truenas_ftp_config" "this" {
  port                                = 21
  clients                             = 5
  ipconnections                       = 2
  loginattempt                        = 1
  timeout                             = 600
  timeout_notransfer                  = 300
  onlyanonymous                       = false
  onlylocal                           = false
  anonpath                            = ""
  defaultroot                         = true
  banner                              = ""
  filemask                            = "077"
  dirmask                             = "022"
  fxp                                 = false
  resume                              = false
  reversedns                          = false
  masqaddress                         = ""
  passiveportsmin                     = 0
  passiveportsmax                     = 0
  localuserbw                         = 0
  localuserdlbw                       = 0
  anonuserbw                          = 0
  anonuserdlbw                        = 0
  ident                               = false
  options                             = ""
  tls                                 = false
  tls_policy                          = "on"
  ssltls_certificate                  = 0
  tls_opt_allow_client_renegotiations = false
  tls_opt_allow_dot_login             = false
  tls_opt_allow_per_user              = false
  tls_opt_common_name_required        = false
  tls_opt_dns_name_required           = false
  tls_opt_enable_diags                = false
  tls_opt_export_cert_data            = false
  tls_opt_ip_address_required         = false
  tls_opt_no_empty_fragments          = false
  tls_opt_no_session_reuse_required   = false
  tls_opt_stdenvvars                  = false
}
