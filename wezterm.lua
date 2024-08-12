-- docs: https://wezfurlong.org/wezterm/config/lua/general.html
-- and: https://wezfurlong.org/wezterm/config/files.html
-- for inspiration: https://alexplescan.com/posts/2024/08/10/wezterm/

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- color scheme
config.color_scheme = 'Solarized Light (Gogh)'
local color_scheme = wezterm.color.get_builtin_schemes()[config.color_scheme]
local bg = color_scheme.background
local fg = color_scheme.foreground
-- font
config.font = wezterm.font_with_fallback(
	{
		family = 'Iosevka',
		harfbuzz_features = { 'liga=1', 'calt=1', 'ss15=1' }
	},
)
config.font_size = 16

-- window background
config.window_background_opacity = 0.95
config.macos_window_background_blur = 30
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'

config.window_close_confirmation = 'NeverPrompt'

-- command palette
config.command_palette_bg_color = bg
config.command_palette_fg_color = fg
config.command_palette_font_size = 16
config.command_palette_rows = 8

-- tab bar
wezterm.on('update-status', function(window)
	local SOLID_LEFT_ARROW = utf8.char(0xe0b2)
	window:set_right_status(wezterm.format({
		{ Background = { Color = 'none' } },
		{ Foreground = { Color = bg } },
		{ Text = SOLID_LEFT_ARROW },
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Text = ' ' .. wezterm.hostname() .. ' ' },
	}))
end)
config.window_frame = {
	font = wezterm.font({ family = 'Iosevka Aile' }),
	font_size = 13,
}
config.hide_tab_bar_if_only_one_tab = true



config.keys = {
	-- Sends ESC + b and ESC + f sequence, which is
	-- used to tell the shell to jump back/forwards.
	{
		-- Go forward one word
		key = 'LeftArrow',
		mods = 'OPT',
		action = wezterm.action.SendString '\x1bb',
	},
	{
		-- Go back one word
		key = 'RightArrow',
		mods = 'OPT',
		action = wezterm.action.SendString '\x1bf',
	},
}

return config