--- Lazy.nvim configuration example for physical-keyboard.nvim
--- Copy this configuration to your lazy.nvim setup
---@diagnostic disable: undefined-field
--[[
{
	dir = "~/.config/nvim/lazy/physical-keyboard.nvim",
	event = "VeryLazy",
	config = function()
		require("physical-keyboard").setup({
			-- Your configuration here
		})
	end,
}
]]
