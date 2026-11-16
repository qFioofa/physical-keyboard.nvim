--- Diagnostic "echo keyboard" that prints the raw key(s) Neovim receives.
---
--- Useful to verify what the terminal actually delivers for a national layout
--- (bytes, code points, or the plain character).
local M = {}

local MODES = { "all", "byte", "hex", "raw", "code", "minimal", "debug" }

local state = {
	enabled = false,
	mode = "all",
	ns = nil,
	callback = nil,
	notify = function(message)
		vim.notify(message, vim.log.levels.INFO)
	end,
}

local function bytes(char)
	local result = {}
	for index = 1, #char do
		result[#result + 1] = string.format("0x%02X", string.byte(char, index))
	end
	return table.concat(result, " ")
end

local function decimal(char)
	local result = {}
	for index = 1, #char do
		result[#result + 1] = tostring(string.byte(char, index))
	end
	return table.concat(result, " ")
end

local function codepoint(char)
	if utf8 and utf8.codepoint then
		local ok, value = pcall(utf8.codepoint, char)
		if ok then
			return tostring(value)
		end
	end
	return tostring(string.byte(char, 1))
end

local function format(char)
	local mode = state.mode
	if mode == "byte" then
		return decimal(char)
	elseif mode == "hex" then
		return bytes(char)
	elseif mode == "raw" then
		return string.format("%q", char)
	elseif mode == "code" then
		return codepoint(char)
	elseif mode == "minimal" then
		return char
	elseif mode == "debug" then
		return string.format(
			"Key: '%s' | Bytes: [%s] | Code: %s | Len: %d",
			char,
			decimal(char),
			codepoint(char),
			#char
		)
	end
	return string.format("'%s' (%s)", char, bytes(char))
end

local function display(char)
	if char == "" or char == "0" then
		return
	end
	state.notify(
		string.format("[Echo Keyboard] mode=%s\n%s", vim.api.nvim_get_mode().mode, format(char))
	)
end

---@param opts table|nil
function M.setup(opts)
	opts = opts or {}
	state.ns = vim.api.nvim_create_namespace("PhysicalKeyboardEcho")
	if opts.notify then
		state.notify = opts.notify
	end
	if opts.mode and M.is_valid_mode(opts.mode) then
		state.mode = opts.mode
	end
end

---@param mode string
---@return boolean
function M.is_valid_mode(mode)
	for _, value in ipairs(MODES) do
		if value == mode then
			return true
		end
	end
	return false
end

---@return string[]
function M.modes()
	return vim.deepcopy(MODES)
end

---@param enabled boolean|nil
function M.enable(enabled)
	if enabled == nil then
		enabled = not state.enabled
	end
	if enabled == state.enabled then
		return state.enabled
	end

	state.enabled = enabled

	if enabled then
		if not state.callback then
			state.callback = function(char)
				if state.enabled and char then
					display(tostring(char))
				end
			end
		end
		vim.on_key(state.callback, state.ns)
	else
		vim.on_key(nil, state.ns)
	end

	return state.enabled
end

---@param mode string
---@return boolean
function M.set_mode(mode)
	if not M.is_valid_mode(mode) then
		return false
	end
	state.mode = mode
	return true
end

---@return string
function M.mode()
	return state.mode
end

---@return boolean
function M.is_enabled()
	return state.enabled
end

return M
