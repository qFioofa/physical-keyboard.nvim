local _c = require("physical-keyboard.Constants")

---@class VimMessage
local M = {
	title = "",
}

M.__index = M

local _default = {
	title = _c.PluginTitle or "",
}

function M.new()
	local self = setmetatable(_default, M)
	return self
end

---@param message any
---@return boolean
function M:is_text(message)
	return type(message) == "string"
end

---@param message string
---@return string
function M:_format_message(message)
	return string.format("[%s] %s", self.title, message)
end

---@param message string
---@param level integer|nil
function M:_notify(message, level)
	level = level or vim.log.levels.INFO
	local formatted_msg = self:_format_message(message)
	vim.notify(formatted_msg, level)
end

---@param message string
function M:i(message)
	if not self:is_text(message) then
		return
	end
	self:_notify(message, vim.log.levels.INFO)
end

---@param message string
function M:d(message)
	if not self:is_text(message) then
		return
	end
	self:_notify(message, vim.log.levels.DEBUG)
end

---@param message string
function M:w(message)
	if not self:is_text(message) then
		return
	end
	self:_notify(message, vim.log.levels.WARN)
end

---@param message string
function M:e(message)
	if not self:is_text(message) then
		return
	end
	self:_notify(message, vim.log.levels.ERROR)
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
