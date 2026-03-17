local u = require("physical-keyboard.utils.Utils")

--- Vim mode types
---@alias VimMod
---| "n" # Normal mode
---| "v" # Visual mode
---| "s" # Select mode
---| "i" # Insert mode
---| "o" # Operator-pending mode
---| "t" # Terminal mode
---| "c" # Command-line mode
---| "x" # Visual mode (alias for 'v')

--- All valid Vim modes
---@type table<string, VimMod>
local VimMods = {
	NORMAL = "n",
	VISUAL = "v",
	SELECT = "s",
	INSERT = "i",
	OP_PENDING = "o",
	TERMINAL = "t",
	COMMAND = "c",
	EX = "x",
}

--- Checks if a mode string is a valid Vim mode.
---@param mode string|nil The mode to validate
---@return boolean True if valid, false otherwise
local function isValidVimMode(mode)
	if not mode then
		return false
	end
	return u.table.is_in(u.table.values(VimMods), mode)
end

return {
	VimMods = VimMods,
	isValidVimMode = isValidVimMode,
}
