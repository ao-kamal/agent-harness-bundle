-- WezTerm starter config
-- Jeffrey's alternate pick alongside Ghostty; native Windows; pairs with tmux-in-WSL.
-- Docs: https://wezterm.org/config/files.html
local wezterm = require("wezterm")
local config = wezterm.config_builder()

-- Launch menu: right-click the + tab button (or SHIFT-click) to pick a shell.
config.launch_menu = {
	{ label = "PowerShell", args = { "powershell.exe", "-NoLogo" } },
	{ label = "Git Bash", args = { "C:\\Program Files\\Git\\bin\\bash.exe", "-l" } },
	{ label = "WSL Ubuntu (root)", args = { "wsl.exe", "-d", "Ubuntu", "-u", "root" } },
}
-- Default: PowerShell (change to the WSL entry above if ntm/tmux is your daily driver).
config.default_prog = { "powershell.exe", "-NoLogo" }

-- WSL distros also appear automatically as launchable domains (wezterm ssh/wsl integration).

config.font_size = 11.0
config.scrollback_lines = 10000
config.hide_tab_bar_if_only_one_tab = true
config.window_close_confirmation = "NeverPrompt"
config.audible_bell = "Disabled"

-- Native panes when you want splits OUTSIDE tmux (tmux inside WSL keeps its own keys):
-- ALT+Shift+% vertical / ALT+Shift+" horizontal are awkward on some layouts; use these:
config.keys = {
	{ key = "|", mods = "ALT|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "_", mods = "ALT|SHIFT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "LeftArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "RightArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Right") },
	{ key = "UpArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "DownArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Down") },
}

return config
