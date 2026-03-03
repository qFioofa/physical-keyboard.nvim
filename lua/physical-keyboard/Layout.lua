---@class Layout
local M = {
	name = "",
	active = true,
	auto_capital_duplication = true,
	map = {},
}

M.__index = M

local _default = {
	name = "",
	active = true,
	auto_capital_duplication = true,
	map = {},
}

function M.new()
	local self = setmetatable(_default, M)

	return self
end

return M
