local defaultLayouts = require("physical-keyboard.const.DefaultLayouts")
local u = require("physical-keyboard.utils.Utils")

--- Configuration options for the Physical Keyboard plugin.
--- Handles default values and merging with user-provided options.
---@class Opts
---@field enable boolean Enable or disable the plugin
---@field notify boolean Enable or disable notifications
---@field active_layouts string|string[] Layout(s) to activate on startup
---@field userLayouts table<string, Layout> User-provided custom layouts
local Opts = {}

Opts.__index = Opts

--- Default configuration values
local _default = {
	enable = true,
	notify = true,
	active_layouts = {},
	userLayouts = {},
}

--- Creates a new Opts instance with default values.
---@return Opts
function Opts.new()
	local self = setmetatable({}, Opts)
	self.enable = _default.enable
	self.notify = _default.notify
	self.active_layouts = _default.active_layouts
	self.userLayouts = u.deepcopy(defaultLayouts)
	return self
end

--- Soft merges user options with defaults.
--- Preserves default layouts unless explicitly overridden by user.
---@param otherOpts table|nil User-provided configuration options
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

	if type(otherOpts.userLayouts) == "table" then
		-- Merge user layouts with defaults
		---@diagnostic disable-next-line: assign-type-mismatch
		for name, layout in pairs(otherOpts.userLayouts) do
			self.userLayouts[name] = layout
		end
	end
end

return Opts
