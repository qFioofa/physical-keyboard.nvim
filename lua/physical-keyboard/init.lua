local LayoutHandler = require("physical-keyboard.layout.LayoutHandler")
local Opts = require("physical-keyboard.Opts")
local defaultLayouts = require("physical-keyboard.const.DefaultLayouts")
local g = require("physical-keyboard.const.Globals")
local u = require("physical-keyboard.utils.Utils")

local M = {}

local GLayoutHandler = LayoutHandler.new(g.VimNotify)

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
			f = function(_) end,
			o = {},
		},
	}

	for _, command in ipairs(commands) do
		local success, error = u.regCom(command.c, command.f, command.o)
		if not success then
			g.VimNotify(error)
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
