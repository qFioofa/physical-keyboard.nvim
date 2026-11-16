-- Several national layouts with automatic detection.
require("physical-keyboard").setup({
	active_layouts = { "ru", "de", "fr" },
	fallback = "unique",
	detect = { enabled = true },
})
