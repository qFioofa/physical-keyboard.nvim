local VimModsModule = require("physical-keyboard.utils.VimMods")
local isValidVimMode = VimModsModule.isValidVimMode
local VimMods = VimModsModule.VimMods
local c = require("physical-keyboard.const.Constants")
local u = require("physical-keyboard.utils.Utils")

--- Form map option constants
---@alias FormMapOptions
---| "all"
---| "auto_capital"
---| "auto_modifiers"
---| "auto_shift_specials"
---| "auto_numbers"
---| "auto_whitespace"
---| "auto_brackets"
---| "auto_visual_duplicate"
---| "auto_insert_normal_duplicate"
---| "exclude_insert"
---| "auto_altgr"
---| "auto_dead_keys"
---| "auto_accents"
---| "auto_iso_specials"
---| "auto_noremap_variants"
---| "auto_keypad"
---| "auto_leader_mappings"
---| "auto_existing_mappings"
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

	--- Automatically creates visual mode mappings based on normal mode mappings.
	--- This ensures that character motions work consistently across modes.
	AUTO_VISUAL_DUPLICATE = "auto_visual_duplicate",

	--- Automatically creates insert mode mappings based on normal mode mappings.
	--- This ensures that character input works consistently in insert mode.
	AUTO_INSERT_NORMAL_DUPLICATE = "auto_insert_normal_duplicate",

	--- Excludes insert mode from the vim_mode list when creating mappings.
	--- Useful when you want to prevent layout switching during normal typing.
	EXCLUDE_INSERT = "exclude_insert",

	--- Automatically handles AltGr (Right Alt) modifier combinations for European layouts.
	--- This is essential for German, French, Spanish and other European keyboard layouts
	--- where AltGr is used to access special characters like €, @, #, etc.
	--- Example: On German layout, AltGr+e produces €, so this adds <A-e> -> <A-e> mappings.
	AUTO_ALTGR = "auto_altgr",

	--- Automatically handles dead key combinations for layouts that use them.
	--- Dead keys are used in French, Spanish, and other Romance language layouts.
	--- Examples: ^ (circumflex), ` (grave), ´ (acute), ~ (tilde), ¨ (umlaut/diaeresis)
	--- This option ensures dead keys followed by base characters produce correct output.
	AUTO_DEAD_KEYS = "auto_dead_keys",

	--- Automatically handles accent combinations for accented characters.
	--- Maps common accented character combinations used in European languages.
	--- Example: If base map has 'é' -> 'e', this can help with related accent mappings.
	--- Works in conjunction with auto_dead_keys for comprehensive accent support.
	AUTO_ACCENTS = "auto_accents",

	--- Automatically handles ISO-specific special characters.
	--- For ISO keyboards (common in Europe), this handles keys like < > | and § ° ½.
	--- Example: German ISO layout has < > | near left Shift, French has µ ².
	AUTO_ISO_SPECIALS = "auto_iso_specials",

	--- Automatically duplicates mappings for noremap versions.
	--- Creates both remap and noremap versions of each key binding.
	--- Useful when some mappings need to trigger other mappings recursively.
	AUTO_NOREMAP_VARIANTS = "auto_noremap_variants",

	--- Automatically handles numeric keypad mappings.
	--- Maps keypad number keys (KP0-KP9) and operations (KP+, KP-, KP*, KP/).
	--- Useful for layouts where keypad should follow the same translation rules.
	AUTO_KEYPAD = "auto_keypad",

	--- Automatically detects and translates existing leader key mappings.
	--- This option scans for existing mappings that use <leader> and creates
	--- translated versions using the physical layout characters.
	--- Example: If you have <leader>yy mapped, and map['н'] = 'n', this creates
	--- a mapping for <leader>нн that triggers the same command.
	--- IMPORTANT: This option must be applied AFTER other plugins have set up their mappings.
	--- Call layout:formMap() again after loading other plugins, or use this option
	--- in combination with a delayed initialization.
	AUTO_LEADER_MAPPINGS = "auto_leader_mappings",

	--- Automatically detects and translates existing buffer-local and global mappings.
	--- Similar to auto_leader_mappings but works for all mappings, not just leader-based.
	--- This is useful for translating mappings from other plugins or your config.
	--- WARNING: This can create a large number of mappings and may have performance impact.
	--- Use with caution and consider excluding certain patterns.
	AUTO_EXISTING_MAPPINGS = "auto_existing_mappings",
}

---@class Layout
---@field name string
---@field active boolean
---@field vim_mode table<VimMod>
---@field form_map_options FormMapOptions[]|string
---@field layout_name string
---@field map table<string, string>
---@field ns_id number|nil
---@field _on_error fun(msg: string)
---@field _registered_mappings table<integer, table>
---@field _ns_id_mappings number|nil
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
	_registered_mappings = {},
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
	self._registered_mappings = {}
	return self
end

--- Sets the active state of the layout.
---@param active boolean Whether the layout should be active
---@return boolean True if successful, false otherwise
function M:setActive(active)
	if type(active) ~= "boolean" then
		self._on_error("[Layout] [setActive] | 'active' field is not a boolean")
		return false
	end

	self.active = active
	return true
end

--- Sets the name of the layout.
---@param name string The name to set
---@return boolean True if successful, false otherwise
function M:setName(name)
	if type(name) ~= "string" then
		self._on_error("[Layout] [setName] | 'name' field is not a string")
		return false
	end

	self.name = name
	return true
end

--- Sets the Vim modes for the layout.
---@param mode string|table<string> Vim mode(s) to set (e.g., "n", {"n", "v"}, "all")
---@return boolean True if successful, false otherwise
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

--- Sets the layout name (e.g., "qwerty", "dvorak").
---@param layout_name string The layout name to set
---@return boolean True if successful, false otherwise
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

--- Sets the error handler function.
---@param func function(string) The error handler function
---@return boolean True if successful, false otherwise
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

--- Sets the character mapping table.
---@param map table<string, string> The mapping table (physical char -> English char)
---@return boolean True if successful, false otherwise
function M:setMap(map)
	if type(map) ~= "table" then
		self._on_error("[Layout] [setMap] | 'map' argument is not a table")
		return false
	end

	local valid, err = M.validateMap(map)
	if not valid then
		self._on_error("[Layout] [setMap] | " .. err)
		return false
	end

	self.map = map
	return true
end

--- Sets the form map options for automatic mapping generation.
---@param form_map_options table<string, string>|table<FormMapOptions>|string Options for formMap
---@return boolean True if successful, false otherwise
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

--- Builds the complete mapping table by applying all form map options.
---@return boolean True if successful, false otherwise
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

--- Returns a map of option names to their handler functions.
---@private
---@return table<string, function>
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
	optsMap[FormMapOptions.AUTO_VISUAL_DUPLICATE] = self.autoVisualDuplicate
	optsMap[FormMapOptions.AUTO_INSERT_NORMAL_DUPLICATE] =
		self.autoInsertNormalDuplicate
	optsMap[FormMapOptions.EXCLUDE_INSERT] = self.excludeInsert
	optsMap[FormMapOptions.AUTO_ALTGR] = self.autoAltGr
	optsMap[FormMapOptions.AUTO_DEAD_KEYS] = self.autoDeadKeys
	optsMap[FormMapOptions.AUTO_ACCENTS] = self.autoAccents
	optsMap[FormMapOptions.AUTO_ISO_SPECIALS] = self.autoIsoSpecials
	optsMap[FormMapOptions.AUTO_NOREMAP_VARIANTS] = self.autoNoremapVariants
	optsMap[FormMapOptions.AUTO_KEYPAD] = self.autoKeypad
	optsMap[FormMapOptions.AUTO_LEADER_MAPPINGS] = self.autoLeaderMappings
	optsMap[FormMapOptions.AUTO_EXISTING_MAPPINGS] = self.autoExistingMappings
	return optsMap
end

--- Validates if a character is a valid key for mapping.
--- Checks against special keys, latin letters, and punctuation from Constants.
---
--- @param char string The character to validate
--- @return boolean true if valid, false otherwise
---
--- LIMITATIONS:
--- - Only explicitly validates against predefined sets in Constants.lua
--- - Allows any single character for international layout support
--- - Does not validate multi-character sequences (handled elsewhere)
local function isValidKey(char)
	if type(char) ~= "string" or #char == 0 then
		return false
	end

	-- Check if it's a special key (e.g., <CR>, <Esc>, etc.)
	for _, special in ipairs(c.special_keys) do
		if char == special then
			return true
		end
	end

	-- Check if it's a single character from supported sets
	if #char == 1 then
		-- Check latin letters
		for _, letter in ipairs(c.latin_letters) do
			if char == letter then
				return true
			end
		end
		-- Check punctuation
		for _, punct in ipairs(c.punctuation) do
			if char == punct then
				return true
			end
		end
	end

	-- Allow any other single character (for international layouts)
	return true
end

--- Validates a mapping table.
--- Ensures all keys and values are valid strings.
---
--- @param map table<string, string> The mapping table to validate
--- @return boolean success True if valid, false otherwise
--- @return string? error_message Error message if validation failed
---
--- LIMITATIONS:
--- - Does not check for conflicting mappings (same key mapped twice)
--- - Does not verify that mapped values are valid Vim key sequences
--- - Validation is permissive for international character support
function M.validateMap(map)
	if type(map) ~= "table" then
		return false, "Map must be a table"
	end

	for lhs, rhs in pairs(map) do
		if not isValidKey(lhs) then
			return false, string.format("Invalid key: '%s'", tostring(lhs))
		end
		if type(rhs) ~= "string" or #rhs == 0 then
			return false,
				string.format(
					"Invalid value for key '%s': must be non-empty string",
					tostring(lhs)
				)
		end
	end

	return true, nil
end

--- Automatically creates mappings for uppercase letters based on lowercase ones.
--- Respects standard QWERTY uppercase mapping.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with uppercase letters
---
--- HOW IT WORKS:
--- - Iterates through all mappings in the base map
--- - For each lowercase letter mapping (e.g., 'ф' -> 'a'), adds uppercase version ('Ф' -> 'A')
--- - Uses Lua's string.upper() for case conversion
---
--- EXAMPLE:
--- - Input: {['ф'] = 'a', ['ц'] = 'w'}
--- - Output: {['ф'] = 'a', ['ц'] = 'w', ['Ф'] = 'A', ['Ц'] = 'W'}
---
--- LIMITATIONS:
--- - Only works with single-character mappings
--- - Requires both physical and English characters to be lowercase letters
--- - Does not handle special uppercase rules (e.g., German ß -> SS)
--- - May not work correctly for all international characters
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

--- Automatically generates mappings for common modifier keys (Ctrl, Alt, Shift).
--- Creates all combinations of modifiers applied to base character mappings.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with modifier combinations
---
--- HOW IT WORKS:
--- - For each character mapping, creates mappings for:
---   - Single modifiers: <C-key>, <A-key>, <S-key>
---   - Double modifiers: <C-A-key>, <C-S-key>, <A-S-key>
--- - Modifiers are sorted alphabetically in combinations (e.g., <A-C-key> not <C-A-key>)
---
--- EXAMPLE:
--- - Input: {['ф'] = 'a'}
--- - Output adds: {['<C-ф>'] = '<C-a>', ['<A-ф>'] = '<A-a>', ['<S-ф>'] = '<S-a>',
---                  ['<A-C-ф>'] = '<A-C-a>', ['<C-S-ф>'] = '<C-S-a>', ['<A-S-ф>'] = '<A-S-a>'}
---
--- LIMITATIONS:
--- - Creates many mappings (7x the base map size) - can impact performance
--- - Does not handle triple modifier combinations (e.g., <C-A-S-key>)
--- - May conflict with existing Vim or plugin shortcuts
--- - Shift mappings may not work as expected (often produces uppercase)
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

--- Automatically handles the mapping of shifted special characters.
--- Maps punctuation and symbols accessed via Shift key.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with shifted characters
---
--- HOW IT WORKS:
--- - Uses a predefined shift_map for US QWERTY layout
--- - For each character in base map, checks if its shifted version exists
--- - If both physical and English shifted versions exist, adds the mapping
---
--- EXAMPLE:
--- - Input: {['.'] = ';'}
--- - Output adds: {['>'] = ':'} (because > is Shift+. and : is Shift+;)
---
--- LIMITATIONS:
--- - Uses hardcoded US QWERTY shift mappings
--- - May not work correctly for non-QWERTY target layouts
--- - Does not handle layout-specific shift behavior
--- - Some shifted characters may vary by keyboard region
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

--- Automatically generates mappings for number keys (0-9) with their shifted versions.
--- Handles number row symbols (!, @, #, $, %, ^, &, *, (, )).
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with number shift mappings
---
--- HOW IT WORKS:
--- - Uses a predefined num_shift_map for number row shifted symbols
--- - For each number in base map, adds mapping for its shifted symbol
---
--- EXAMPLE:
--- - Input: {['='] = '0'} (Russian layout)
--- - Output adds: {['+'] = ')'} (because + is Shift+= and ) is Shift+0)
---
--- LIMITATIONS:
--- - Only handles standard US number row shifted symbols
--- - Does not handle numpad keys (use auto_keypad option)
--- - May conflict with auto_shift_specials for overlapping keys
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

--- Automatically creates mappings for common whitespace and control characters.
--- Handles Space, Tab, Enter, Backspace, Delete, Escape.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with whitespace mappings
---
--- HOW IT WORKS:
--- - Defines common whitespace/control character mappings
--- - If physical character matches a whitespace key, maps it to standard Vim key
---
--- EXAMPLE:
--- - Input: {[' '] = ' ', ['<Tab>'] = '<Tab>'}
--- - Output: Ensures whitespace keys map correctly
---
--- LIMITATIONS:
--- - Only handles predefined whitespace characters
--- - Does not handle all control characters (e.g., Ctrl+H, Ctrl+I)
--- - Some whitespace mappings may be layout-specific
function M.autoWhitespace(map)
	local res = vim.deepcopy(map)
	-- Common whitespace and control character mappings
	local whitespace_map = {
		[" "] = " ",
		["<Tab>"] = "<Tab>",
		["<CR>"] = "<CR>",
		["<Enter>"] = "<CR>",
		["<Return>"] = "<CR>",
		["<BS>"] = "<BS>",
		["<Backspace>"] = "<BS>",
		["<Del>"] = "<Del>",
		["<Delete>"] = "<Del>",
		["<Esc>"] = "<Esc>",
		["<Space>"] = "<Space>",
	}

	for phys_char, _ in pairs(map) do
		local ws_mapping = whitespace_map[phys_char]
		if ws_mapping then
			res[phys_char] = ws_mapping
		end
	end
	return res
end

--- Automatically maps common bracket pairs (parentheses, square brackets, curly braces, angle brackets).
--- Ensures shifted versions of brackets are also mapped.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with bracket mappings
---
--- HOW IT WORKS:
--- - Defines bracket pairs: [], (), {}, <>
--- - Checks if both open and close brackets are in base map
--- - If found, adds uppercase (shifted) versions
---
--- EXAMPLE:
--- - Input: {['х'] = '[', 'ъ'] = ']'}
--- - Output adds: {['Х'] = '{', 'Ъ'] = '}'}
---
--- LIMITATIONS:
--- - Only handles standard bracket pairs
--- - Assumes shifted brackets follow standard US layout
--- - May not work for layouts with different bracket positions
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

--- Automatically creates visual mode mappings based on normal mode mappings.
--- Ensures character motions work consistently across normal and visual modes.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Same mapping table (visual mode handled by LayoutHandler)
---
--- HOW IT WORKS:
--- - Currently returns a copy of the base map
--- - LayoutHandler applies these mappings to visual mode when activating layout
---
--- EXAMPLE:
--- - Input: {['ф'] = 'a'}
--- - Output: {['ф'] = 'a'} (applied to visual mode by LayoutHandler)
---
--- LIMITATIONS:
--- - Does not create visual-mode-specific mappings
--- - Some visual mode commands may need special handling
--- - Works best for character-based motions and operations
function M.autoVisualDuplicate(map)
	local res = vim.deepcopy(map)
	-- Visual mode mappings are typically the same as normal mode
	-- for character-based motions and operations
	-- This ensures consistent behavior when selecting text
	return res
end

--- Automatically creates insert mode mappings based on normal mode mappings.
--- Ensures character input works consistently in insert mode.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Same mapping table (insert mode handled by LayoutHandler)
---
--- HOW IT WORKS:
--- - Currently returns a copy of the base map
--- - LayoutHandler applies these mappings to insert mode when activating layout
---
--- EXAMPLE:
--- - Input: {['ф'] = 'a'}
--- - Output: {['ф'] = 'a'} (applied to insert mode by LayoutHandler)
---
--- LIMITATIONS:
--- - Does not create insert-mode-specific mappings
--- - Some insert mode commands may need special handling
--- - Use exclude_insert option if you don't want insert mode mappings
function M.autoInsertNormalDuplicate(map)
	local res = vim.deepcopy(map)
	-- Insert mode mappings are typically the same as normal mode
	-- for direct character input
	-- This ensures that typing in insert mode produces correct characters
	return res
end

--- Excludes insert mode from the vim_mode list when creating mappings.
--- Signals to LayoutHandler to skip insert mode when activating layout.
---
--- @param map table<string, string> Base character mapping table (ignored)
--- @return table<string, string> Empty table (marker only)
---
--- HOW IT WORKS:
--- - Returns empty table as marker
--- - LayoutHandler checks for this option and filters out 'i' mode
---
--- USE CASE:
--- - When you want layout translation in normal/visual modes but not insert mode
--- - Useful for users who prefer native layout for typing
---
--- LIMITATIONS:
--- - Only affects mapping creation, not runtime behavior
--- - Does not prevent insert mode mappings from other sources
function M.excludeInsert(map)
	_ = map
	-- This option doesn't add mappings, but signals to remove 'i' mode
	-- from vim_mode list during mapping creation
	-- The actual filtering is handled in LayoutHandler:_activateLayout
	-- Add a marker to the map so LayoutHandler can detect it
	return { ["_EXCLUDE_INSERT_MARKER_"] = "_EXCLUDE_INSERT_MARKER_" }
end

--- Automatically handles AltGr (Right Alt) modifier combinations for European layouts.
--- Creates mappings for AltGr-based special characters (€, @, #, etc.).
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with AltGr combinations
---
--- HOW IT WORKS:
--- - For each character mapping, creates <A-key> and <C-A-key> variants
--- - AltGr is represented as Alt or Ctrl+Alt in Vim/X11
---
--- EXAMPLE:
--- - Input: {['e'] = 'e'} (German layout with AltGr+e = €)
--- - Output adds: {['<A-e>'] = '<A-e>', ['<C-A-e>'] = '<C-A-e>'}
---
--- LIMITATIONS:
--- - Does not map specific AltGr characters (e.g., AltGr+e -> €)
--- - Only creates modifier passthrough mappings
--- - May conflict with existing Alt-based shortcuts
--- - Behavior varies by OS and keyboard driver
function M.autoAltGr(map)
	local res = vim.deepcopy(map)
	-- AltGr (Right Alt) is represented as <A-> or <C-A-> in Vim
	-- European layouts use AltGr for special characters like €, @, #, etc.
	for phys_char, en_char in pairs(map) do
		-- AltGr combinations are often represented as Ctrl+Alt in X11
		-- So we create both <A-key> and <C-A-key> mappings
		local lhs_altgr = "<A-" .. phys_char .. ">"
		local rhs_altgr = "<A-" .. en_char .. ">"
		res[lhs_altgr] = rhs_altgr

		-- Some systems represent AltGr as Ctrl+Alt
		local lhs_ctrl_alt = "<C-A-" .. phys_char .. ">"
		local rhs_ctrl_alt = "<C-A-" .. en_char .. ">"
		res[lhs_ctrl_alt] = rhs_ctrl_alt
	end
	return res
end

--- Automatically handles dead key combinations for layouts that use them.
--- Dead keys modify the next character typed (used in French, Spanish, German).
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with dead key combinations
---
--- HOW IT WORKS:
--- - Defines common dead key combinations (acute, grave, circumflex, tilde, umlaut)
--- - For each combo, checks if base character exists in map
--- - If found, adds the accented result mapping
---
--- EXAMPLE:
--- - Input: {['a'] = 'a'}
--- - Output adds: {['´a'] = 'á', ['`a'] = 'à', ['^a'] = 'â', ['~a'] = 'ã', ['"a'] = 'ä'}
---
--- LIMITATIONS:
--- - Only handles predefined dead key combinations
--- - Does not handle all possible dead key sequences
--- - Dead key behavior varies by OS and IME
--- - May not work with all terminal emulators
function M.autoDeadKeys(map)
	local res = vim.deepcopy(map)
	-- Dead keys are special keys that modify the next character typed
	-- Common dead keys: ^ (circumflex), ` (grave), ´ (acute), ~ (tilde), ¨ (diaeresis/umlaut)
	-- These are used in French, Spanish, Portuguese, German and other layouts

	-- Map common dead key combinations
	local dead_key_combos = {
		-- Acute accent combinations (´)
		["´a"] = "á",
		["´e"] = "é",
		["´i"] = "í",
		["´o"] = "ó",
		["´u"] = "ú",
		["´y"] = "ý",
		-- Grave accent combinations (`)
		["`a"] = "à",
		["`e"] = "è",
		["`i"] = "ì",
		["`o"] = "ò",
		["`u"] = "ù",
		-- Circumflex combinations (^)
		["^a"] = "â",
		["^e"] = "ê",
		["^i"] = "î",
		["^o"] = "ô",
		["^u"] = "û",
		-- Tilde combinations (~)
		["~a"] = "ã",
		["~n"] = "ñ",
		["~o"] = "õ",
		-- Diaeresis/Umlaut combinations (¨)
		['"a'] = "ä",
		['"e'] = "ë",
		['"i'] = "ï",
		['"o'] = "ö",
		['"u'] = "ü",
		['"y'] = "ÿ",
		-- Ring combination (˚)
		["°a"] = "å",
		-- Cedilla combination (¸)
		["¸c"] = "ç",
	}

	-- Create mappings for dead key combinations if base characters exist
	for combo, result in pairs(dead_key_combos) do
		-- Check if the base character is in the map
		local base_char = combo:sub(2, 2)
		if map[base_char] then
			res[combo] = result
		end
	end

	return res
