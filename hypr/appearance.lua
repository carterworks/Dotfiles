local colors = require("desktop-colors")

hl.config({
    general = {
        layout = "scrolling",
        gaps_in = 6,
        gaps_out = 12,
        border_size = 2,
        col = {
            active_border = colors.active_border,
            inactive_border = colors.inactive_border,
        },
        resize_on_border = true,
    },
    scrolling = {
        column_width = 0.5,
        fullscreen_on_one_column = false,
        focus_fit_method = 1,
        follow_focus = true,
        explicit_column_widths = "0.333, 0.5, 0.667, 1.0",
    },
    decoration = {
        rounding = 12,
        shadow = { enabled = true, range = 12, render_power = 3, color = 0x44000000 },
        blur = { enabled = true, size = 4, passes = 2 },
    },
    input = {
        kb_layout = "us",
        follow_mouse = 1,
        sensitivity = 0,
        touchpad = { natural_scroll = true },
    },
    misc = {
        disable_hyprland_logo = true,
        force_default_wallpaper = -1,
    },
})

hl.curve("easeOutExpo", { type = "bezier", points = { { 0.19, 1 }, { 0.22, 1 } } })
hl.curve("ease", { type = "bezier", points = { { 0.25, 0.1 }, { 0.25, 1 } } })

-- Opt in only occasional entrances/exits. Workspace switches, scrolling,
-- resizing, focus feedback and decorative effects inherit instant updates.
hl.animation({ leaf = "global", enabled = false })

-- Speeds are deciseconds: 1.8 = 180ms. Large windows barely scale;
-- exits use the same curve, less movement and a shorter duration.
hl.animation({ leaf = "windowsIn", enabled = true, speed = 1.8, bezier = "easeOutExpo", style = "popin 95%" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 1.2, bezier = "easeOutExpo", style = "popin 97%" })
hl.animation({ leaf = "fadeIn", enabled = true, speed = 1.8, bezier = "ease" })
hl.animation({ leaf = "fadeOut", enabled = true, speed = 1.2, bezier = "ease" })

-- Shell surfaces fade without sliding or scaling; Vicinae's no_anim rule
-- keeps the keyboard launcher instant regardless of these settings.
hl.animation({ leaf = "layersIn", enabled = true, speed = 1.6, bezier = "ease", style = "fade" })
hl.animation({ leaf = "layersOut", enabled = true, speed = 1.2, bezier = "ease", style = "fade" })
hl.animation({ leaf = "fadeLayersIn", enabled = true, speed = 1.6, bezier = "ease" })
hl.animation({ leaf = "fadeLayersOut", enabled = true, speed = 1.2, bezier = "ease" })
