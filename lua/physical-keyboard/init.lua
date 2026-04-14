local EchoLayoutModule = require("physical-keyboard.layout.EchoKeyboard")
local EchoLayout = EchoLayoutModule.Class
local EchoLayoutMode = EchoLayoutModule.Mode

local LayoutHandler = require("physical-keyboard.layout.LayoutHandler")
local Opts = require("physical-keyboard.Opts")
local defaultLayouts = require("physical-keyboard.const.DefaultLayouts")

local c = require("physical-keyboard.const.Constants")
local g = require("physical-keyboard.const.Globals")
local u = require("physical-keyboard.utils.Utils")

local M = {}

local GLayoutHandler = LayoutHandler.new(g.VimNotify)
local GEchoLayout = EchoLayout.new(g.VimNotify)

--- Registers all plugin commands.
---@return nil
local function registerCommands()
	local commands = {
		-- General commands
		-- Shows info
		{
			c = "PhyKeyboard",
			f = function(_)
				local lines = { "=== Physical Keyboard ===" }

				table.insert(
					lines,
					string.format(
						"Author: %s\nGitHub: %s\nVersion: %s",
						c.PluginAuthor,
						c.PluginGitLink,
						c.Version
					)
				)

				local message = table.concat(lines, "\n")
				g.VimNotify:i(message, "f")
			end,
			o = {
				desc = "Show general information about the plugin",
				nargs = 0,
			},
		},
		{
			c = "PhyKeyboardStatus",
			f = function(_)
				local registered = GLayoutHandler:getRegistedLayouts() or {}
				local active_layouts = GLayoutHandler:getActiveLayouts() or {}

				-- Convert active_layouts array to a set for O(1) lookup
				local active_set = {}
				for _, name in ipairs(active_layouts) do
					active_set[name] = true
				end

				local lines = { "=== Physical Keyboard Status ===" }
				local messageNotifications = "Notifications: "
				if g.VimNotify.enabled == true then
					messageNotifications = messageNotifications .. "enabled"
				else
					messageNotifications = messageNotifications .. "disabled"
				end

				table.insert(lines, messageNotifications)
				if #registered == 0 then
					table.insert(lines, "\nNo layouts registered.")
				else
					table.insert(lines, "")

					local max_num = #registered
					local width = tostring(max_num):len()

					for i, name in ipairs(registered) do
						local is_active = active_set[name] == true
						local status_sym = is_active and "✓" or "○"
						local status_text = is_active and "ACTIVE" or "inactive"

						table.insert(
							lines,
							string.format(
								"  %-" .. width .. "d. [%s] %s (%s)",
								i,
								status_sym,
								name,
								status_text
							)
						)
					end
				end

				local message = table.concat(lines, "\n")
				g.VimNotify:i(message, "f")
			end,
			o = {
				desc = "Show status of registered layouts",
				nargs = 0,
			},
		},
		-- On/off plugin
		{
			c = "PhyKeyboardEnable",
			f = function(_)
				GLayoutHandler:activePlugin()
			end,
			o = {
				desc = "Enable the physical keyboard plugin",
				nargs = 0,
			},
		},
		{
			c = "PhyKeyboardDisable",
			f = function()
				GLayoutHandler:disablePlugin()
			end,
			o = {
				desc = "Disable the physical keyboard plugin",
				nargs = 0,
			},
		},
		-- Layout control
		{
			c = "PhyKeyboardEnableLayout",
			f = function(opts)
				local layoutName = opts.fargs and opts.fargs[1]
				GLayoutHandler:enableLayout(layoutName)
			end,
			o = {
				desc = "Enable a layout by name",
				nargs = 1,
				complete = function(_, _, _)
					return GLayoutHandler:getRegistedLayouts()
				end,
			},
		},
		{
			c = "PhyKeyboardDisableLayout",
			f = function(opts)
				local layoutName = opts.fargs and opts.fargs[1]
				GLayoutHandler:disableLayout(layoutName)
			end,
			o = {
				desc = "Disable a layout by name",
				nargs = 1,
				complete = function(_, _, _)
					return GLayoutHandler:getActiveLayouts()
				end,
			},
		},
		{
			c = "PhyKeyboardSet",
			f = function(opts)
				local layout_name = opts.fargs[1]
				local active = opts.fargs[2]

				if not layout_name or not active or #opts.fargs ~= 2 then
					vim.notify(
						"Usage: :PhyKeyboardSet <layout_name> <true|false>",
						vim.log.levels.ERROR
					)
					return
				end

				local is_active = u.toBoolean(active)

				GLayoutHandler:setActiveLayout(layout_name, is_active)
			end,
			o = {
				desc = "Set a layout's active state",
				nargs = "*",
				complete = function(arg_lead, cmdline, cursor_pos)
					local space_count = 0
					for i = 1, cursor_pos do
						if cmdline:sub(i, i) == " " then
							space_count = space_count + 1
						end
					end

					if space_count == 1 then
						local layouts = GLayoutHandler:getRegistedLayouts()

						local filtered = {}
						for _, name in ipairs(layouts) do
							if name:find(arg_lead, 1, true) == 1 then
								table.insert(filtered, name)
							end
						end
						return filtered
					end

					if space_count >= 2 then
						local booleans = { "true", "false" }
						local filtered = {}
						for _, val in ipairs(booleans) do
							if val:find(arg_lead, 1, true) == 1 then
								table.insert(filtered, val)
							end
						end
						return filtered
					end

					return {}
				end,
			},
		},
		-- Test section
		-- test: char -> translated char
		{
			c = "PhyKeyboardTest",
			f = function(_) end,
			o = {},
		},
		{
			c = "PhyKeyboardEcho",
			f = function(opts)
				local arg = opts.fargs and opts.fargs[1] or nil

				arg = u.toBoolean(arg)
				if arg == true then
					GEchoLayout:enable(true)
				else
					GEchoLayout:enable(false)
				end
			end,
			o = {
				desc = "Toggle keyboard echo display",
				nargs = "?",
				complete = function(_, _, _)
					return { "on", "off" }
				end,
			},
		},
		{
			c = "PhyKeyboardEchoMode",
			f = function(opts)
				local arg = opts.fargs and opts.fargs[1] or nil

				if not arg then
					pcall(function()
						GEchoLayout._vimMessageInstance:i(
							"Current echo mode: " .. tostring(GEchoLayout._mode)
						)
					end)
					return
				end

				local selected_mode = nil
				local search_arg = string.lower(arg)

				for _, mode_value in pairs(EchoLayoutMode) do
					if
						type(mode_value) == "string"
						and string.lower(mode_value) == search_arg
					then
						selected_mode = mode_value
						break
					end
				end

				if selected_mode then
					GEchoLayout:set_mode(selected_mode)
				else
					pcall(function()
						GEchoLayout._vimMessageInstance:w(
							"Invalid mode: '" .. arg .. "'"
						)
					end)
				end
			end,
			o = {
				desc = "Set or show echo display mode",
				nargs = "?",
				complete = function(_, _, _)
					local modes = {}
					for _, mode_value in pairs(EchoLayoutMode) do
						if type(mode_value) == "string" then
							table.insert(modes, mode_value)
						end
					end
					return modes
				end,
			},
		},
		{
			c = "PhyKeyboardNotify",
			f = function(opts)
				local arg = opts.fargs and opts.fargs[1] or nil

				local message = "Notifications: "
				arg = u.toBoolean(arg)
				if arg == true then
					g.VimNotify.enabled = true
				elseif arg == false then
					g.VimNotify.enabled = false
				else
					g.VimNotify.enabled = not g.VimNotify.enabled
				end

				if g.VimNotify.enabled == true then
					message = message .. "enabled"
				else
					message = message .. "disabled"
				end

				g.VimNotify:i(message, "f")
			end,
			o = {
				desc = "Toggle plugin notifications",
				nargs = "?",
				complete = function(_, _, _)
					return { "on", "off" }
				end,
			},
		},
	}

	for _, command in ipairs(commands) do
		local success, error = u.regCom(command.c, command.f, command.o)
		if not success then
			g.VimNotify:e("Failed to register command '" .. command.c .. "': " .. error)
		end
	end
end

--- Registers layouts with the layout handler.
---@param ... Layout Variadic list of layout objects to register
---@return nil
local function layoutRegister(...)
	local layouts = { ... }
	for _, layout in ipairs(layouts) do
		GLayoutHandler:registerLayout(layout)
	end
end

--- Initializes the plugin with user configuration.
---@param opts table User configuration options
---@return nil
function M.setup(opts)
	local configOpts = Opts.new()
	configOpts:softClone(opts)

	g.VimNotify:enable(configOpts.notify)

	registerCommands()

	local userLayouts = {}
	if type(opts.userLayouts) == "table" then
		userLayouts = opts.userLayouts
	end

	-- Convert userLayouts table to array for registration
	local userLayoutsArray = {}
	for _, layout in pairs(userLayouts) do
		table.insert(userLayoutsArray, layout)
	end

	layoutRegister(u.table.unpack(defaultLayouts), u.table.unpack(userLayoutsArray))

	if type(configOpts.active_layouts) == "string" then
		GLayoutHandler:enableLayout(configOpts.active_layouts)
	elseif type(configOpts.active_layouts) == "table" then
		for _, layoutName in ipairs(configOpts.active_layouts) do
			GLayoutHandler:enableLayout(layoutName)
		end
	end
end

return M
