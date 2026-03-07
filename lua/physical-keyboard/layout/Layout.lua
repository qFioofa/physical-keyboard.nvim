local VimModsModule = require("physical-keyboard.utils.VimMods")
local isValidVimMode = VimModsModule.isValidVimMode
local VimMods = VimModsModule.VimMods
local u = require("physical-keyboard.utils.Utils")

--- @enum
--- @class FormMapOptions
local FormMapOptions = {
	--- Include all options below
	ALL = "all",

	--- Automatically creates mappings for uppercase letters based on lowercase ones.
	--- Example: If `map['ф'] = 'a'`, this option adds `map['Ф'] = 'A'`.
	--- This respects the standard QWERTY uppercase mapping (e.g., 'A' for 'a', 'L' for 'l').
	AUTOCAPITAL = "auto_capital",

	--- Automatically generates mappings for common modifier keys (Ctrl, Alt, Shift)
	--- applied to the characters defined in the base map.
	--- Example: If `map['ф'] = 'a'`, this option adds:
	---   - `<C-ф>` -> `<C-a>`
	---   - `<A-ф>` -> `<A-a>`
	---   - `<S-ф>` -> `<S-a>` (which often results in the uppercase letter 'A')
	---   - `<C-S-ф>` -> `<C-S-a>` (often `<C-A>`), etc.
	--- This can create a large number of mappings and covers many plugin and native Vim shortcuts.
	AUTO_MODIFIERS = "auto_modifiers",

	--- Automatically handles the mapping of shifted special characters.
	--- Example: If `map['.'] = ';'`, this option would add `map['>'] = ':'`,
	--- because `>` is Shift+`.` and `:` is Shift+`;` on a standard QWERTY layout.
	--- This is particularly useful for punctuation and symbols accessed via Shift.
	AUTO_SHIFT_SPECIALS = "auto_shift_specials",

	--- Automatically generates mappings for number keys (0-9) if they are present
	--- in the base `layout.map`. For instance, if `map['='] = '0'` (on Russian layout),
	--- this could ensure Shift+`=` (which is `+`) maps to Shift+`0` (which is `)`).
	AUTO_NUMBERS = "auto_numbers",

	--- Automatically creates mappings for common whitespace and control characters
	--- like Space, Enter (`<CR>`), Tab (`<Tab>`), and Backspace (`<BS>`)
	--- if their base characters are included in the initial map.
	AUTO_WHITESPACE = "auto_whitespace",

	--- Automatically maps common bracket pairs (parentheses, square brackets, curly braces)
	--- based on the base map. Example: if `map['х'] = '['` and `map['ъ'] = ']'`, it ensures
	--- Shifted versions `Х` -> `{` and `Ъ` -> `}` are also mapped.
	AUTO_BRACKETS = "auto_brackets",
}

---@class Layout
---@field name string
---@field active boolean
---@field vim_mode table<VimMod>
---@field form_map_options table<FormMapOptions>|table<string, string>|string
---@field layout_name string
---@field map table<string, string>
---@field ns_id number|nil
---@field _on_error fun(msg: string)
local M = {}

M.__index = M

local _default = {
	name = "",
	active = true,
	vim_mode = { "n" },
	form_map_options = {},
	layout_name = "qwerty",
	map = {},
	_on_error = function(_) end,
}

function M.new()
	local self = setmetatable({}, M)

	self.name = _default.name
	self.active = _default.active
	self.vim_mode = _default.vim_mode
	self.form_map_options = _default.form_map_options
	self.layout_name = _default.layout_name
	self.map = vim.deepcopy(_default.map)
	self._on_error = _default._on_error
	return self
end

---@param active boolean
---@return boolean
function M:setActive(active)
	if type(active) ~= "boolean" then
		self._on_error("[Layout] [setActive] | 'active' field is not a boolean")
		return false
	end

	self.active = active
	return true
end

---@param name string
---@return boolean
function M:setName(name)
	if type(name) ~= "string" then
		self._on_error("[Layout] [setName] | 'name' field is not a string")
		return false
	end

	self.name = name
	return true
end

