local c = require("physical-keyboard.const.Constants")

--- Must check for <C-...> commands too
---@param char string
local function physicalCharTranslation(char)
	if type(char) ~= "string" then
		return {
			false,
			"'char' must be a string type",
		}
	end

	if #char == 0 then
		return {
			false,
			"'char' must not be empty",
		}
	end

	char = char:sub(1, 1)

	local result = {
		true,
		char = char,
	}

	return result
end

---@param name string
---@param command function|string
---@param options table
local function registerVimCommand(name, command, options)
	local error = {
		false,
		"Can't register vim command: check the types",
	}

	if type(name) ~= "string" or type(options) ~= "table" then
		return error
	end

	if type(command) ~= "function" or type(command) ~= "string" then
		return error
	end

	vim.api.nvim_create_user_command(name, command, options)
	return {
		true,
		"",
	}
end

return {
	regCom = registerVimCommand,
	toPhyCharTrans = physicalCharTranslation,
}
