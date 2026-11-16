--- Lazy.nvim configuration example for physical-keyboard.nvim
--- Copy this configuration to your lazy.nvim setup
---@diagnostic disable: undefined-field
--[[
{
	dir = "~/.config/nvim/lazy/physical-keyboard.nvim",
	event = { "VeryLazy" },
	opts = {
		-- Set only the layouts you use. Defaults to { "ru" }.
		-- Use {} to enable every bundled layout.
		active_layouts = { "ru" },
		-- active_layouts = { "ru", "de", "fr" },

		detect = { enabled = true },
		mappings = { automapping = true, hack_keymap = true },
		cmdline = { enabled = true },
	},
}
]]
