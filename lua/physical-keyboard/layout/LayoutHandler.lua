local Layout = require("physical-keyboard.layout.Layout")
local u = require("physical-keyboard.utils.Utils")

--- LayoutHandler manages the registration, activation, and deactivation of keyboard layouts.
--- It handles the creation and removal of Vim keymaps for each active layout.
---@class LayoutHandler
---@field private _active_plugin boolean Whether the plugin is currently active
---@field private _active_layouts string[] List of currently active layout names
---@field private _active_layouts_plugin_save string[] Saved active layouts when plugin is disabled
---@field private _layouts table<string, Layout> Map of layout name to Layout object
---@field private _layout_list string[] List of registered layout names
---@field private _vimMessageInstance VimMessage Instance for displaying messages
local M = {}

M.__index = M

---@class LayoutHandlerDefault
---@field _active_plugin boolean
---@field _active_layouts string[]
---@field _active_layouts_plugin_save string[]
---@field _layouts table
---@field _layout_list string[]
---@field _vimMessageInstance nil
local _default = {
	_active_plugin = true,
	_active_layouts = {},
	_active_layouts_plugin_save = {},
	_layouts = {},
	_layout_list = {},

	_vimMessageInstance = nil,
}

--- Creates a new LayoutHandler instance.
---@param vimMessageInstance VimMessage Instance for displaying messages
---@return LayoutHandler
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

--- Enables the physical keyboard plugin and restores previously active layouts.
---@return nil
function M:activePlugin()
	if self._active_plugin == true then
		pcall(function()
			self._vimMessageInstance:i("Physical Keyboard: Already enabled")
		end)
		return
	end

	pcall(function()
		self._vimMessageInstance:i("Physical Keyboard: Enabled")
	end)

	self._active_plugin = true
	for _, layoutName in ipairs(self._active_layouts_plugin_save) do
		self:_activateLayout(layoutName)
	end
end

--- Disables the physical keyboard plugin and saves active layouts for restoration.
---@return nil
function M:disablePlugin()
	if self._active_plugin == false then
		pcall(function()
			self._vimMessageInstance:i("Physical Keyboard: Already disabled")
		end)
		return
	end

	pcall(function()
		self._vimMessageInstance:i("Physical Keyboard: Disabled")
	end)

	self._active_plugin = false
	local _save_active_layouts = u.deepcopy(self._active_layouts)
	for _, layoutName in ipairs(_save_active_layouts) do
		self:_cleanLayout(layoutName)
	end
	self._active_layouts_plugin_save = _save_active_layouts
end

--- Checks if the plugin is currently enabled.
---@private
---@return boolean True if enabled, false otherwise
function M:_isEnable()
	if self._active_plugin == false then
		pcall(function()
			self._vimMessageInstance:e(
				"Plugin is disabled. Enable it with :PhyKeyboardEnable"
			)
		end)
		return false
	end

	return true
end

--- Registers a new keyboard layout.
---@param layout Layout The layout object to register
---@return boolean True if registration succeeded, false otherwise
function M:registerLayout(layout)
	if not self:_isEnable() then
		return false
	end

	if not layout or type(layout) ~= "table" then
		self:_on_error("Invalid layout object provided")
		return false
	end

	local newLayout = Layout.new()
	local name = layout.name

	-- Validate required fields
	if not name or name == "" then
		self:_on_error("Layout must have a non-empty 'name' field")
		return false
	end

	--- Validation checklist for layout fields
	local validationChecks = {
		{ check = newLayout:setName(name), field = "name" },
		{ check = newLayout:setActive(layout.active), field = "active" },
		{ check = newLayout:setVimMode(layout.vim_mode), field = "vim_mode" },
		{ check = newLayout:setLayoutName(layout.layout_name), field = "layout_name" },
		{ check = newLayout:setFormMapOptions(layout.form_map_options), field = "form_map_options" },
		{ check = newLayout:setMap(layout.map), field = "map" },
		{ check = newLayout:setOnError(function(msg) self:_on_error(msg) end), field = "on_error" },
	}

	-- Check if all validations passed
	for _, validation in ipairs(validationChecks) do
		if not validation.check then
			self:_on_error(
				string.format(
					"Layout '%s' failed validation on field '%s'",
					tostring(name),
					tostring(validation.field)
				)
			)
			return false
		end
	end

	local formedSuccess = newLayout:formMap()
	if not formedSuccess then
		self:_on_error(
			string.format(
				"Layout '%s' failed to build mapping table",
				tostring(name)
			)
		)
		return false
	end

	self._layouts[name] = newLayout
	table.insert(self._layout_list, name)
	return true
