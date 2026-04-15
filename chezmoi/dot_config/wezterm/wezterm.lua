local wezterm = require("wezterm")

local act = wezterm.action
local config = wezterm.config_builder()

config.color_scheme = "Catppuccin Mocha"
config.colors = {
	background = "#000000",
}
config.font = wezterm.font_with_fallback({
	{ family = "Maple Mono NF", weight = "Medium" },
	{ family = "FiraCode Nerd Font Mono", weight = "Medium" },
	{ family = "FiraCode Nerd Font", weight = "Medium" },
})
config.font_size = 13.7
config.freetype_load_target = "Normal"
config.freetype_render_target = "HorizontalLcd"
config.disable_default_key_bindings = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = false
config.window_close_confirmation = "NeverPrompt"
config.window_padding = {
	left = 6,
	right = 6,
	top = 4,
	bottom = 4,
}

config.default_cursor_style = "SteadyBar"

config.unix_domains = {
	{
		name = "unix",
	},
}

config.default_gui_startup_args = { "connect", "unix" }

wezterm.on("format-tab-title", function(tab, tabs, panes, config, hover, max_width)
	local title = tostring(tab.tab_index + 1)
	local pane = tab.active_pane

	-- Get the pane title which often contains git branch info
	local pane_title = pane.title

	-- Try to extract branch from pane title if it's in the format "user@host:path (branch)"
	-- or just use the current working directory name
	local cwd_uri = pane.current_working_dir
	if cwd_uri then
		local cwd = cwd_uri.file_path or tostring(cwd_uri)
		cwd = cwd:gsub("file://[^/]*/", "/")

		-- Get the directory name (which in worktree setup is the branch name)
		local dir_name = cwd:match("([^/]+)/?$")
		if dir_name and dir_name ~= "" then
			title = title .. ": " .. dir_name
		end
	end

	return {
		{ Text = " " .. title .. " " },
	}
end)

wezterm.on("gui-startup", function(cmd)
	local cwd = cmd and cmd.cwd or nil
	wezterm.mux.spawn_window({
		cwd = cwd,
		workspace = "local",
	})
end)

config.keys = {
	{ key = "L", mods = "SUPER|SHIFT", action = act.SwitchToWorkspace({ name = "local" }) },
	{ key = "D", mods = "SUPER|SHIFT", action = act.SwitchToWorkspace({ name = "dev" }) },
	{ key = "W", mods = "SUPER|SHIFT", action = act.ShowLauncherArgs({ flags = "FUZZY|WORKSPACES" }) },
	{ key = "R", mods = "SUPER|SHIFT", action = act.ReloadConfiguration },
	{ key = "+", mods = "SUPER", action = act.IncreaseFontSize },
	{ key = "-", mods = "SUPER", action = act.DecreaseFontSize },
}

return config
