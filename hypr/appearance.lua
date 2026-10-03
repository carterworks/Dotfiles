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