end

--- Automatically handles accent combinations for accented characters.
--- Maps common precomposed accented characters to their base equivalents.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with accent mappings
---
--- HOW IT WORKS:
--- - Defines comprehensive accent map for European languages
--- - Includes: acute, grave, circumflex, tilde, umlaut, ring, cedilla, ligatures
--- - For each accented character in map, adds mapping to base character
---
--- EXAMPLE:
--- - Input: {['é'] = 'e', ['ü'] = 'u', ['ñ'] = 'n'}
--- - Output: {['é'] = 'e', ['ü'] = 'u', ['ñ'] = 'n'} (maps accents to base)
---
--- LIMITATIONS:
--- - Only handles predefined accented characters
--- - Does not handle all Unicode accented characters
--- - May conflict with auto_dead_keys for overlapping characters
--- - Ligature handling (æ, œ, ß) maps to multiple characters
function M.autoAccents(map)
	local res = vim.deepcopy(map)
	-- Maps common precomposed accented characters to their base equivalents
	-- This is useful for layouts where accented characters are directly available

	local accent_map = {
		-- Acute accents
		["á"] = "a",
		["é"] = "e",
		["í"] = "i",
		["ó"] = "o",
		["ú"] = "u",
		["ý"] = "y",
		["Á"] = "A",
		["É"] = "E",
		["Í"] = "I",
		["Ó"] = "O",
		["Ú"] = "U",
		["Ý"] = "Y",
		-- Grave accents
		["à"] = "a",
		["è"] = "e",
		["ì"] = "i",
		["ò"] = "o",
		["ù"] = "u",
		["À"] = "A",
		["È"] = "E",
		["Ì"] = "I",
		["Ò"] = "O",
		["Ù"] = "U",
		-- Circumflex
		["â"] = "a",
		["ê"] = "e",
		["î"] = "i",
		["ô"] = "o",
		["û"] = "u",
		["Â"] = "A",
		["Ê"] = "E",
		["Î"] = "I",
		["Ô"] = "O",
		["Û"] = "U",
		-- Tilde
		["ã"] = "a",
		["ñ"] = "n",
		["õ"] = "o",
		["Ã"] = "A",
		["Ñ"] = "N",
		["Õ"] = "O",
		-- Diaeresis/Umlaut
		["ä"] = "a",
		["ë"] = "e",
		["ï"] = "i",
		["ö"] = "o",
		["ü"] = "u",
		["ÿ"] = "y",
		["Ä"] = "A",
		["Ë"] = "E",
		["Ï"] = "I",
		["Ö"] = "O",
		["Ü"] = "U",
		["Ÿ"] = "Y",
		-- Ring
		["å"] = "a",
		["Å"] = "A",
		-- Cedilla
		["ç"] = "c",
		["Ç"] = "C",
		-- Ligatures
		["æ"] = "ae",
		["Æ"] = "AE",
		["œ"] = "oe",
		["Œ"] = "OE",
		["ß"] = "ss",
	}

	for phys_char, _ in pairs(map) do
		local base = accent_map[phys_char]
		if base then
			-- Map accented character to its base form
			res[phys_char] = base
		end
	end

	return res
