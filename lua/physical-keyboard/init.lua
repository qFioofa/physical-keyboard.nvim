local Opts = require("physical-keyboard.Opts")
local g = require("physical-keyboard.const.Globals")
local u = require("physical-keyboard.utils.Utils")

local M = {}

local function registerCommands()
	local commands = {
		{
			c = "PhyStatus",
			f = function() end,
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
end

return M
