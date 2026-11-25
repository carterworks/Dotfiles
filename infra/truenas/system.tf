locals {
  # Keys are server addresses; `id` is the row ID, used only to import.
  ntp_servers = {
    "0.debian.pool.ntp.org" = { id = 1 }
    "1.debian.pool.ntp.org" = { id = 2 }
    "2.debian.pool.ntp.org" = { id = 3 }
  }
}

import {
  to = truenas_system_general.this
  id = "system_general"
}

resource "truenas_system_general" "this" {
  timezone           = "America/Denver"
  kbdmap             = "us"
  ds_auth            = false
  usage_collection   = false
  ui_address         = ["0.0.0.0"]
  ui_v6address       = ["::"]
  ui_allowlist       = []
  ui_port            = 80
  ui_httpsport       = 443
  ui_httpsredirect   = false
  ui_httpsprotocols  = ["TLSv1.2", "TLSv1.3"]
  ui_certificate     = 1
  ui_consolemsg      = false
  ui_x_frame_options = "SAMEORIGIN"
}

import {
  to = truenas_system_advanced.this
  id = "system_advanced"
}

resource "truenas_system_advanced" "this" {
  advancedmode         = false
  anonstats            = true
  autotune             = false
  boot_scrub           = 7
  consolemenu          = true
  consolemsg           = false
  debugkernel          = false
  fqdn_syslog          = false
  kdump_enabled        = false
  kernel_extra_options = ""
  login_banner         = ""
  motd                 = "Welcome to TrueNAS"
  nvidia               = false
  powerdaemon          = false
  sed_user             = "USER"
  serialconsole        = false
  serialport           = "ttyS0"
  serialspeed          = "9600"
  syslog_audit         = false
  sysloglevel          = "F_INFO"
  syslogservers        = []
  traceback            = true
  uploadcrash          = true
}

import {
  to = truenas_system_dataset.this
  id = "system_dataset"
}

resource "truenas_system_dataset" "this" {
  pool = "reservoir"
}

import {
  for_each = local.ntp_servers
  to       = truenas_ntp_server.this[each.key]
  id       = each.value.id
}

resource "truenas_ntp_server" "this" {
  for_each = local.ntp_servers

  address = each.key
  burst   = false
  iburst  = true
  minpoll = 6
  maxpoll = 10
  prefer  = false
}
