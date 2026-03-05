---@enum EchoKeyboardMode
local EchoKeyboardMode = {
	ALL = "all",
	BYTE = "byte",
	HEX = "hex",
	RAW = "raw",
	CODE = "code",
	MINIMAL = "minimal",
	DEBUG = "debug",
}

---@class EchoKeyboard
---@field enabled boolean
---@field _vimMessageInstance VimMessage
---@field _attach_group integer
---@field _mode EchoKeyboardMode
---@field _ns_id integer
---@field _key_callback fun(char: string)|nil
local M = {}

M.__index = M

local _default = {
	enabled = false,
	_vimMessageInstance = nil,
	_attach_group = nil,
	_ns_id = nil,
	_mode = EchoKeyboardMode.ALL,
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
	self._mode = _default._mode
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
			self._vimMessageInstance:i(
				"EchoKeyboard : turn on [" .. self._mode .. "]"
			)
		end)
	else
		self:_detach()
		pcall(function()
			self._vimMessageInstance:i("EchoKeyboard : turn off")
		end)
	end
end

---@param mode EchoKeyboardMode
function M:set_mode(mode)
	local valid = false
	for _, v in pairs(EchoKeyboardMode) do
		if v == mode then
			valid = true
			break
		end
	end

	if not valid then
		pcall(function()
			self._vimMessageInstance:w(
				"EchoKeyboard : invalid mode '" .. tostring(mode) .. "'"
			)
		end)
		return
	end

	self._mode = mode
	pcall(function()
		self._vimMessageInstance:i(
			"EchoKeyboard : mode switched to '" .. mode .. "'"
		)
	end)
end

---@private
---@return nil
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

---@private
---@return nil
function M:_detach()
	if not self._key_callback then
		return
	end

	vim.on_key(nil, self._ns_id)
	self._key_callback = nil
end

---@private
---@param char string
---@return string
function M:_format_all(char)
	local bytes = {}
	for i = 1, #char do
		table.insert(bytes, string.format("0x%02X", string.byte(char, i)))
	end
	return string.format("'%s' (%s)", char, table.concat(bytes, " "))
end

---@param char string
---@return string
function M:_format_byte(char)
	local bytes = {}
	for i = 1, #char do
		table.insert(bytes, tostring(string.byte(char, i)))
	end
	return table.concat(bytes, " ")
end

---@private
---@param char string
---@return string
function M:_format_hex(char)
	local bytes = {}
	for i = 1, #char do
		table.insert(bytes, string.format("0x%02X", string.byte(char, i)))
	end
	return table.concat(bytes, " ")
end

---@private
---@param char string
---@return string
function M:_format_raw(char)
	return string.format("%q", char)
end

---@private
---@param char string
---@return string
function M:_format_code(char)
	local cp = utf8 and utf8.codepoint(char)
	if cp then
		return tostring(cp)
	end
	return tostring(string.byte(char, 1))
end

---@private
---@param char string
---@return string
function M:_format_minimal(char)
	return char
end

---@private
---@param char string
---@return string
function M:_format_debug(char)
	local bytes = {}
	for i = 1, #char do
		table.insert(bytes, string.byte(char, i))
	end
	local cp = utf8 and utf8.codepoint(char) or string.byte(char, 1)
	return string.format(
		"Key: '%s' | Bytes: [%s] | Code: %d | Len: %d",
		char,
		table.concat(bytes, ", "),
		cp,
		#char
	)
end

---@private
---@param char string
function M:_display_key(char)
	if char == "" or char == "0" then
		return
	end

	local formatted = ""

	if self._mode == EchoKeyboardMode.ALL then
		formatted = self:_format_all(char)
	elseif self._mode == EchoKeyboardMode.BYTE then
		formatted = self:_format_byte(char)
	elseif self._mode == EchoKeyboardMode.HEX then
		formatted = self:_format_hex(char)
	elseif self._mode == EchoKeyboardMode.RAW then
		formatted = self:_format_raw(char)
	elseif self._mode == EchoKeyboardMode.CODE then
		formatted = self:_format_code(char)
	elseif self._mode == EchoKeyboardMode.MINIMAL then
		formatted = self:_format_minimal(char)
	elseif self._mode == EchoKeyboardMode.DEBUG then
		formatted = self:_format_debug(char)
	else
		formatted = char
	end

	self._vimMessageInstance:i("[Echo Keyboard] " .. formatted)
end

return {
	Class = M,
	Mode = EchoKeyboardMode,
}
