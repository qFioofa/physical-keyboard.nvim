local Layout = require("physical-keyboard.layout.Layout")
local u = require("physical-keyboard.utils.Utils")

---@class LayoutHandler
---@field _active_plugin boolean
---@field _active_layouts table<string>
---@field _active_layouts_plugin_save table<string>
---@field _layouts table<string, Layout>
---@field _layout_list string[]
---@field _vimMessageInstance VimMessage
local M = {}

M.__index = M

local _default = {
	_active_plugin = true,
	_active_layouts = {},
	_active_layouts_plugin_save = {},
	_layouts = {},
	_layout_list = {},

	_vimMessageInstance = nil,
}

---@param vimMessageInstance VimMessage
function M.new(vimMessageInstance)
	local self = setmetatable({}, M)
	self._active_plugin = _default._active_plugin
	self._active_layouts = _default._active_layouts
	self._active_layouts_plugin_save = _default._active_layouts_plugin_save
	self._layouts = _default._layouts
	self._layout_list = _default._layout_list
	self._vimMessageInstance = vimMessageInstance
	return self
end

---@return nil
function M:activePlugin()
	if self._active_plugin == true then
		pcall(function()
			self._vimMessageInstance:i("Plugin: already enabled")
		end)
		return
	end

	pcall(function()
		self._vimMessageInstance:i("Plugin: enabled")
	end)

	self._active_plugin = true
	for _, layoutName in ipairs(self._active_layouts_plugin_save) do
		self:_activateLayout(layoutName)
	end
end

---@return nil
function M:disablePlugin()
	if self._active_plugin == false then
		pcall(function()
			self._vimMessageInstance:i("Plugin: already disabled")
		end)
		return
	end

	pcall(function()
		self._vimMessageInstance:i("Plugin: disabled")
	end)

	self._active_plugin = false
	local _save_active_layouts = u.deepcopy(self._active_layouts)
	for _, layoutName in ipairs(_save_active_layouts) do
		self:_cleanLayout(layoutName)
	end
	self._active_layouts_plugin_save = _save_active_layouts
end

---@private
---@return boolean
function M:_isEnable()
	if self._active_plugin == false then
		pcall(function()
			self._vimMessageInstance:i(
				"Can't set layout status\nPlugin is disabled\nUse: <PhyKeyboardEnable> to enable it"
			)
		end)
		return false
	end

	return true
end

---@param layout Layout
---@return boolean
function M:registerLayout(layout)
	if not self:_isEnable() then
		return false
	end

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
		newLayout:setName(name),
		newLayout:setActive(layout.active),
		newLayout:setVimMode(layout.vim_mode),
		newLayout:setLayoutName(layout.layout_name),
		newLayout:setFormMapOptions(layout.form_map_options),
		newLayout:setMap(layout.map),

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

	if u.table.is_in(setVarsTable, false) then
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
	table.insert(self._layout_list, name)
	return true
end

---@param layoutName string
---@param isActive boolean
---@return boolean
function M:setActiveLayout(layoutName, isActive)
	if not self:_isEnable() then
		return false
	end

	if not self:_isLayoutRegisted(layoutName) then
		return false
	end

	if isActive == true then
		if u.table.is_in(self._active_layouts, layoutName) then
			self._vimMessageInstance:i(
				"Layout with name '" .. layoutName .. "' already activated"
			)
			return false
		end

		if not self:_activateLayout(layoutName) then
			return false
		end

		table.insert(self._active_layouts, layoutName)
		return true
	elseif isActive == false then
		if not self:_cleanLayout(layoutName) then
			return false
		end

		u.table.erase_first(self._active_layouts, layoutName)
		return true
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
	if not u.table.is_in(self._layout_list, layoutName) then
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

function M:_activateLayout(layoutName)
	if not u.table.is_in(self._layout_list, layoutName) then
		return false
	end

	local layout = self._layouts[layoutName]
	if not layout then
		return false
	end

	if not layout.active then
		return false
	end

	local ns_id = vim.api.nvim_create_namespace("LayoutMappings_" .. layoutName)
	layout:setNsIdMappings(ns_id)

	for original_char, translated_char in pairs(layout.map) do
		if
			type(original_char) == "string"
			and type(translated_char) == "string"
		then
			for _, vim_mode in pairs(layout.vim_mode) do
				vim.api.nvim_buf_set_keymap(
					0,
					vim_mode,
					original_char,
					translated_char,
					{
						noremap = false,
						silent = true,
						nowait = false,
						expr = false,
						unique = false,
						desc = "PKB_Translation_" .. layoutName,
					}
				)
			end
		end
	end

	pcall(function()
		self._vimMessageInstance:i(
			"✓ Layout: " .. layoutName .. " mappings created and activated"
		)
	end)

	return true
end

function M:_cleanLayout(layoutName)
	if not u.table.is_in(self._layout_list, layoutName) then
		return false
	end

	local layout = self._layouts[layoutName]
	if not layout then
		self:_on_error("Layout object not found during cleanup: " .. layoutName)
		return false
	end

	local ns_id = layout:getNsIdMappings()

	if ns_id then
		for original_char, _ in pairs(layout.map) do
			if type(original_char) == "string" then
				pcall(function()
					for _, vim_mode in ipairs(layout.vim_mode) do
						vim.keymap.del(
							vim_mode,
							original_char,
							{ buffer = 0, nsid = ns_id }
						)
					end
				end)
			end
		end
		layout:setNsIdMappings(nil)
	end

	pcall(function()
		self._vimMessageInstance:i(
			"✓ Layout: " .. layoutName .. " mappings removed and deactivated"
		)
	end)

	return true
end

return M
