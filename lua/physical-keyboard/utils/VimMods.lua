local u = require("physical-keyboard.utils.Utils")

---@enum VimMod
local VimMods = {
	NORMAL = "n",
	VISUAL = "v",
	VISUAL_LINE = "V",
	VISUAL_BLOCK = "\22", -- or "<C-v>"
	SELECT = "s",
	SELECT_LINE = "S",
	SELECT_BLOCK = "\19",
	INSERT = "i",
	OP_PENDING = "o",
	TERMINAL = "t",
	COMMAND = "c",
	EX = "x",
}

---@param mode string|nil
---@return boolean
local function isValidVimMode(mode)
	return u.isInTable(u.tableValues(VimMods), mode)
end

return {
	VimMods = VimMods,
	isValidVimMode = isValidVimMode,
}
