local defaultLayouts = require("physical-keyboard.const.DefaultLayouts")
local u = require("physical-keyboard.utils.Utils")

---@class Opts
---@field enable boolean
---@field notify boolean
---@field active_layouts string|table<string>|any
---@field maps table<string, Layout>
local Opts = {}

Opts.__index = Opts

local _default = {
	enable = true,
	notify = true,
	active_layouts = {},
	maps = {},
}

function Opts.new()
	local self = setmetatable({}, Opts)
	self.enable = _default.enable
	self.notify = _default.notify
	self.active_layouts = _default.active_layouts
	self.maps = u.deepcopy(defaultLayouts)
	return self
end

--- It's called 'soft' since we need to
--- replace default layout bind
--- with user's one (if user hits)
---@param otherOpts table
function Opts:softClone(otherOpts)
	if not otherOpts then
		return
	end

	if otherOpts.enable ~= nil then
		self.enable = otherOpts.enable
	end

	if otherOpts.notify ~= nil then
		self.notify = otherOpts.notify
	end

	if
		type(otherOpts.active_layouts) == "string"
		or type(otherOpts.active_layouts) == "table"
	then
		self.active_layouts = otherOpts.active_layouts
	end

	if type(otherOpts.maps) == "table" then
		self.maps = otherOpts.maps
	end
end

return Opts
