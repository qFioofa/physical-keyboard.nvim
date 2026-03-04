local defaultLayouts = require("physical-keyboard.const.DefaultLayouts")

---@class Opts
local Opts = {}

Opts.__index = Opts

local _default = {
	enable = true,
	notify = true,
	maps = defaultLayouts,
}

function Opts.new()
	local self = setmetatable(_default, Opts)
	return self
end

---@param otherOpts table
function Opts:softClone(otherOpts)
	for key, value in pairs(otherOpts) do
		self[key] = value
	end
end

return Opts
