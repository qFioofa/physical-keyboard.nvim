local Layout = require("physical-keyboard.layout.Layout")

---@class LayoutHandler
local M = {}

M.__index = M

local _default = {
	_notify = true,
	_debug = false,
	_active_plugin = true,
	_active_layouts = {},
	_layouts = {},
	_layout_list = {},

	_vimMessageInstance = nil,
}

---@param vimMessageInstance VimMessage
function M.new(vimMessageInstance)
	local self = setmetatable(_default, M)
	self._vimMessageInstance = vimMessageInstance
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
