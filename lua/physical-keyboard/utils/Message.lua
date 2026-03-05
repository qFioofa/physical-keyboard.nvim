local c = require("physical-keyboard.const.Constants")

---@class VimMessage
---@field enabled boolean
---@field title string
local M = {}

M.__index = M

local _default = {
	enabled = true,
	title = c.PluginTitle or "",
}

function M.new()
	local self = setmetatable({}, M)
	for k, v in pairs(_default) do
		self[k] = v
	end
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

---@private
---@param message string
---@param level integer|nil
function M:_notify(message, level)
	if not self.enabled then
		return
	end

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