end

--- Automatically handles ISO-specific special characters.
--- For ISO keyboards (common in Europe) with special keys near left Shift.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with ISO special mappings
---
--- HOW IT WORKS:
--- - Defines ISO special characters: < > | § ° ½ ¬ µ ² ³ ¹ € £ ¥ ¢
--- - Maps ISO characters to themselves or equivalent sequences
--- - Handles shifted versions of ISO special keys
---
--- EXAMPLE:
--- - Input: {['<'] = '<', ['>'] = '>', ['|'] = '|'} (German ISO)
--- - Output: Keeps ISO special characters mapped correctly
---
--- LIMITATIONS:
--- - Only handles predefined ISO special characters
--- - Shifted ISO mappings may vary by keyboard region
--- - Currency symbols (€ £ ¥) mapped to themselves
--- - May not work with all ISO keyboard variants
function M.autoIsoSpecials(map)
	local res = vim.deepcopy(map)
	-- ISO keyboards (common in Europe) have special keys near left Shift
	-- German: < > |, French: < > |, and other special characters

	local iso_specials = {
		-- Common ISO special characters
		["<"] = "<",
		[">"] = ">",
		["|"] = "|",
		["§"] = "§",
		["°"] = "°",
		["½"] = "½",
		["¬"] = "¬",
		["µ"] = "µ",
		["²"] = "²",
		["³"] = "³",
		["¹"] = "¹",
		["€"] = "€",
		["£"] = "£",
		["¥"] = "¥",
		["¢"] = "¢",
	}

	-- Map ISO special characters to themselves or to equivalent sequences
	for phys_char, _ in pairs(map) do
		local iso_mapping = iso_specials[phys_char]
		if iso_mapping then
			res[phys_char] = iso_mapping
		end
	end

	-- Also handle shifted versions of ISO special keys
	local iso_shift_map = {
		["<"] = ">",
		[">"] = "<",
		["|"] = "¦",
		["§"] = "°",
		["°"] = "§",
		["²"] = "³",
		["³"] = "²",
	}

	for phys_char, en_char in pairs(map) do
		local phys_shifted = iso_shift_map[phys_char]
		local en_shifted = iso_shift_map[en_char]
		if phys_shifted and en_shifted then
			res[phys_shifted] = en_shifted
		end
	end

	return res
