local Layout = require("physical-keyboard.layout.Layout")
local u = require("physical-keyboard.utils.Utils")

---@class LayoutHandler
---@field _active_plugin boolean
---@field _active_layouts table<string, boolean>
---@field _layouts table<string, Layout>
---@field _layout_list string[]
---@field _vimMessageInstance VimMessage
local M = {}

M.__index = M

local _default = {
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

---@return nil
function M:activePlugin()
	if self._active_plugin then
		return
	end

	self._active_plugin = true
	for _, layoutName in ipairs(self._active_layouts) do
		self:_activateLayout(layoutName)
	end
end

---@return nil
function M:disablePlugin()
	if not self._active_plugin then
		return
	end

	self._active_plugin = false
	for _, layoutName in ipairs(self._active_layouts) do
		self:_cleanLayout(layoutName)
	end
end

---@param layout Layout
---@return boolean
function M:registerLayout(layout)
	local newLayout = Layout.new()
	local name = layout.name

	---Note:
	---1. 'field' must always be non empty string to identify layout
	---2. Why 'layout.`field` ~= nill or newLayout:set`Field`(layout.`field`)' structer
	---We assume that Layout.new() will have other fields relevant
	---   in terms of type of fields.
	---   In other words, it gerentes to not have nil field in
	---   Layout class even if user didn't provided it
	---
	local setVarsTable = {
		name and name ~= "",
		newLayout:setActive(layout.active),
		newLayout:setVimMode(layout.vim_mode),
		newLayout:setLayoutName(layout.layout_name),
		newLayout:setMap(layout.map),

		newLayout:setAutoCapical(layout.auto_capital_duplication),
		newLayout:setOnError(self._on_error),

		-- layout.active ~= nil or newLayout:setActive(layout.active),
		-- layout.vim_mode ~= nil or newLayout:setVimMode(layout.vim_mode),
		-- layout.layout_name ~= nil
		-- 	or newLayout:setLayoutName(layout.layout_name),
		-- layout.map ~= nil or newLayout:setMap(layout.map),
		--
		-- layout.auto_capital_duplication ~= nil
		-- 	or newLayout:setAutoCapical(layout.auto_capital_duplication),
		-- layout._on_error ~= nil or newLayout:setOnError(self._on_error),
	}

	if u.isInTable(setVarsTable, false) then
		pcall(function()
			self._vimMessageInstance:w(
				"[registerLayout] | layout with name: '"
					.. layout.name
					.. "' does not registered.\n"
					.. "Invalid layout fields."
			)
		end)
		return false
	end

	local formedSuccess = newLayout:formMap()
	if not formedSuccess then
		pcall(function()
			self._vimMessageInstance:w(
				"[enableLayout] | layout with name: '"
					.. name
					.. "' does not registered.\n"
					.. "Can't form correct map"
			)
		end)
		return false
	end

	self._layouts[name] = newLayout
	return true
end

---@param layoutName string
---@param isActive boolean
---@return boolean
function M:setActiveLayout(layoutName, isActive)
	if not self:_isLayoutRegisted(layoutName) then
		return false
	end

	if isActive == true then
		if u.isInTable(self._active_layouts, layoutName) then
			self._vimMessageInstance:i(
				"Layout with name '" .. layoutName .. "' already activated"
			)
			return false
		end

		table.insert(self._active_layouts, layoutName)
		self:_activateLayout(layoutName)
		return true
	elseif isActive == false then
		u.tableEraseFirst(self._active_layouts, layoutName)
		self:_cleanLayout(layoutName)
	end

	return false
end

---@param layoutName string
---@return boolean
function M:enableLayout(layoutName)
	return self:setActiveLayout(layoutName, true)
end

---@param layoutName string
---@return boolean
function M:disableLayout(layoutName)
	return self:setActiveLayout(layoutName, false)
end

---@return table<string>|table
function M:getRegistedLayouts()
	return u.deepcopy(self._layout_list)
end

---@return table<string>|table
function M:getActiveLayouts()
	return u.deepcopy(self._active_layouts)
end

---@private
---@param message string
---@return nil
function M:_on_error(message)
	pcall(function()
		self._vimMessageInstance:e(message)
	end)
end

---@private
---@param layoutName string
---@return boolean
function M:_isLayoutRegisted(layoutName)
	if not u.isInTable(self._layout_list, layoutName) then
		pcall(function()
			self._vimMessageInstance:w(
				"[enableLayout] | layout with name: '"
					.. layoutName
					.. "' does not registered"
			)
		end)
		return false
	end
	return true
end

---@private
---@param layoutName string
---@return nil
function M:_cleanLayout(layoutName)
	if not u.isInTable(self._layout_list, layoutName) then
		return
	end
end

---@private
---@param layoutName string
---@return nil
function M:_activateLayout(layoutName)
	if not u.isInTable(self._layout_list, layoutName) then
		return
	end
end

return M
