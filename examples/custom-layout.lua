-- Add a layout that is not bundled. `map` is English -> native.
require("physical-keyboard").setup({
	active_layouts = { "my" },
	userLayouts = {
		my = {
			title = "My layout",
			names = { "my", "My Layout" },
			map = {
				["q"] = "й",
				["w"] = "ц",
				["e"] = "у",
				["r"] = "к",
			},
		},
	},
})
