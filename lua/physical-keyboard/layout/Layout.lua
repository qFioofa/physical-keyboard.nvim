local VimModsModule = require("physical-keyboard.utils.VimMods")
local isValidVimMode = VimModsModule.isValidVimMode
local VimMods = VimModsModule.VimMods

---@class Layout
---@field name string
---@field active boolean
---@field vim_mode string
---@field auto_capital_duplication boolean
---@field layout_name string
---@field map table<string, string>
---@field _on_error fun(msg: string)
local M = {}

M.__index = M

local _default = {
	name = "",
	active = true,
	vim_mode = "n",
	auto_capital_duplication = true,
	layout_name = "qwerty",
	map = {},
	_on_error = function(_) end,
}

function M.new()
	local self = setmetatable({}, M)

	self.name = _default.name
	self.active = _default.active
	self.vim_mode = _default.vim_mode
	self.auto_capital_duplication = _default.auto_capital_duplication
	self.layout_name = _default.layout_name
	self.map = vim.deepcopy(_default.map)
	self._on_error = _default._on_error
	return self
end

---@param active boolean
---@return boolean
function M:setActive(active)
	if type(active) ~= "boolean" then
		self._on_error("[Layout] [setActive] | 'active' field is not a boolean")
		return false
	end

	self.active = active
	return true
end

---@param name string
---@return boolean
function M:setName(name)
	if type(name) ~= "string" then
		self._on_error("[Layout] [setName] | 'name' field is not a string")
		return false
	end

	self.name = name
	return true
end

---@param mode string
---@return boolean
function M:setVimMode(mode)
	if not isValidVimMode(mode) then
		local modes_string = table.concat(VimModsModule.VimMods, " ")

		self._on_error(
			"[Layout] [setVimMode] | wrong vim mode.\nUse one of: "
				.. modes_string
		)
		return false
	end

	self.vim_mode = mode
	return true
end

---@param layout_name string
---@return boolean
function M:setLayoutName(layout_name)
	if type(layout_name) ~= "string" or #layout_name == 0 then
		self._on_error(
			"[Layout] [setLayoutName] | 'layout_name' field is not a non-empty string"
		)
		return false
	end

	self.layout_name = layout_name
	return true
end

---@param active boolean
---@return boolean
function M:setAutoCapical(active)
	if type(active) ~= "boolean" then
		self._on_error(
			"[Layout] [setAutoCapical] | 'active' field is not a boolean"
		)
		return false
	end

	self.auto_capital_duplication = active
	return true
end

---@param func function(string)
---@return boolean
function M:setOnError(func)
	if type(func) ~= "function" then
		self._on_error(
			"[Layout] [setOnError] | 'on_error' field is not a function"
		)
		return false
	end

	self._on_error = func
	return true
end

---@param map table<string, string>
---@return boolean
function M:setMap(map)
	if type(map) ~= "table" then
		self._on_error("[Layout] [setMap] | 'map' argument is not a table")
		return false
	end

	self.map = map
	return true
end

---@return boolean
function M:formMap()
	return true
end

return M
