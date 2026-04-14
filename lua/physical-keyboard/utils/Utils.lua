local c = require("physical-keyboard.const.Constants")

--- Creates a deep copy of a table or returns the original value for non-tables.
--- Handles circular references using a copies cache.
---@generic T
---@param original T
---@param copies table? Cache of already copied references (internal use)
---@return T
local function deepcopy(original, copies)
	copies = copies or {}

	if type(original) ~= "table" then
		return original
	end

	-- Handle circular references
	if copies[original] then
		return copies[original]
	end

	local copy = {}
	copies[original] = copy

	for key, value in pairs(original) do
		copy[deepcopy(key, copies)] = deepcopy(value, copies)
	end

	-- Copy metatable
	local mt = getmetatable(original)
	if mt then
		setmetatable(copy, deepcopy(mt, copies))
	end

	return copy
end

--- Converts various input types to a boolean value.
--- Recognizes truthy values: true, 1, "true", "1", "on"
--- Recognizes falsy values: false, 0, "false", "0", "off", nil
---@param input boolean|string|number|any Input value to convert
---@return boolean
local function toBoolean(input)
	local truly = {
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
	}

	for _, value in ipairs(truly) do
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

--- Checks if a value exists in a table (array).
---@param _table table The table to search
---@param _val any The value to find
---@return boolean True if value is found, false otherwise
local function isInTable(_table, _val)
	for _, value in ipairs(_table) do
		if _val == value then
			return true
		end
	end

	return false
end

--- Extracts all values from a table into an array.
---@generic V
---@param t table<any, V>
---@return V[]
local function tableValues(t)
	local values = {}
	for _, value in pairs(t) do
		table.insert(values, value)
	end
	return values
end

--- Deep merges two tables recursively.
---@generic T: table
---@param t1 T
---@param t2 T
---@return T
local function tableMerge(t1, t2)
	if type(t1) ~= "table" or type(t2) ~= "table" then
		return t1
	end

	for k, v in pairs(t2) do
		if type(v) == "table" and type(t1[k]) == "table" then
			t1[k] = tableMerge(t1[k] or {}, v)
		else
			t1[k] = v
		end
	end
	return t1
end

--- Unpacks a range of elements from a table as multiple return values.
---@generic T
---@param list T[]
---@param i integer? Start index (default: 1)
---@param j integer? End index (default: #list)
---@return ... Returns multiple values from the table
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

--- Removes the first occurrence of a value from a table.
---@generic T
---@param list T[]
---@param value T
---@return boolean removed True if an element was removed, false otherwise
local function tableEraseFirst(list, value)
	for i = 1, #list do
		if list[i] == value then
			table.remove(list, i)
			return true
		end
	end
	return false
end

--- Registers a Vim user command with error handling.
---@param name string Command name
---@param command function|string Command function or command string
---@param options table Command options
---@return boolean success True if registration succeeded
---@return string? error_message Error message if registration failed
local function registerVimCommand(name, command, options)
	if type(name) ~= "string" or type(options) ~= "table" then
		return false, "Invalid arguments: 'name' must be a string and 'options' must be a table"
	end

	if type(command) ~= "function" and type(command) ~= "string" then
		return false, "Invalid argument: 'command' must be a function or string"
	end

	vim.api.nvim_create_user_command(name, command, options)
	return true, nil
end

return {
	table = {
		values = tableValues,
		merge = tableMerge,
		unpack = tableUnpack,
		is_in = isInTable,
		erase_first = tableEraseFirst,
	},
	deepcopy = deepcopy,
	toBoolean = toBoolean,
	regCom = registerVimCommand,
}
