local c = require("physical-keyboard.const.Constants")

---@class Opts
local Opts = {}

Opts.__index = Opts

local _default = {
	enable = true,
	notify = true,
	maps = c.DefaultMaps,
}

function Opts.new()
	local self = setmetatable(_default, Opts)
	return self
end

---@param otherOpts table
function Opts:softClone(otherOpts)
	for key, value in pairs(self) do
		print(otherOpts[key])
		self[key] = value
	end
end

return Opts
