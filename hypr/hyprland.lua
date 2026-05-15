local colors = require("colors")

hl.monitor({
  output = "",
  mode = "preferred",
  position = "auto",
  scale = "auto",
})

local terminal = "ghostty"
local file_manager = "cosmic-files"
local menu = "vicinae toggle"
local browser = "brave"
local main_mod = "SUPER"
local app_mod = main_mod .. " + SHIFT"

hl.on("hyprland.start", function()
  hl.exec_cmd("ashell")
  hl.exec_cmd("mako")
  hl.exec_cmd("systemctl --user start hyprpolkitagent")
  hl.exec_cmd("vicinae server")
  hl.exec_cmd("trayscale --hide-window")
end)

hl.env("XCURSOR_SIZE", "24")
hl.env("XCURSOR_THEME", "Bibata-Modern-Classic")
hl.env("HYPRCURSOR_SIZE", "24")
hl.env("HYPRCURSOR_THEME", "Bibata-Modern-Classic")

hl.config({
  general = {
    gaps_in = 4,
    gaps_out = 4,
    border_size = 2,
    col = {
      active_border = colors.active_border,
      inactive_border = colors.inactive_border,
    },
    resize_on_border = false,
    allow_tearing = false,
    layout = "dwindle",
  },

  decoration = {
    rounding = 10,
    rounding_power = 4,
    active_opacity = 1.0,
    inactive_opacity = 1.0,
    shadow = {
      enabled = true,
      range = 4,
      render_power = 3,
      color = colors.shadow,
    },
    blur = {
      enabled = true,
      size = 3,
      passes = 1,
      vibrancy = 0.1696,
    },
  },

  animations = {
    enabled = true,
  },

  dwindle = {
    pseudotile = true,
    preserve_split = true,
  },

  master = {
    new_status = "master",
  },

  misc = {
    force_default_wallpaper = 0,
    disable_hyprland_logo = true,
  },

  input = {
    kb_layout = "us",
    kb_variant = "",
    kb_model = "",
    kb_options = "",
    kb_rules = "",
    follow_mouse = 1,
    sensitivity = 0,
    touchpad = {
      natural_scroll = false,
    },
  },
})

hl.curve("easeOutQuad", { type = "bezier", points = { { 0.25, 0.46 }, { 0.45, 0.94 } } })
hl.curve("easeOutCubic", { type = "bezier", points = { { 0.215, 0.61 }, { 0.355, 1 } } })
hl.curve("easeOutQuint", { type = "bezier", points = { { 0.23, 1 }, { 0.32, 1 } } })
hl.curve("easeInOutCubic", { type = "bezier", points = { { 0.645, 0.045 }, { 0.355, 1 } } })
hl.curve("ease", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })
hl.curve("linear", { type = "bezier", points = { { 0, 0 }, { 1, 1 } } })

hl.animation({ leaf = "global", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "border", enabled = true, speed = 2, bezier = "ease" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 100, bezier = "linear", style = "loop" })
hl.animation({ leaf = "windowsIn", enabled = true, speed = 2.5, bezier = "easeOutCubic", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 2, bezier = "easeOutCubic", style = "popin 95%" })
hl.animation({ leaf = "windowsMove", enabled = true, speed = 2.5, bezier = "easeInOutCubic" })
hl.animation({ leaf = "fade", enabled = true, speed = 1.5, bezier = "easeOutCubic" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.5, bezier = "easeOutCubic" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.2, bezier = "easeOutCubic" })
hl.animation({ leaf = "fadeSwitch", enabled = true, speed = 1.5, bezier = "ease" })
hl.animation({ leaf = "fadeShadow", enabled = true, speed = 1.5, bezier = "ease" })
hl.animation({ leaf = "layersIn", enabled = true, speed = 2, bezier = "easeOutCubic", style = "popin 95%" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.5, bezier = "easeOutCubic", style = "popin 95%" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.5, bezier = "easeOutCubic" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.2, bezier = "easeOutCubic" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 2.5, bezier = "easeInOutCubic", style = "slide" })
hl.animation({ leaf = "workspacesIn", enabled = true, speed = 2.5, bezier = "easeInOutCubic", style = "slide" })
hl.animation({ leaf = "workspacesOut", enabled = true, speed = 2, bezier = "easeInOutCubic", style = "slide" })
hl.animation({ leaf = "zoomFactor", enabled = true, speed = 2, bezier = "easeOutQuint" })
hl.animation({ leaf = "monitorAdded", enabled = true, speed = 2.5, bezier = "easeOutCubic" })

hl.gesture({ fingers = 3, direction = "horizontal", action = "workspace" })

hl.device({
  name = "epic-mouse-v1",
  sensitivity = -0.5,
})

hl.bind(main_mod .. " + W", hl.dsp.window.close())
hl.bind("CTRL + SPACE", hl.dsp.exec_cmd(menu))
hl.bind(main_mod .. " + return", hl.dsp.exec_cmd(terminal))
hl.bind("PRINT", hl.dsp.exec_cmd('grim -g "$(slurp)" ~/Pictures/Screenshots/screenshot-$(date +%Y-%m-%d_%H-%M-%S).png'))
hl.bind("SHIFT + PRINT", hl.dsp.exec_cmd('grim -g "$(slurp)" - | wl-copy'))
hl.bind(app_mod .. " + F", hl.dsp.exec_cmd(file_manager))
hl.bind(app_mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(app_mod .. " + W", hl.dsp.exec_cmd("command pkill waybar & waybar &"))
hl.bind(main_mod .. " + V", hl.dsp.window.float({ action = "toggle" }))

hl.bind(main_mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(main_mod .. " + right", hl.dsp.focus({ direction = "right" }))
hl.bind(main_mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(main_mod .. " + down", hl.dsp.focus({ direction = "down" }))

for i = 1, 10 do
  local key = i % 10
  hl.bind(main_mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
  hl.bind(main_mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(main_mod .. " + S", hl.dsp.workspace.toggle_special("magic"))
hl.bind(main_mod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic" }))
hl.bind(main_mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(main_mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))
hl.bind(main_mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(main_mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"), { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%+"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 5%-"), { locked = true, repeating = true })
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

hl.window_rule({
  name = "suppress-maximize-events",
  match = { class = ".*" },
  suppress_event = "maximize",
})

hl.window_rule({
  name = "chrome-ext-float",
  match = { class = "(chrome|brave)-.+-(Default|Profile_\\d+)" },
  float = true,
})

hl.window_rule({
  name = "fix-xwayland-drags",
  match = {
    class = "^$",
    title = "^$",
    xwayland = true,
    float = true,
    fullscreen = false,
    pin = false,
  },
  no_focus = true,
})

hl.layer_rule({
  name = "vicinae-blur",
  match = { namespace = "vicinae" },
  blur = true,
  ignore_alpha = 0,
})

hl.layer_rule({
  name = "vicinae-no-animation",
  match = { namespace = "vicinae" },
  no_anim = true,
})
