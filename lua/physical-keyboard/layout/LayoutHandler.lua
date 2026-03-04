local Layout = require("physical-keyboard.layout.Layout")
local VimMessages = require("physical-keyboard.utils.Message")

---@class LayoutHandler
local M = {
	_notify = true,
	_debug = false,
	_active_plugin = true,
	_active_layouts = {},

	_vimMessageInstance = nil,
}

M.__index = M

local _default = {
	_notify = true,
	_debug = false,
	_active_plugin = true,
	_active_layouts = {},

	_vimMessageInstance = VimMessages.new(),
}

function M.new()
	local self = setmetatable(_default, M)
	return self
end

function M:activePlugin() end

function M:disablePlugin() end

function M:setActiveLayout(layoutName, isActive) end

function M:_cleanLayout() end

---@param layout Layout
function M:registerLayout(layout)
	local newLayout = Layout.new()
end

function M:_isNotify()
	return self._debug == true or self._notify == true
end

function M:enableLayout(layoutName) end

function M:disableLayout(layoutName) end

return M
