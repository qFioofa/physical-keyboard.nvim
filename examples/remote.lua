-- Remote Neovim over SSH: detection is disabled automatically, so the
-- client-side layout cannot be detected. Pick the layout explicitly.
require("physical-keyboard").setup({
	active_layouts = { "ru" },
	detect = { remote = "auto" },
	fallback = "ru",
})
