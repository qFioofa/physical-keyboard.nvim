-- Mapping mirroring filters and a toggle key.
require("physical-keyboard").setup({
	active_layouts = { "ru" },
	toggle_key = "<leader>tk",
	mappings = {
		exclude = {
			"<Leader>f", -- Telescope picker shortcuts
			"<C%-", -- any Ctrl-- mapping
		},
		extra = {
			["<Leader>zz"] = "<Leader>ZZ",
		},
	},
	cmdline = {
		aliases = { "tabnew", "resize" },
		extra = { ["цц"] = "w" },
	},
})
