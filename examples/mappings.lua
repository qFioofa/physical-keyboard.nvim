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
	which_key = {
		display = nil, -- hide mirrored entries, keep the original shortcuts
		relative_group = true, -- group mirrors under the translated prefix
		alongside = false, -- or append mirrors to the original label
		separator = "\\",
	},
	cmdline = {
		aliases = { "tabnew", "resize" },
		extra = { ["цц"] = "w" },
	},
})