---@param mode string|table<string>
---@return boolean
function M:setVimMode(mode)
	if
		mode == "all" or (type(mode) == "table" and u.table.is_in(mode, "all"))
	then
		self.vim_mode = u.deepcopy(u.table.values(VimMods))
		return true
	end

	if type(mode) == "string" then
		mode = { mode }
	end

	for _, expectedMode in ipairs(mode) do
		if not isValidVimMode(expectedMode) then
			local modes_string = table.concat(VimModsModule.VimMods, " ")

			self._on_error(
				"[Layout] [setVimMode] | wrong vim mode.\nUse one of: "
					.. modes_string
			)
			return false
		end
	end

	self.vim_mode = mode
	return true
end

---@param layout_name string
---@return boolean
function M:setLayoutName(layout_name)
	if type(layout_name) ~= "string" or #layout_name == 0 then
		self._on_error(
			"[Layout] [setLayoutName] | 'layout_name' field is not a non-empty string"
		)
		return false
	end

	self.layout_name = layout_name
	return true
end

---@param func function(string)
---@return boolean
function M:setOnError(func)
	if type(func) ~= "function" then
		self._on_error(
			"[Layout] [setOnError] | 'on_error' field is not a function"
		)
		return false
	end

	self._on_error = func
	return true
end

---@param map table<string, string>
---@return boolean
function M:setMap(map)
	if type(map) ~= "table" then
		self._on_error("[Layout] [setMap] | 'map' argument is not a table")
		return false
	end

	self.map = map
	return true
end

---@param form_map_options table<string, string>|table<FormMapOptions>|string
---@return boolean
function M:setFormMapOptions(form_map_options)
	if
		type(form_map_options) ~= "table"
		and type(form_map_options) ~= "string"
	then
		self._on_error(
			"[Layout] [setMap] | 'map' argument is not a table or string"
		)
		return false
	end

	self.form_map_options = form_map_options
	return true
end

---@return boolean
function M:formMap()
	local opts = self.form_map_options or _default.form_map_options

	if type(opts) == "string" then
		if opts == FormMapOptions.ALL then
			opts = u.deepcopy(FormMapOptions)
		else
			opts = { opts }
		end
	elseif type(opts) == "table" then
		if u.table.is_in(opts, FormMapOptions.ALL) then
			opts = u.deepcopy(FormMapOptions)
		end
	end

	local acc = {}
	local formMapOptionsFunctions = self:_optionMap()
	for _, option in ipairs(opts) do
		local func = formMapOptionsFunctions[option]
		if type(func) == "function" then
			local mapExtra = func(self.map)
			u.table.merge(acc, mapExtra)
		end
	end

	u.table.merge(acc, self.map)
	self.map = acc
	return true
end

---@private
function M:_optionMap()
	local optsMap = {}
	optsMap[FormMapOptions.ALL] = function(_)
		return {}
	end
	optsMap[FormMapOptions.AUTOCAPITAL] = self.autocapital
	optsMap[FormMapOptions.AUTO_MODIFIERS] = self.autoModifiers
	optsMap[FormMapOptions.AUTO_SHIFT_SPECIALS] = self.autoShiftSpecials
	optsMap[FormMapOptions.AUTO_NUMBERS] = self.autoNumbers
	optsMap[FormMapOptions.AUTO_WHITESPACE] = self.autoWhitespace
	optsMap[FormMapOptions.AUTO_BRACKETS] = self.autoBrackets
	return optsMap
end

---@param map table<string, string>
---@return table<string,string>
function M.autocapital(map)
	local res = vim.deepcopy(map)

	for phys_lower, en_lower in pairs(map) do
		if phys_lower:match("^%l$") and en_lower:match("^%l$") then
			local phys_upper = phys_lower:upper()
			local en_upper = en_lower:upper()
			res[phys_upper] = en_upper
		end
	end
	return res
end

