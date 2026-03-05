local EchoLayout = require("physical-keyboard.layout.EchoKeyboard")
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
			o = {},
		},
		{
			c = "PhyKeyboardStatus",
			f = function() end,
			o = {},
		},
		{
			c = "PhyKeyboardEnable",
			f = function() end,
			o = {},
		},
		{
			c = "PhyKeyboardDisable",
			f = function() end,
			o = {},
		},
		{
			c = "PhyKeyboardSet",
			f = function(_) end,
			o = {},
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
	}

	for _, command in ipairs(commands) do
		local success, error = u.regCom(command.c, command.f, command.o)
		if not success then
			g.VimNotify:i(error)
		end
	end
end

---@param opts table
function M.setup(opts)
	local configOpts = Opts.new()
	configOpts:softClone(opts)

	g.VimNotify:enable(configOpts.notify)

	registerCommands()

	-- GLayoutHandler.registerLayout()
end

return M
