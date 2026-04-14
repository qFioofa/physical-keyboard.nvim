--- Echo keyboard display modes
---@alias EchoKeyboardMode
---| "all" # Show all information (character, bytes, code)
---| "byte" # Show byte values only
---| "hex" # Show hexadecimal values only
---| "raw" # Show raw quoted string
---| "code" # Show Unicode code point
---| "minimal" # Show character only
---| "debug" # Show detailed debug information

--- EchoKeyboard displays typed characters in the echo area.
---@class EchoKeyboard
---@field enabled boolean Whether the echo keyboard is enabled
---@field _vimMessageInstance VimMessage Instance for displaying messages
---@field _attach_group integer Autocmd group ID
---@field _mode EchoKeyboardMode Current display mode
---@field _ns_id integer Namespace ID for key callbacks
---@field _key_callback fun(char: string)|nil Key callback function
local M = {}

M.__index = M

local _default = {
	enabled = false,
	_vimMessageInstance = nil,
	_attach_group = nil,
	_ns_id = nil,
	_mode = "all",
	_key_callback = nil,
}

--- Creates a new EchoKeyboard instance.
---@param vimMessageInstance VimMessage Instance for displaying messages
---@return EchoKeyboard
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

--- Enables or disables the echo keyboard display.
---@param enable boolean|any If boolean, sets the state; otherwise toggles
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
				"Echo Keyboard: enabled [" .. self._mode .. "]"
			)
		end)
	else
		self:_detach()
		pcall(function()
			self._vimMessageInstance:i("Echo Keyboard: disabled")
		end)
	end
end

--- Sets the display mode.
---@param mode EchoKeyboardMode The display mode to set
function M:set_mode(mode)
	local valid = false

	-- Check against known mode values
	local validModes = { "all", "byte", "hex", "raw", "code", "minimal", "debug" }
	for _, v in ipairs(validModes) do
		if v == mode then
			valid = true
			break
		end
	end

	if not valid then
		pcall(function()
			self._vimMessageInstance:w(
				"Echo Keyboard: invalid mode '" .. tostring(mode) .. "'"
			)
		end)
		return
	end

	self._mode = mode
	pcall(function()
		self._vimMessageInstance:i(
			"Echo Keyboard: mode set to '" .. mode .. "'"
		)
	end)
end

--- Attaches the key callback.
---@private
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

--- Detaches the key callback.
---@private
function M:_detach()
	if not self._key_callback then
		return
	end

	vim.on_key(nil, self._ns_id)
	self._key_callback = nil
end

--- Formats character information with all details.
---@private
---@param char string The character to format
---@return string Formatted string
function M:_format_all(char)
	local bytes = {}
	for i = 1, #char do
		table.insert(bytes, string.format("0x%02X", string.byte(char, i)))
	end
	return string.format("'%s' (%s)", char, table.concat(bytes, " "))
end

--- Formats character as byte values.
---@param char string The character to format
---@return string Formatted string
function M:_format_byte(char)
	local bytes = {}
	for i = 1, #char do
		table.insert(bytes, tostring(string.byte(char, i)))
	end
	return table.concat(bytes, " ")
end

--- Formats character as hexadecimal values.
---@private
---@param char string The character to format
---@return string Formatted string
function M:_format_hex(char)
	local bytes = {}
	for i = 1, #char do
		table.insert(bytes, string.format("0x%02X", string.byte(char, i)))
	end
	return table.concat(bytes, " ")
end

--- Formats character as raw quoted string.
---@private
---@param char string The character to format
---@return string Formatted string
function M:_format_raw(char)
	return string.format("%q", char)
end

--- Formats character as Unicode code point.
---@private
---@param char string The character to format
---@return string Formatted string
function M:_format_code(char)
	local cp = utf8 and utf8.codepoint(char)
	if cp then
		return tostring(cp)
	end
	return tostring(string.byte(char, 1))
end

--- Formats character minimally.
---@private
---@param char string The character to format
---@return string Formatted string
function M:_format_minimal(char)
	return char
end

--- Formats character with debug information.
---@private
---@param char string The character to format
---@return string Formatted string
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

--- Displays a key press in the echo area.
---@private
---@param char string The character to display
function M:_display_key(char)
	if char == "" or char == "0" then
		return
	end

	local formatted = ""

	if self._mode == "all" then
		formatted = self:_format_all(char)
	elseif self._mode == "byte" then
		formatted = self:_format_byte(char)
	elseif self._mode == "hex" then
		formatted = self:_format_hex(char)
	elseif self._mode == "raw" then
		formatted = self:_format_raw(char)
	elseif self._mode == "code" then
		formatted = self:_format_code(char)
	elseif self._mode == "minimal" then
		formatted = self:_format_minimal(char)
	elseif self._mode == "debug" then
		formatted = self:_format_debug(char)
	else
		formatted = char
	end

	self._vimMessageInstance:i(
		string.format(
			"[Echo Keyboard]\nMode: %s\n%s",
			vim.api.nvim_get_mode().mode,
			formatted
		)
	)
end

return {
	Class = M,
	Mode = {
		ALL = "all",
		BYTE = "byte",
		HEX = "hex",
		RAW = "raw",
		CODE = "code",
		MINIMAL = "minimal",
		DEBUG = "debug",
	},
}
