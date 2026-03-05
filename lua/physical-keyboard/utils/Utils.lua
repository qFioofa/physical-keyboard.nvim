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
		s = false,
		m = "Can't register vim command: check the types",
	}

	if type(name) ~= "string" or type(options) ~= "table" then
		return error.s, error.m
	end

	if type(command) ~= "function" and type(command) ~= "string" then
		return error.s, error.m
	end

	vim.api.nvim_create_user_command(name, command, options)
	return true, "None"
end

---@param input boolean|string|number|any
---@return boolean|nil
local function toBoolean(input)
	local truely = {
		true,
		1,
		"true",
		"1",
		"on",
	}

	local falsy = {
		false,
		0,
		"false",
		"0",
		"off",
		nil,
	}

	for _, value in ipairs(truely) do
		if value == input then
			return true
		end
	end

	for _, value in ipairs(falsy) do
		if value == input then
			return false
		end
	end

	return nil
end

return {
	toBoolean = toBoolean,
	regCom = registerVimCommand,
	toPhyCharTrans = physicalCharTranslation,
}
