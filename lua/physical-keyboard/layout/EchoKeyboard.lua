---@class EchoKeyboard
---@field enabled boolean
---@field _vimMessageInstance VimMessage
---@field _attach_group integer
---@field _ns_id integer
---@field _key_callback fun(char: string)|nil
local M = {}

M.__index = M

local _default = {
	enabled = false,
	_vimMessageInstance = nil,
	_attach_group = nil,
	_ns_id = nil,
	_key_callback = nil,
}

---@param vimMessageInstance VimMessage
function M.new(vimMessageInstance)
	local self = setmetatable({}, M)
	self.enabled = _default.enabled
	self._vimMessageInstance = vimMessageInstance
	self._attach_group =
		vim.api.nvim_create_augroup("EchoKeyboard", { clear = true })
	self._ns_id = vim.api.nvim_create_namespace("EchoKeyboardNS")
	return self
end

---@param enable boolean|any
function M:enable(enable)
	if type(enable) ~= "boolean" then
		enable = not self.enabled
	end

	if self.enabled == enable then
		return
	end

	self.enabled = enable

	if self.enabled then
		self:_attach()
		pcall(function()
			self._vimMessageInstance:i("EchoKeyboard : turn on")
		end)
	else
		self:_detach()
		pcall(function()
			self._vimMessageInstance:i("EchoKeyboard : turn off")
		end)
	end
end

function M:_attach()
	if self._key_callback then
		return
	end

	self._key_callback = function(char)
		if char then
			self:_display_key(tostring(char))
		end
	end

	vim.on_key(self._key_callback, self._ns_id)
end

function M:_detach()
	if not self._key_callback then
		return
	end

	vim.on_key(nil, self._ns_id)
	self._key_callback = nil
end

---@param char string
function M:_display_key(char)
	if char == "" or char == "0" then
		return
	end

	self._vimMessageInstance:i(
		string.format("[Echo Keyboard] Pressed: '%s'", char)
	)
end

return M
