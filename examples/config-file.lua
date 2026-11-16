-- ~/.config/nvim/physical-keyboard.lua
-- Enable it with setup({ config_file = true }).
return {
	active_layouts = { "ru" },
	fallback = "unique",
	detect = {
		enabled = true,
		-- provider = "niri",
	},
	mappings = {
		exclude = { "<Leader>f" },
	},
}
