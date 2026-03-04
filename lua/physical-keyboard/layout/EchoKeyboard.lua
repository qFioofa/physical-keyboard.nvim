---@class EchoKeyboard
local M = {}

local _default = {
	enabled = false,

	_vimMessageInstance = nil,
}

---@param vimMessageInstance VimMessage
function M.new(vimMessageInstance)
	local self = setmetatable(_default, M)
	self._vimMessageInstance = vimMessageInstance
	return self
end

---@param enable boolean
function M:enable(enable)
	if type(enable) ~= "boolean" then
		enable = _default.enabled
	end

	self.enabled = enable
	if self.enabled then
		self:_attach()
	else
		self:_detatch()
	end
end

function M._attach() end

function M._detatch() end

return M
