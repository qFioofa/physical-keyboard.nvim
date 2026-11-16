if vim.g.loaded_physical_keyboard == 1 then
	return
end
vim.g.loaded_physical_keyboard = 1

require("physical-keyboard")
