local c = require("physical-keyboard.const.Constants")

---@enum NotifyLvl
local NotifyLvl = {
	REGULER = "r",
	FORCE = "f",
}

---@class VimMessage
---@field enabled boolean
---@field _notify_lvl table<string, function>
---@field title string
local M = {}

M.__index = M

local _default = {
	enabled = true,
	title = c.PluginTitle or "",
}

function M.new()
	local self = setmetatable({}, M)
	self.enabled = _default.enabled
	self.title = _default.title
	self._notify_lvl = {
		["r"] = function(...)
			self:_notify(...)
		end,
		["f"] = function(...)
			self:_notify_force(...)
		end,
	}
	return self
end

---@param message any
---@return boolean
function M:is_text(message)
	return type(message) == "string"
end

---@param enable boolean|any
function M:enable(enable)
	if type(enable) ~= "boolean" then
		enable = _default.enabled
	end

	self.enabled = enable
end

---@private
---@param message string
---@return string
function M:_format_message(message)
	return string.format("\n [ %s ] \n%s", self.title, message)
end

---@param message string
---@param level integer|nil
function M:_notify(message, level)
	if not self.enabled then
		return
	end
	self:_notify_force(message, level)
end

---@param message string
---@param level integer|nil
function M:_notify_force(message, level)
	level = level or vim.log.levels.INFO
	local formatted_msg = self:_format_message(message)
	vim.notify(formatted_msg, level)
end

---@param message string
---@param level NotifyLvl?
function M:i(message, level)
	level = level or NotifyLvl.REGULER
	if not self:is_text(message) then
		return
	end
	pcall(function()
		self._notify_lvl[level](message, vim.log.levels.INFO)
	end)
end

---@param message string
---@param level NotifyLvl?
function M:d(message, level)
	level = level or NotifyLvl.REGULER
	if not self:is_text(message) then
		return
	end
	pcall(function()
		self._notify_lvl[level](message, vim.log.levels.INFO)
	end)
end

---@param message string
---@param level NotifyLvl?
function M:w(message, level)
	level = level or NotifyLvl.REGULER
	if not self:is_text(message) then
		return
	end
	pcall(function()
		self._notify_lvl[level](message, vim.log.levels.INFO)
	end)
end

---@param message string
---@param level NotifyLvl?
function M:e(message, level)
	level = level or NotifyLvl.REGULER
	if not self:is_text(message) then
		return
	end
	pcall(function()
		self._notify_lvl[level](message, vim.log.levels.INFO)
	end)
end

---@param message string
---@param hl string|nil
function M:echo(message, hl)
	if not self:is_text(message) then
		return
	end
	hl = hl or "None"
	vim.api.nvim_echo({ { self:_format_message(message), hl } }, true, {})
end

return M
