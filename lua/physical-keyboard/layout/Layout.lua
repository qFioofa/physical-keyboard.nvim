---@class Layout
local M = {
	name = "",
	active = true,
	auto_capital_duplication = true,
	layout_name = "qwerty",
	map = {},
	_on_error = function(_) end,
}

M.__index = M

local _default = {
	name = "",
	active = true,
	auto_capital_duplication = true,
	layout_name = "qwerty",
	map = {},
	_on_error = function(_) end,
}

function M.new()
	local self = setmetatable(_default, M)
	return self
end

---@param active boolean
function M:setActive(active)
	if type(active) ~= "boolean" then
		self._on_error("[Layout] [setActive] | 'active' field is not a boolean")
		return
	end

	self.active = active
end

---@param name string
function M:setName(name)
	if type(name) ~= "string" then
		self._on_error("[Layout] [setName] | 'name' field is not a string")
		return
	end

	self.name = name
end

---@param layout_name string
function M:setLayoutName(layout_name)
	if type(layout_name) ~= "string" or #layout_name == 0 then
		self._on_error(
			"[Layout] [setName] | 'layout_name' field is not a string"
		)
		return
	end

	self.layout_name = layout_name
end

---@param active boolean
function M:setAutoCapical(active)
	if type(active) ~= "boolean" then
		self._on_error(
			"[Layout] [setAutoCapical] | 'active' field is not a boolean"
		)
		return
	end
end

---@param func function(string)
function M:setOnError(func)
	if type(func) ~= "function" then
		self._on_error(
			"[Layout] [setOnError] | 'on_error' field is not a function"
		)
		return
	end

	self._on_error = func
end

---@param map table
function M:setMap(map)
	for char, targetChar in pairs(map) do
		if type(char) ~= "string" and type(targetChar) ~= "string" then
			self._on_error("Map table must contain 'char' = 'char' singature")
			goto continue
		end

		char = char:sub(1, 1)
		targetChar = targetChar:sub(1, 1)

		if self.auto_capital_duplication then
			local charCapital = char.upper(char)
			local targetCharCapital = targetChar.upper(targetChar)

			self.map[charCapital] = targetCharCapital
		end

		self.map[char] = targetChar

		::continue::
	end
end

return M
