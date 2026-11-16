-- Russian only, no OS detection and no layout switching.
require("physical-keyboard").setup({
	active_layouts = { "ru" },
	detect = { enabled = false },
	fallback = "ru",
})
