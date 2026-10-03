require("appearance")
require("bindings")
require("rules")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })

-- UWSM starts the Quickshell, network and polkit systemd services, plus XDG
-- autostart applications (including the existing Vicinae server).