end

--- Automatically creates noremap (non-recursive) variants of mappings.
--- Currently a marker for future expansion.
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Same mapping table (marker only)
---
--- HOW IT WORKS:
--- - Currently returns copy of base map without changes
--- - Reserved for future noremap-specific handling
---
--- LIMITATIONS:
--- - Currently does not create separate noremap variants
--- - Noremap behavior controlled by nvim_buf_set_keymap options
--- - May be expanded in future versions
function M.autoNoremapVariants(map)
	local res = vim.deepcopy(map)
	-- Creates noremap (non-recursive) variants of mappings
	-- This is handled by the noremap option in nvim_buf_set_keymap
	-- This option serves as a marker for potential future expansion
	-- where different mapping strategies might be needed
	return res
end

--- Automatically handles numeric keypad mappings.
--- Maps keypad number keys (KP0-KP9) and operations (KP+, KP-, KP*, KP/).
---
--- @param map table<string, string> Base character mapping table
--- @return table<string, string> Extended mapping table with keypad mappings
---
--- HOW IT WORKS:
--- - Defines keypad keys: KP0-KP9, KPDecimal, KPAdd, KPSubtract, KPMultiply, KPDivide, KPEnter, KPEqual
--- - For each keypad key in base map, ensures proper mapping
---
--- EXAMPLE:
--- - Input: {['<KP0>'] = '<KP0>', ['<KPAdd>'] = '<KPAdd>'}
--- - Output: Keeps keypad keys mapped correctly
---
--- LIMITATIONS:
--- - Only handles predefined keypad keys
--- - Does not handle keypad-specific behaviors
--- - May not work with all terminal emulators
--- - Keypad behavior varies by system
function M.autoKeypad(map)
	local res = vim.deepcopy(map)
	-- Maps keypad number keys and operations
	-- Useful for layouts where keypad should follow same translation

	local keypad_map = {
		["<KP0>"] = "<KP0>",
		["<KP1>"] = "<KP1>",
		["<KP2>"] = "<KP2>",
		["<KP3>"] = "<KP3>",
		["<KP4>"] = "<KP4>",
		["<KP5>"] = "<KP5>",
		["<KP6>"] = "<KP6>",
		["<KP7>"] = "<KP7>",
		["<KP8>"] = "<KP8>",
		["<KP9>"] = "<KP9>",
		["<KPDecimal>"] = "<KPDecimal>",
		["<KPAdd>"] = "<KPAdd>",
		["<KPSubtract>"] = "<KPSubtract>",
		["<KPMultiply>"] = "<KPMultiply>",
		["<KPDivide>"] = "<KPDivide>",
		["<KPEnter>"] = "<KPEnter>",
		["<KPEqual>"] = "<KPEqual>",
	}

	for phys_char, _ in pairs(map) do
		local kp_mapping = keypad_map[phys_char]
		if kp_mapping then
			res[phys_char] = kp_mapping
		end
	end

	return res
