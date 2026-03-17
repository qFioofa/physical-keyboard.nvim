local c = require("physical-keyboard.const.Constants")

--- Notification level
---@alias NotifyLvl
---| "r" # Regular notification (respects enabled setting)
---| "f" # Force notification (ignores enabled setting)

--- VimMessage provides a wrapper around vim.notify with formatting and enable/disable control.
---@class VimMessage
---@field enabled boolean Whether notifications are enabled
---@field private _notify_lvl table<string, fun(message: string, level: integer?)> Notification level functions
---@field title string Title to display in notifications
local M = {}

M.__index = M

local _default = {
	enabled = true,
	title = c.PluginTitle or "",
}

--- Creates a new VimMessage instance.
---@return VimMessage
function M.new()
	local self = setmetatable({}, M)
	self.enabled = _default.enabled
	self.title = _default.title
	self._notify_lvl = {
		["r"] = function(message, level)
			self:_notify(message, level)
		end,
		["f"] = function(message, level)
			self:_notify_force(message, level)
		end,
	}
	return self
end

--- Checks if a message is valid text.
---@param message any The message to validate
---@return boolean True if message is a string, false otherwise
function M:is_text(message)
	return type(message) == "string"
end

--- Enables or disables notifications.
---@param enable boolean|any If boolean, sets the state; otherwise uses default
function M:enable(enable)
	if type(enable) ~= "boolean" then
		enable = _default.enabled
	end

	self.enabled = enable
end

--- Formats a message with the plugin title.
---@private
---@param message string The message to format
---@return string Formatted message
function M:_format_message(message)
	return string.format("\n⌨ [ %s ] ⌨ \n%s", self.title, message)
end

--- Internal notification function that respects the enabled setting.
---@private
---@param message string The message to notify
---@param level integer? The log level
function M:_notify(message, level)
	if not self.enabled then
		return
	end
	self:_notify_force(message, level)
end

--- Internal notification function that always displays the message.
---@private
---@param message string The message to notify
---@param level integer? The log level
function M:_notify_force(message, level)
	level = level or vim.log.levels.INFO
	local formatted_msg = self:_format_message(message)
	vim.notify(formatted_msg, level)
end

--- Displays an informational message.
---@param message string The message to display
---@param level NotifyLvl? The notification level (default: "r")
function M:i(message, level)
	level = level or "r"
	if not self:is_text(message) then
		return
	end
	pcall(function()
		self._notify_lvl[level](message, vim.log.levels.INFO)
	end)
end

--- Displays a debug message.
---@param message string The message to display
---@param level NotifyLvl? The notification level (default: "r")
function M:d(message, level)
	level = level or "r"
	if not self:is_text(message) then
		return
	end
	pcall(function()
		self._notify_lvl[level](message, vim.log.levels.DEBUG)
	end)
end

--- Displays a warning message.
---@param message string The message to display
---@param level NotifyLvl? The notification level (default: "r")
function M:w(message, level)
	level = level or "r"
	if not self:is_text(message) then
		return
	end
	pcall(function()
		self._notify_lvl[level](message, vim.log.levels.WARN)
	end)
end

--- Displays an error message.
---@param message string The message to display
---@param level NotifyLvl? The notification level (default: "r")
function M:e(message, level)
	level = level or "r"
	if not self:is_text(message) then
		return
	end
	pcall(function()
		self._notify_lvl[level](message, vim.log.levels.ERROR)
	end)
end

--- Displays a message in the command-line area.
---@param message string The message to display
---@param hl string? Highlight group name (default: "None")
function M:echo(message, hl)
	if not self:is_text(message) then
		return
	end
	hl = hl or "None"
	vim.api.nvim_echo({ { self:_format_message(message), hl } }, true, {})
end

return M
