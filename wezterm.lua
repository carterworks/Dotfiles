-- docs: https://wezfurlong.org/wezterm/config/lua/general.html
-- and: https://wezfurlong.org/wezterm/config/files.html
-- for inspiration: https://alexplescan.com/posts/2024/08/10/wezterm/

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- color scheme
config.color_scheme = 'Selenized Light (Gogh)'
local color_scheme = wezterm.color.get_builtin_schemes()[config.color_scheme]
local bg = color_scheme.background
local fg = color_scheme.foreground
-- font
config.font = wezterm.font({
	family = 'Iosevka',
	harfbuzz_features = { 'liga=1', 'calt=1', 'ss15=1' }
})
config.font_size = 16
config.freetype_load_flags = 'NO_HINTING'

-- window background
config.window_background_opacity = 0.90
config.macos_window_background_blur = 30
config.window_decorations = 'INTEGRATED_BUTTONS|RESIZE'

config.window_close_confirmation = 'NeverPrompt'

-- command palette
config.command_palette_bg_color = bg
config.command_palette_fg_color = fg
config.command_palette_font_size = 16
config.command_palette_rows = 8

-- tab bar
config.window_frame = {
	font = wezterm.font({ family = 'Iosevka' }),
	font_size = 14,
}

-- launch menu - https://wezfurlong.org/wezterm/config/launch.html#the-launcher-menu
local launch_menu = {}
if wezterm.target_triple == "x86_64-pc-windows-msvc" then
	table.insert(launch_menu, {
    label = "Command Prompt",
    args = { '%SystemRoot%\\System32\\cmd.exe' }
  })
	table.insert(launch_menu, {
    label = "PowerShell (System)",
    args = { '%SystemRoot%\\System32\\WindowsPowerShell\\v1.0\\powershell.exe' }
  })
	table.insert(launch_menu,  {
    label = 'Powershell',
    args = { 'C:\\Users\\carte\\AppData\\Local\\Microsoft\\WindowsApps\\Microsoft.PowerShell_8wekyb3d8bbwe\\pwsh.exe', '-NoLogo' },
  })
	table.insert(launch_menu,   {
    label = 'Ubuntu 20.04',
    args = { 'wsl', '-d', 'Ubuntu-20.04' },
  })
end
config.launch_menu = launch_menu

-- hotkeys
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