end

--- Automatically detects and translates existing leader key mappings.
--- Scans for mappings that use <leader> and creates translated versions.
---
--- HOW IT WORKS:
--- - Returns marker "_LEADER_MAPPING_MARKER_" to signal LayoutHandler
--- - LayoutHandler scans existing mappings for leader-based sequences
--- - Creates translated versions using reverse character map
---
--- EXAMPLE:
--- - Original: <leader>yy → %y (yank paragraph)
--- - With map['н'] = 'n': creates <leader>нн → %y
---
--- IMPORTANT:
--- - Must be called AFTER other plugins set up their mappings
--- - Call layout:formMap() again after loading other plugins
--- - Or use delayed initialization
---
--- LIMITATIONS:
--- - Only works with standard leader key format
--- - Does not handle recursive mappings (noremap=false)
--- - May create duplicate mappings if called multiple times
--- - Performance impact: scans all existing mappings
---@param map table<string, string> Base character mapping table
---@return table<string, string> Marker table (actual translation in LayoutHandler)
function M.autoLeaderMappings(map)
	local res = vim.deepcopy(map)
	-- This function doesn't add mappings directly to the map
	-- Instead, it returns a marker that signals LayoutHandler to process leader mappings
	-- The actual leader mapping translation happens in LayoutHandler:_activateLayout
	res["_LEADER_MAPPING_MARKER_"] = "_LEADER_MAPPING_MARKER_"
	return res