---@param map table<string, string>
---@return table<string,string>
function M.autoModifiers(map)
	local res = vim.deepcopy(map)
	local modifiers = { "C", "A", "S" }
	for phys_char, en_char in pairs(map) do
		for _, mod1 in ipairs(modifiers) do
			local lhs = "<" .. mod1 .. "-" .. phys_char .. ">"
			local rhs = "<" .. mod1 .. "-" .. en_char .. ">"
			res[lhs] = rhs

			for _, mod2 in ipairs(modifiers) do
				if mod1 ~= mod2 then
					local sorted_mods = { mod1, mod2 }
					table.sort(sorted_mods)
					local combo_lhs = "<"
						.. table.concat(sorted_mods, "-")
						.. "-"
						.. phys_char
						.. ">"
					local combo_rhs = "<"
						.. table.concat(sorted_mods, "-")
						.. "-"
						.. en_char
						.. ">"
					res[combo_lhs] = combo_rhs
				end
			end
		end
	end
	return res
end

---@param map table<string, string>
---@return table<string,string>
function M.autoVisualDuplicate(map)
	local res = vim.deepcopy(map)
	return res
end

---@param map table<string, string>
---@return table<string,string>
function M.autoInsertNormalDuplicate(map)
	local res = vim.deepcopy(map)
	return res
end

---@param map table<string, string>
---@return table<string,string>
function M.autoShiftSpecials(map)
	local res = vim.deepcopy(map)
	local shift_map = {
		["1"] = "!",
		["2"] = "@",
		["3"] = "#",
		["4"] = "$",
		["5"] = "%",
		["6"] = "^",
		["7"] = "&",
		["8"] = "*",
		["9"] = "(",
		["0"] = ")",
		["-"] = "_",
		["="] = "+",
		["["] = "{",
		["]"] = "}",
		["\\"] = "|",
		[";"] = ":",
		["'"] = '"',
		[","] = "<",
		["."] = ">",
		["/"] = "?",
		["`"] = "~",
	}
	for phys_char, en_char in pairs(map) do
		local phys_shifted = shift_map[phys_char]
		local en_shifted = shift_map[en_char]
		if phys_shifted and en_shifted then
			res[phys_shifted] = en_shifted
		end
	end
	return res
end

---@param map table<string, string>
---@return table<string,string>
function M.autoNumbers(map)
	local res = vim.deepcopy(map)
	local num_shift_map = {
		["1"] = "!",
		["2"] = "@",
		["3"] = "#",
		["4"] = "$",
		["5"] = "%",
		["6"] = "^",
		["7"] = "&",
		["8"] = "*",
		["9"] = "(",
		["0"] = ")",
	}
	for phys_char, en_char in pairs(map) do
		local phys_shifted = num_shift_map[phys_char]
		local en_shifted = num_shift_map[en_char]
		if phys_shifted and en_shifted then
			res[phys_shifted] = en_shifted
		end
	end
	return res
end

---@param map table<string, string>
---@return table<string,string>
function M.autoWhitespace(map)
	return vim.deepcopy(map)
end

---@param map table<string, string>
---@return table<string,string>
function M.autoBrackets(map)
	local res = vim.deepcopy(map)
	local bracket_pairs = {
		{ p_open = "[", p_close = "]", e_open = "[", e_close = "]" },
		{ p_open = "(", p_close = ")", e_open = "(", e_close = ")" },
		{ p_open = "{", p_close = "}", e_open = "{", e_close = "}" },
		{ p_open = "<", p_close = ">", e_open = "<", e_close = ">" },
	}
	for _, bp in ipairs(bracket_pairs) do
		if map[bp.p_open] == bp.e_open and map[bp.p_close] == bp.e_close then
			res[bp.p_open:upper()] = bp.e_open:upper()
			res[bp.p_close:upper()] = bp.e_close:upper()
		end
	end
	return res
end

---@return number|nil
function M:getNsIdMappings()
	return self._ns_id_mappings
end

---@param ns_id number|nil
function M:setNsIdMappings(ns_id)
	if type(ns_id) ~= "number" and ns_id ~= nil then
		self._on_error(
			"[Layout] [setNsIdMappings] | 'ns_id' field is not a number or nil"
		)
		return false
	end
	self._ns_id_mappings = ns_id
	return true
end

return M
