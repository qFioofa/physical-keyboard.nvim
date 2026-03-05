local EchoLayoutModule = require("physical-keyboard.layout.EchoKeyboard")
local EchoLayout = EchoLayoutModule.Class
local EchoLayoutMode = EchoLayoutModule.Mode

local LayoutHandler = require("physical-keyboard.layout.LayoutHandler")
local Opts = require("physical-keyboard.Opts")
local defaultLayouts = require("physical-keyboard.const.DefaultLayouts")
local g = require("physical-keyboard.const.Globals")
local u = require("physical-keyboard.utils.Utils")

local M = {}

local GLayoutHandler = LayoutHandler.new(g.VimNotify)
local GEchoLayout = EchoLayout.new(g.VimNotify)

---@return nil
local function registerCommands()
	local commands = {
		-- General commands
		{
			c = "PhyKeyboard",
			f = function() end,
			o = {
				desc = "Show general information about plugin",
				nargs = 0,
			},
		},
		{
			c = "PhyKeyboardStatus",
			f = function(_)
				local registered = GLayoutHandler:getRegistedLayouts()
				local active_map = GLayoutHandler:getActiveLayouts() or {}

				local lines = { "=== Physical Keyboard Status ===" }

				-- Section 1: Active Layouts
				table.insert(lines, "\n[ Active Layouts ]")
				local has_active = false
				for name, is_active in pairs(active_map) do
					if is_active then
						table.insert(lines, string.format("  ✓ %s", name))
						has_active = true
					end
				end
				if not has_active then
					table.insert(lines, "  (none)")
				end

				-- Section 2: All Registered Layouts
				table.insert(lines, "\n[ Registered Layouts ]")
				if #registered == 0 then
					table.insert(lines, "  (none)")
				else
					for _, name in ipairs(registered) do
						local status = active_map[name] and "✓" or "o"
						table.insert(
							lines,
							string.format("  [%s] %s", status, name)
						)
					end
				end

				local message = table.concat(lines, "\n")
				g.VimNotify:i(message)
			end,
			o = {
				desc = "Show state of the plugin",
				nargs = 0,
			},
		},
		{
			c = "PhyKeyboardEnable",
			f = function(_)
				GLayoutHandler:activePlugin()
			end,
			o = {
				desc = "Enables plugin",
				nargs = 0,
			},
		},
		{
			c = "PhyKeyboardDisable",
			f = function()
				GLayoutHandler:disablePlugin()
			end,
			o = {
				desc = "Disables plugin",
				nargs = 0,
			},
		},
		{
			c = "PhyKeyboardEnableLayout",
			f = function(opts)
				local layoutName = opts.fargs and opts.fargs[1]
				GLayoutHandler:enableLayout(layoutName)
			end,
			o = {
				desc = "Enables layout with given name",
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
				desc = "Disables layout with given name",
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
				desc = "Sets 'layout name' into 'active' state",
				nargs = "*",
				complete = function(arg_lead, cmdline, cursor_pos)
					local space_count = 0
					for i = 1, cursor_pos do
						if cmdline:sub(i, i) == " " then
							space_count = space_count + 1
						end
					end

					if space_count == 1 then
						if not GLayoutHandler then
							return {}
						end

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
		}, -- Test section
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
				elseif arg == false then
					GEchoLayout:enable(false)
				else
					-- Toggle if no argument or invalid argument
					GEchoLayout:enable(not GEchoLayout.enabled)
				end
			end,
			o = {
				desc = "Toggle keyboard echo functionality",
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
							"Current mode: " .. tostring(GEchoLayout._mode)
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
				desc = "Set echo display mode (or show current if no args)",
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
	}

	for _, command in ipairs(commands) do
		local success, error = u.regCom(command.c, command.f, command.o)
		if not success then
			g.VimNotify:i(error)
		end
	end
end

---@param ... Layout
local function layoutRegister(...)
	local layouts = { ... }
	for _, layout in ipairs(layouts) do
		GLayoutHandler:registerLayout(layout)
	end
end

---@param opts table
function M.setup(opts)
	local configOpts = Opts.new()
	configOpts:softClone(opts)

	g.VimNotify:enable(configOpts.notify)

	registerCommands()

	local userLayouts = {}
	if type(opts.userLayouts) == table then
		userLayouts = opts.layouts
	end

	layoutRegister(u.tableUnpack(defaultLayouts), u.tableUnpack(userLayouts))
end

return M