end

--- Automatically detects and translates existing buffer-local and global mappings.
--- Similar to autoLeaderMappings but works for all mappings, not just leader-based.
---
--- HOW IT WORKS:
--- - Returns marker "_EXISTING_MAPPING_MARKER_" to signal LayoutHandler
--- - LayoutHandler scans all existing mappings
--- - Creates translated versions using reverse character map
---
--- WARNING:
--- - This can create a large number of mappings
--- - May have performance impact with many plugins
---
---@param map table<string, string> Base character mapping table
---@return table<string, string> Marker table (actual translation in LayoutHandler)
function M.autoExistingMappings(map)
	local res = vim.deepcopy(map)
	-- This function doesn't add mappings directly to the map
	-- Instead, it returns a marker that signals LayoutHandler to process all existing mappings
	-- The actual mapping translation happens in LayoutHandler:_activateLayout
	res["_EXISTING_MAPPING_MARKER_"] = "_EXISTING_MAPPING_MARKER_"
	return res
end

--- Gets the namespace ID for the layout mappings.
---@return number|nil The namespace ID or nil if not set
function M:getNsIdMappings()
	return self._ns_id_mappings
end

--- Sets the namespace ID for the layout mappings.
---@param ns_id number|nil The namespace ID to set
---@return boolean True if successful, false otherwise
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
