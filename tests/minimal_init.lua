-- Minimal init for manual/pty testing.
-- From the repository root:
--   nvim --clean -n -u tests/minimal_init.lua file.txt
vim.opt.rtp:prepend(vim.fn.getcwd())
require("physical-keyboard").setup({
	notify = false,
	active_layouts = { "ru" },
	detect = { enabled = false },
	fallback = "ru",
})
