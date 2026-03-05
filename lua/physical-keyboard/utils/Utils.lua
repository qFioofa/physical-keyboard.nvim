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
---@return boolean
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

	return false
end

---@param _table table
---@param _val any
---@return boolean
local function isInTable(_table, _val)
	for _, value in ipairs(_table) do
		if _val == value then
			return true
		end
	end

	return false
end

---@generic K, V
---@param t table<K, V>
---@return V[]
local function tableValues(t)
	local values = {}
	for _, value in pairs(t) do
		table.insert(values, value)
	end
	return values
end

---@generic T
---@param list T[]
---@param i integer? Start index (default: 1)
---@param j integer? End index (default: #list)
---@return ... T Returns multiple values from the table
local function tableUnpack(list, i, j)
	if type(list) ~= "table" then
		return
	end

	i = i or 1
	j = j or #list

	if i > j then
		return
	end

	return list[i], tableUnpack(list, i + 1, j)
end

---@generic T
---@param list T[]
---@param value T
---@return boolean removed Returns true if an element was removed, false otherwise
local function tableEraseFirst(list, value)
	for i = 1, #list do
		if list[i] == value then
			table.remove(list, i)
			return true
		end
	end
	return false
end

---@generic T
---@param original T
---@param copies table?
---@return T
local function deepcopy(original, copies)
	copies = copies or {}

	if type(original) ~= "table" then
		return original
	end

	if copies[original] then
		return copies[original]
	end

	local copy = {}
	copies[original] = copy

	for key, value in pairs(original) do
		copy[deepcopy(key, copies)] = deepcopy(value, copies)
	end

	local mt = getmetatable(original)
	if mt then
		setmetatable(copy, deepcopy(mt, copies))
	end

	return copy
end

return {
	deepcopy = deepcopy,
	tableValues = tableValues,
	isInTable = isInTable,
	tableUnpack = tableUnpack,
	tableEraseFirst = tableEraseFirst,
	toBoolean = toBoolean,
	regCom = registerVimCommand,
	toPhyCharTrans = physicalCharTranslation,
}
