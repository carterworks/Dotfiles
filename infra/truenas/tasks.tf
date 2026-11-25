locals {
  snapshot_tasks = {
    reservoir = {
      id             = 1
      lifetime_value = 2
      lifetime_unit  = "MONTH"
      hour           = "0"
      exclude        = []
    }
    river-rapid = {
      id             = 2
      lifetime_value = 2
      lifetime_unit  = "WEEK"
      hour           = "*"
      exclude = [
        "river-rapid/vm-data/qbittorrent-vpn/data",
        "river-rapid/vm-data/resilio-sync",
      ]
    }
  }

  scrub_tasks = {
    reservoir   = { id = 1 }
    river-rapid = { id = 2 }
  }

  # 25.10 removed SMART test scheduling and migrated the old schedules to
  # these cron jobs.
  cronjobs = {
    connectivity_check = {
      id          = 2
      description = "Connectivity Check"
      user        = "carter"
      command     = "curl --doh-url https://1.1.1.1/dns-query --request GET --fail --show-error --silent --retry 3 --retry-delay 2 --connect-timeout 15 --max-time 30 ${var.connectivity_check_url}"
      stderr      = false
      schedule    = { minute = "*/15", hour = "*", dom = "*", month = "*", dow = "*" }
    }
    smart_short = {
      id          = 3
      description = "S.M.A.R.T. Test"
      user        = "root"
      command     = "midclt call disk.smart_test SHORT '[\"*\"]'"
      stderr      = true
      schedule    = { minute = "00", hour = "23", dom = "*", month = "*", dow = "*" }
    }
    smart_long = {
      id          = 4
      description = "S.M.A.R.T. Test"
      user        = "root"
      command     = "midclt call disk.smart_test LONG '[\"*\"]'"
      stderr      = true
      schedule    = { minute = "00", hour = "21", dom = "1", month = "*", dow = "*" }
    }
  }
}

import {
  for_each = local.snapshot_tasks
  to       = truenas_periodic_snapshot_task.this[each.key]
  id       = each.value.id
}

resource "truenas_periodic_snapshot_task" "this" {
  for_each = local.snapshot_tasks

  dataset        = truenas_dataset.this[each.key].name
  recursive      = true
  exclude        = each.value.exclude
  lifetime_value = each.value.lifetime_value
  lifetime_unit  = each.value.lifetime_unit
  naming_schema  = "auto-%Y-%m-%d_%H-%M"
  allow_empty    = false
  enabled        = true
  schedule = {
    minute = "0"
    hour   = each.value.hour
    dom    = "*"
    month  = "*"
    dow    = "*"
    begin  = "00:00"
    end    = "23:59"
  }

  lifecycle {
    prevent_destroy = true
  }
}

data "truenas_pool" "this" {
  for_each = local.scrub_tasks
  name     = each.key
}

import {
  for_each = local.scrub_tasks
  to       = truenas_scrub_task.this[each.key]
  id       = each.value.id
}

resource "truenas_scrub_task" "this" {
  for_each = local.scrub_tasks

  pool        = data.truenas_pool.this[each.key].id
  description = ""
  enabled     = true
  threshold   = 35
  schedule = {
    minute = "00"
    hour   = "00"
    dom    = "*"
    month  = "*"
    dow    = "7"
  }

  lifecycle {
    prevent_destroy = true
  }
}

import {
  for_each = local.cronjobs
  to       = truenas_cronjob.this[each.key]
  id       = each.value.id
}

resource "truenas_cronjob" "this" {
  for_each = local.cronjobs

  description = each.value.description
  user        = each.value.user
  command     = each.value.command
  enabled     = true
  stdout      = true
  stderr      = each.value.stderr
  schedule    = each.value.schedule

  lifecycle {
    prevent_destroy = true
  }
}

import {
  to = truenas_init_shutdown_script.enable_linger_carter
  id = 1
}

resource "truenas_init_shutdown_script" "enable_linger_carter" {
  type    = "COMMAND"
  when    = "POSTINIT"
  command = "/usr/bin/loginctl enable-linger carter"
  script  = ""
  comment = "Start T3 Code after reboot for carter"
  enabled = true
  timeout = 10

  lifecycle {
    prevent_destroy = true
  }
}