end

--- Sets the active state of a layout.
---@param layoutName string Name of the layout
---@param isActive boolean Whether to activate or deactivate the layout
---@return boolean True if operation succeeded, false otherwise
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
				string.format("Layout '%s' is already active", layoutName)
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

--- Enables a layout by name.
---@param layoutName string Name of the layout to enable
---@return boolean True if operation succeeded, false otherwise
function M:enableLayout(layoutName)
	return self:setActiveLayout(layoutName, true)
end

--- Disables a layout by name.
---@param layoutName string Name of the layout to disable
---@return boolean True if operation succeeded, false otherwise
function M:disableLayout(layoutName)
	return self:setActiveLayout(layoutName, false)
end

--- Gets all registered layout names.
---@return string[] List of registered layout names
function M:getRegistedLayouts()
	return u.deepcopy(self._layout_list)
end

--- Gets all active layout names.
---@return string[] List of active layout names
function M:getActiveLayouts()
	return u.deepcopy(self._active_layouts)
end

--- Displays an error message.
---@private
---@param message string The error message to display
---@return nil
function M:_on_error(message)
	pcall(function()
		self._vimMessageInstance:e(message)
	end)
end

--- Checks if a layout is registered.
---@private
---@param layoutName string Name of the layout to check
---@return boolean True if registered, false otherwise
function M:_isLayoutRegisted(layoutName)
	if not u.table.is_in(self._layout_list, layoutName) then
		pcall(function()
			self._vimMessageInstance:w(
				string.format("Layout '%s' is not registered", layoutName)
			)
		end)
		return false
	end
	return true
end

