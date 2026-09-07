-- WezTerm starter config (harness-bundle Track A)
-- Jeffrey's alternate pick alongside Ghostty; native Windows; pairs with tmux-in-WSL.
-- Docs: https://wezterm.org/config/files.html
local wezterm = require("wezterm")
local config = wezterm.config_builder()

local userprofile = os.getenv("USERPROFILE") or ("C:\\Users\\" .. (os.getenv("USERNAME") or "USER"))
local grok_env = userprofile .. "\\.config\\xai\\grok-env.ps1"

-- Launch menu. Tab bar is hidden with one tab, so use CTRL+SHIFT+L
-- or CTRL+SHIFT+G instead of clicking +.
config.launch_menu = {
	{ label = "PowerShell", args = { "powershell.exe", "-NoLogo" } },
	{ label = "Git Bash", args = { "C:\\Program Files\\Git\\bin\\bash.exe", "-l" } },
	{ label = "WSL Ubuntu (root)", args = { "wsl.exe", "-d", "Ubuntu", "-u", "root" } },
	{
		label = "Claude (Grok sub)",
		args = {
			"powershell.exe",
			"-NoExit",
			"-ExecutionPolicy",
			"Bypass",
			"-File",
			grok_env,
		},
	},
}
-- Default: PowerShell (change to the WSL entry above if ntm/tmux is your daily driver).
config.default_prog = { "powershell.exe", "-NoLogo" }

-- WSL distros also appear automatically as launchable domains (wezterm ssh/wsl integration).

config.font_size = 11.0
config.scrollback_lines = 10000
config.hide_tab_bar_if_only_one_tab = true
config.window_close_confirmation = "NeverPrompt"
config.audible_bell = "Disabled"
-- Kitty keyboard protocol: needed for Ctrl+Enter (Grok interject) and other modified Enter keys.
config.enable_kitty_keyboard = true

local localappdata = os.getenv("LOCALAPPDATA") or "C:\\Users\\USER\\AppData\\Local"
local getclip = localappdata .. "\\agy\\bin\\getclip.exe"

local function paste_unbracketed(window, pane)
	local success, stdout, stderr = wezterm.run_child_process({ getclip })
	if success and stdout and #stdout > 0 then
		pane:send_text(stdout)
	else
		window:perform_action(wezterm.action.PasteFrom("Clipboard"), pane)
	end
end

-- Native panes when you want splits OUTSIDE tmux (tmux inside WSL keeps its own keys):
-- ALT+Shift+% vertical / ALT+Shift+" horizontal are awkward on some layouts; use these:
config.keys = {
	{ key = "|", mods = "ALT|SHIFT", action = wezterm.action.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "_", mods = "ALT|SHIFT", action = wezterm.action.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "LeftArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Left") },
	{ key = "RightArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Right") },
	{ key = "UpArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Up") },
	{ key = "DownArrow", mods = "ALT", action = wezterm.action.ActivatePaneDirection("Down") },
	{
		key = "Backspace",
		mods = "CTRL",
		action = wezterm.action.SendKey({ key = "w", mods = "CTRL" }),
	},
	-- Paste: make Wispr Flow (and any clipboard paste) work everywhere including agy CLI
	-- agy CLI drops bracketed paste (\x1b[200~); sending text directly via getclip.exe bypasses this
	{ key = "V", mods = "CTRL", action = wezterm.action_callback(paste_unbracketed) },
	{ key = "V", mods = "CTRL|SHIFT", action = wezterm.action_callback(paste_unbracketed) },
	{ key = "Insert", mods = "SHIFT", action = wezterm.action_callback(paste_unbracketed) },
	{ key = "C", mods = "CTRL|SHIFT", action = wezterm.action.CopyTo("Clipboard") },
	{ key = "C", mods = "CTRL", action = wezterm.action.CopyTo("ClipboardAndPrimarySelection") },
	{
		key = "L",
		mods = "CTRL|SHIFT",
		action = wezterm.action.ShowLauncherArgs({ flags = "LAUNCH_MENU_ITEMS" }),
	},
	{
		key = "G",
		mods = "CTRL|SHIFT",
		action = wezterm.action.SpawnCommandInNewWindow({
			args = {
				"powershell.exe",
				"-NoExit",
				"-ExecutionPolicy",
				"Bypass",
				"-File",
				grok_env,
			},
		}),
	},
}

-- Let right-click paste when no selection (Windows expectation)
config.mouse_bindings = {
	{
		event = { Down = { streak = 1, button = "Right" } },
		mods = "NONE",
		action = wezterm.action_callback(function(window, pane)
			local has_selection = window:get_selection_text_for_pane(pane) ~= ""
			if has_selection then
				window:perform_action(wezterm.action.CopyTo("Clipboard"), pane)
			else
				paste_unbracketed(window, pane)
			end
		end),
	},
}

return config