--- Activates a layout by creating its keymaps.
---@private
---@param layoutName string Name of the layout to activate
---@return boolean True if activation succeeded, false otherwise
function M:_activateLayout(layoutName)
	if not u.table.is_in(self._layout_list, layoutName) then
		self:_on_error(string.format("Layout '%s' not found in registered layouts", layoutName))
		return false
	end

	local layout = self._layouts[layoutName]
	if not layout then
		self:_on_error(string.format("Layout object not found for '%s'", layoutName))
		return false
	end

	if not layout.active then
		self:_on_error(string.format("Layout '%s' is marked as inactive", layoutName))
		return false
	end

	local ns_id = vim.api.nvim_create_namespace("LayoutMappings_" .. layoutName)
	layout:setNsIdMappings(ns_id)

	-- Clear any previously registered mappings from a previous activation
	layout._registered_mappings = {}
	local mapping_counter = 0

	-- Check if EXCLUDE_INSERT option is set
	local exclude_insert = false
	-- Check if AUTO_LEADER_MAPPINGS option is set
	local has_leader_mappings = false
	-- Check if AUTO_EXISTING_MAPPINGS option is set
	local has_existing_mappings = false

	if layout.form_map_options then
		local opts = layout.form_map_options
		if type(opts) == "string" then
			if opts == "exclude_insert" then
				exclude_insert = true
			elseif opts == "auto_leader_mappings" then
				has_leader_mappings = true
			elseif opts == "auto_existing_mappings" then
				has_existing_mappings = true
			end
		elseif type(opts) == "table" then
			for _, opt in ipairs(opts) do
				if opt == "exclude_insert" or opt == "auto_insert_normal_duplicate" then
					exclude_insert = true
				elseif opt == "auto_leader_mappings" then
					has_leader_mappings = true
				elseif opt == "auto_existing_mappings" then
					has_existing_mappings = true
				end
			end
		end
	end

	-- Also check the layout.map for exclude_insert marker (in case it was added via formMap)
	if exclude_insert == false and layout.map then
		for key, _ in pairs(layout.map) do
			if key == "_EXCLUDE_INSERT_MARKER_" then
				exclude_insert = true
				break
			end
		end
	end

	-- Filter vim modes if EXCLUDE_INSERT is set
	local modes_to_use = layout.vim_mode
	if exclude_insert then
		modes_to_use = {}
		for _, mode in ipairs(layout.vim_mode) do
			if mode ~= "i" then
				table.insert(modes_to_use, mode)
			end
		end
	end

	local mappingsCreated = 0

	-- Create basic character mappings
	for original_char, translated_char in pairs(layout.map) do
		-- Skip marker keys
		if
			type(original_char) == "string"
			and type(translated_char) == "string"
			and original_char ~= "_LEADER_MAPPING_MARKER_"
			and original_char ~= "_EXISTING_MAPPING_MARKER_"
			and original_char ~= "_EXCLUDE_INSERT_MARKER_"
		then
			for _, vim_mode in ipairs(modes_to_use) do
				local success, err = pcall(function()
					vim.api.nvim_buf_set_keymap(
						-1,
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
				end)

				if success then
					mappingsCreated = mappingsCreated + 1
					mapping_counter = mapping_counter + 1
					-- Save the registered mapping to layout for later removal
					layout._registered_mappings[mapping_counter] = {
						mode = vim_mode,
						lhs = original_char,
						bufnr = -1,
					}
				else
					self:_on_error(
						string.format(
							"Failed to create mapping '%s' → '%s' in mode '%s': %s",
							original_char,
							translated_char,
							vim_mode,
							tostring(err)
						)
					)
				end
			end
		end
	end

	-- Process leader key mappings if option is enabled
	if has_leader_mappings or has_existing_mappings then
		local leader_mappings_created = self:_translateLeaderMappings(
			layoutName,
			layout,
			modes_to_use,
			ns_id,
			has_leader_mappings,
			has_existing_mappings
		)
		mappingsCreated = mappingsCreated + leader_mappings_created
	end

	self._vimMessageInstance:i(
		string.format(
			"Layout '%s' activated with %d mappings",
			layoutName,
			mappingsCreated
		)
	)

	return true
end

--- Translates existing leader key mappings to use physical layout characters.
--- This function scans for existing mappings that use the leader key and creates
--- translated versions using the character map from the layout.
---
--- How it works:
--- 1. Gets the current leader key (default is '\')
--- 2. Scans all existing mappings in the specified modes
--- 3. For each mapping that starts with the leader key, creates a translated version
---    using the physical layout characters
---
--- Example:
--- - Original mapping: `<leader>yy` → `%y` (yank paragraph)
--- - With map['н'] = 'n', creates: `<leader>нн` → `%y`
---
--- LIMITATIONS:
--- - Must be called AFTER other plugins have set up their mappings
--- - Only works with mappings that use the standard leader key format
--- - Does not handle recursive mappings (noremap=false mappings)
--- - May create duplicate mappings if called multiple times
--- - Performance impact: scans all existing mappings which can be slow with many plugins
---
---@private
---@param layoutName string Name of the layout being activated
---@param layout Layout Layout object to register mappings on
---@param modes_to_use table<string> List of vim modes to process (e.g., {"n", "v", "o"})
---@param _ns_id number Namespace ID for the mappings
---@param has_leader_mappings boolean Whether to process only leader mappings
---@param has_existing_mappings boolean Whether to process all existing mappings
---@return number Number of leader mappings created
function M:_translateLeaderMappings(layoutName, layout, modes_to_use, _ns_id, has_leader_mappings, has_existing_mappings)
	local mappingsCreated = 0

	-- Get the leader key (default is '\')
	local leader = vim.g.mapleader or "\\"
	if leader == "" then
		leader = "\\"
	end

	-- Normalize leader key: handle special keys like <Space>
	-- When mapleader is set to '<Space>', vim.g.mapleader contains the literal string '<Space>'
	-- But in actual mappings, it's represented as ' ' (space character)
	local normalizedLeader = leader
	if leader == "<Space>" then
		normalizedLeader = " "
	elseif leader:match("^<.+>$") then
		-- Handle other special keys if needed
		-- For most cases, we use the literal character
		normalizedLeader = leader
	end

	-- Create reverse map (english -> physical) for translation
	local reverseMap = {}
	for phys, en in pairs(layout.map) do
		if type(phys) == "string" and type(en) == "string" then
			-- Skip marker keys
			if phys ~= "_LEADER_MAPPING_MARKER_" and phys ~= "_EXISTING_MAPPING_MARKER_" then
				reverseMap[en] = phys
			end
		end
	end

	-- Function to translate a key sequence using the reverse map
	-- Preserves the leader key prefix and only translates characters after it
	local function translateKeySequence(sequence)
		local result = ""
		local i = 1

		-- Check if sequence starts with leader key and preserve it
		local leaderPrefix = ""
		if normalizedLeader ~= "" and sequence:sub(1, #normalizedLeader) == normalizedLeader then
			leaderPrefix = normalizedLeader
			i = #normalizedLeader + 1
		end

		while i <= #sequence do
			-- Check for special key patterns like <C-x>, <S-x>, etc.
			if sequence:sub(i, i) == "<" then
				local endBracket = sequence:find(">", i)
				if endBracket then
					result = result .. sequence:sub(i, endBracket)
					i = endBracket + 1
				else
					result = result .. sequence:sub(i, i)
					i = i + 1
				end
			else
				local char = sequence:sub(i, i)
				-- Try to find the character in reverse map
				local translated = reverseMap[char]
				if translated then
					result = result .. translated
				else
					result = result .. char
				end
				i = i + 1
			end
		end

		-- Prepend the leader key prefix
		return leaderPrefix .. result
	end

	-- Process each mode
	for _, mode in ipairs(modes_to_use) do
		-- Get all mappings for this mode
		local mappings = vim.api.nvim_buf_get_keymap(0, mode)

		for _, mapping in ipairs(mappings) do
			local lhs = mapping.lhs
			local rhs = mapping.rhs or ""
			local callback = mapping.callback

			-- Skip our own mappings
			if mapping.desc and mapping.desc:find("PKB_Translation_") then
				goto continue
			end

			-- Check if this is a leader mapping or if we're processing all mappings
			-- Use normalizedLeader for consistent detection
			local isLeaderMapping = lhs and lhs:find(normalizedLeader, 1, true) == 1
			local shouldProcess = (has_leader_mappings and isLeaderMapping) or
			                      (has_existing_mappings and not isLeaderMapping) or
			                      (has_leader_mappings and has_existing_mappings)

			if shouldProcess and lhs and #lhs > 0 then
				-- Translate the lhs using the reverse map
				local translatedLhs = translateKeySequence(lhs)

				-- Skip if translation didn't change anything
				if translatedLhs ~= lhs then
					-- Create the translated mapping
					local success, err = pcall(function()
						local mapOpts = {
							noremap = mapping.noremap,
							silent = mapping.silent or false,
							nowait = mapping.nowait or false,
							expr = mapping.expr or false,
							unique = false,
							desc = "PKB_Leader_" .. layoutName,
						}

						if callback then
							mapOpts.callback = callback
						else
							-- For rhs, we keep it the same (it's the command to execute)
							vim.api.nvim_buf_set_keymap(0, mode, translatedLhs, rhs, mapOpts)
							return
						end

						vim.api.nvim_buf_set_keymap(0, mode, translatedLhs, "", mapOpts)
					end)

					if success then
						mappingsCreated = mappingsCreated + 1
						-- Save the registered leader mapping to layout for later removal
						local counter = #layout._registered_mappings + 1
						layout._registered_mappings[counter] = {
							mode = mode,
							lhs = translatedLhs,
							bufnr = 0,
						}
					else
						self:_on_error(
							string.format(
								"Failed to create leader mapping '%s' → '%s' in mode '%s': %s",
								translatedLhs,
								rhs,
								mode,
								tostring(err)
							)
						)
					end
				end
			end

			::continue::
		end
	end

	return mappingsCreated
end

--- Deactivates a layout by removing its keymaps.
---@private
---@param layoutName string Name of the layout to deactivate
---@return boolean True if deactivation succeeded, false otherwise
function M:_cleanLayout(layoutName)
	if not u.table.is_in(self._layout_list, layoutName) then
		self:_on_error(string.format("Layout '%s' not found in registered layouts", layoutName))
		return false
	end

	local layout = self._layouts[layoutName]
	if not layout then
		self:_on_error(string.format("Layout object not found for '%s'", layoutName))
		return false
	end

	local mappingsRemoved = 0

	-- Remove all registered mappings using the exact mode, lhs, and bufnr they were created with
	for _, mapping_info in ipairs(layout._registered_mappings) do
		local success = pcall(function()
			vim.api.nvim_buf_del_keymap(mapping_info.bufnr, mapping_info.mode, mapping_info.lhs)
		end)

		if success then
			mappingsRemoved = mappingsRemoved + 1
		end
	end

	-- Clear the registered mappings table
	layout._registered_mappings = {}
	layout:setNsIdMappings(nil)

	self._vimMessageInstance:i(
		string.format(
			"Layout '%s' deactivated, %d mappings removed",
			layoutName,
			mappingsRemoved
		)
	)

	return true
end

return M
