local layouts = require("physical-keyboard.layouts")

local M = {}

M.defaults = {
	config_file = false,
	env = true,
	enable = true,
	notify = "errors",
	active_layouts = { "ru" },
	fallback = "unique",
	toggle_key = false,
	detect = {
		enabled = true,
		provider = nil,
		providers = nil,
		remote = "auto",
		min_interval = 300,
		timeout = 500,
		events = { "FocusGained", "VimResume", "InsertLeave" },
		async = true,
		on_change = nil,
	},
	langmap = {
		enabled = true,
	},
	mappings = {
		enabled = true,
		hack_keymap = true,
		automapping = true,
		modes = { "n", "x", "s", "o" },
		exclude = {},
		extra = {},
	},
	cmdline = {
		enabled = true,
		aliases = {},
		extra = {},
	},
	echo = {
		enabled = false,
		mode = "all",
	},
}

local KNOWN = {
	top = {
		config_file = true,
		env = true,
		enable = true,
		enabled = true,
		notify = true,
		active_layouts = true,
		layouts = true,
		fallback = true,
		toggle_key = true,
		detect = true,
		langmap = true,
		mappings = true,
		cmdline = true,
		echo = true,
		userLayouts = true,
		user_layouts = true,
	},
	detect = {
		enabled = true,
		provider = true,
		providers = true,
		remote = true,
		min_interval = true,
		timeout = true,
		events = true,
		async = true,
		on_change = true,
	},
	langmap = { enabled = true },
	mappings = {
		enabled = true,
		hack_keymap = true,
		automapping = true,
		modes = true,
		exclude = true,
		extra = true,
	},
	cmdline = { enabled = true, aliases = true, extra = true },
	echo = { enabled = true, mode = true },
}

local NOTIFY_MODES = {
	all = true,
	errors = true,
	off = true,
}

local ALLOWED_MODES = {
	n = true,
	x = true,
	s = true,
	o = true,
	i = true,
	c = true,
	t = true,
}

local function is_list(value)
	if next(value) == nil then
		return false
	end
	if vim.islist then
		return vim.islist(value)
	end
	local count = 0
	for _ in pairs(value) do
		count = count + 1
	end
	return count > 0 and value[1] ~= nil
end

local function merge(base, override)
	if type(base) ~= "table" or type(override) ~= "table" then
		return vim.deepcopy(override)
	end

	if is_list(base) or is_list(override) then
		return vim.deepcopy(override)
	end

	local result = vim.deepcopy(base)
	for key, value in pairs(override) do
		if type(value) == "table" and type(result[key]) == "table" then
			result[key] = merge(result[key], value)
		else
			result[key] = vim.deepcopy(value)
		end
	end
	return result
end

local function truthy(value)
	if value == nil then
		return false
	end
	if type(value) == "boolean" then
		return value
	end
	local lowered = tostring(value):lower()
	return lowered == "1" or lowered == "true" or lowered == "yes" or lowered == "on"
end

local function normalize_notify(value, warnings)
	if value == nil then
		return M.defaults.notify
	end
	if type(value) == "boolean" then
		return value and "all" or "errors"
	end
	local lowered = tostring(value):lower()
	if lowered == "true" or lowered == "always" then
		return "all"
	elseif lowered == "false" or lowered == "warn" or lowered == "warning" then
		return "errors"
	elseif lowered == "none" or lowered == "silent" or lowered == "quiet" then
		return "off"
	elseif NOTIFY_MODES[lowered] then
		return lowered
	end
	warnings[#warnings + 1] = ("unknown notify mode '%s', using '%s'"):format(
		tostring(value),
		M.defaults.notify
	)
	return M.defaults.notify
end

---@param mode string|nil
---@param level integer
---@return boolean
function M.should_notify(mode, level)
	if mode == "off" then
		return false
	end
	if mode == "all" then
		return true
	end
	return level >= vim.log.levels.WARN
end

---@return string
function M.default_file()
	return vim.fn.stdpath("config") .. "/physical-keyboard.lua"
end

---@param path string
---@return table|nil
---@return string|nil
function M.load_file(path)
	local chunk, err = loadfile(path)
	if not chunk then
		return nil, err
	end
	local ok, value = pcall(chunk)
	if not ok then
		return nil, tostring(value)
	end
	if type(value) == "function" then
		local ok_call, result = pcall(value)
		if not ok_call then
			return nil, tostring(result)
		end
		value = result
	end
	if type(value) ~= "table" then
		return nil, "config file must return a table"
	end
	return value
end

local function check_unknown(value, known, prefix, warnings)
	if type(value) ~= "table" then
		return
	end
	for key in pairs(value) do
		if not known[key] then
			warnings[#warnings + 1] = ("unknown config key '%s%s' ignored"):format(
				prefix,
				tostring(key)
			)
		end
	end
end

local function normalize_list(value)
	if value == nil or value == "" then
		return nil
	end
	if type(value) == "string" then
		return { value }
	end
	if type(value) == "table" then
		return vim.deepcopy(value)
	end
	return nil
end

local function normalize_aliases(value)
	if type(value) ~= "table" then
		return value
	end
	if value.enabled ~= nil and value.enable == nil then
		value.enable = value.enabled
	end
	value.enabled = nil
	if value.active_layouts == nil and value.layouts ~= nil then
		value.active_layouts = value.layouts
	end
	value.layouts = nil
	return value
end

local function normalize_active(value, warnings)
	if value == nil or value == "" then
		return layouts.ids()
	elseif type(value) == "string" then
		value = { value }
	elseif type(value) ~= "table" then
		warnings[#warnings + 1] = "active_layouts must be a string or a list"
		return layouts.ids()
	end

	if #value == 0 then
		return layouts.ids()
	end

	local valid = {}
	for _, id in ipairs(value) do
		if layouts.get(id) then
			valid[#valid + 1] = id
		else
			warnings[#warnings + 1] = ("unknown layout '%s' ignored"):format(tostring(id))
		end
	end

	if #valid == 0 then
		return layouts.ids()
	end
	return valid
end

local function normalize_modes(value, warnings)
	local modes = normalize_list(value) or vim.deepcopy(M.defaults.mappings.modes)
	local valid = {}
	for _, mode in ipairs(modes) do
		if ALLOWED_MODES[mode] then
			valid[#valid + 1] = mode
		else
			warnings[#warnings + 1] = ("unknown mapping mode '%s' ignored"):format(tostring(mode))
		end
	end
	if #valid == 0 then
		return vim.deepcopy(M.defaults.mappings.modes)
	end
	return valid
end

local function normalize_strings(value, name, warnings)
	local list = normalize_list(value) or {}
	local valid = {}
	for _, item in ipairs(list) do
		if type(item) == "string" and item ~= "" then
			valid[#valid + 1] = item
		else
			warnings[#warnings + 1] = ("%s must contain strings"):format(name)
		end
	end
	return valid
end

local function normalize_cmdline_extra(value, warnings)
	local aliases = {}
	local extra = {}
	if value == nil then
		return aliases, extra
	end
	if type(value) ~= "table" then
		warnings[#warnings + 1] = "cmdline.extra must be a list or a table"
		return aliases, extra
	end
	if is_list(value) then
		for _, item in ipairs(value) do
			if type(item) == "string" and item ~= "" then
				aliases[#aliases + 1] = item
			else
				warnings[#warnings + 1] = "cmdline.extra must contain strings"
			end
		end
		return aliases, extra
	end
	for native, english in pairs(value) do
		if type(native) == "string" and type(english) == "string" and native ~= "" and english ~= "" then
			extra[native] = english
		else
			warnings[#warnings + 1] = "cmdline.extra must map native keys to English commands"
		end
	end
	return aliases, extra
end

local function apply_env(result, warnings, used)
	if result.env == false then
		return
	end

	if truthy(vim.env.PKB_DISABLE) then
		result.enable = false
		used.disable = true
	end

	local layout = vim.env.PKB_LAYOUT
	if layout and layout ~= "" then
		local ids = {}
		for item in layout:gmatch("[^,%s]+") do
			ids[#ids + 1] = item
		end
		if #ids > 0 then
			local first = ids[1]:lower()
			if #ids == 1 and (first == "en" or first == "us" or first == "english") then
				result.env_layout = first
			else
				result.active_layouts = ids
				result.env_layout = ids[1]
			end
			used.layout = layout
		end
	end

	if vim.env.PKB_NOTIFY and vim.env.PKB_NOTIFY ~= "" then
		result.notify = normalize_notify(vim.env.PKB_NOTIFY, warnings)
		used.notify = vim.env.PKB_NOTIFY
	end

	if truthy(vim.env.PKB_DEBUG) then
		result.echo.enabled = true
		result.echo.mode = "debug"
		result.notify = "all"
		used.debug = true
	end
end

---@param opts table|nil
---@return table
function M.resolve(opts)
	opts = vim.deepcopy(opts or {})

	local warnings = {}
	local used = {}

	local explicit_file = opts.config_file
	if
		explicit_file ~= nil
		and explicit_file ~= false
		and explicit_file ~= true
		and type(explicit_file) ~= "string"
	then
		warnings[#warnings + 1] = "config_file must be false, true or a path"
		explicit_file = false
	end
	local file_path = nil
	if explicit_file == false then
		file_path = nil
	elseif explicit_file == true then
		file_path = M.default_file()
	elseif type(explicit_file) == "string" and explicit_file ~= "" then
		file_path = explicit_file
	elseif opts.env ~= false and vim.env.PKB_CONFIG and vim.env.PKB_CONFIG ~= "" then
		file_path = vim.env.PKB_CONFIG
		used.config = true
	end

	local attempted_file = nil
	local file_opts = nil
	if file_path then
		file_path = vim.fn.expand(file_path)
		attempted_file = file_path
		if vim.fn.filereadable(file_path) == 1 then
			local err
			file_opts, err = M.load_file(file_path)
			if not file_opts then
				warnings[#warnings + 1] = ("config file '%s': %s"):format(
					file_path,
					tostring(err)
				)
				file_path = nil
			end
		else
			warnings[#warnings + 1] = ("config file '%s' does not exist"):format(file_path)
			file_path = nil
		end
	end

	-- Accept both old and new spellings.
	normalize_aliases(opts)
	if file_opts then
		normalize_aliases(file_opts)
	end

	local custom = opts.userLayouts or opts.user_layouts
	opts.userLayouts = nil
	opts.user_layouts = nil
	if custom ~= nil and type(custom) ~= "table" then
		warnings[#warnings + 1] = "userLayouts must be a table"
		custom = nil
	end

	local file_custom = file_opts and (file_opts.userLayouts or file_opts.user_layouts) or nil
	if file_custom ~= nil and type(file_custom) ~= "table" then
		warnings[#warnings + 1] = "config file userLayouts must be a table"
		file_custom = nil
	end

	local result = merge(M.defaults, file_opts or {})
	opts.config_file = nil
	result = merge(result, opts)

	if type(custom) == "table" or type(file_custom) == "table" then
		local merged_custom = {}
		if type(file_custom) == "table" then
			for id, def in pairs(file_custom) do
				merged_custom[id] = def
			end
		end
		if type(custom) == "table" then
			for id, def in pairs(custom) do
				merged_custom[id] = def
			end
		end
		for id, definition in pairs(merged_custom) do
			local ok, err = layouts.register(id, definition)
			if not ok then
				warnings[#warnings + 1] = ("custom layout '%s': %s"):format(id, err)
			end
		end
	end

	for _, section in ipairs({ "detect", "langmap", "mappings", "cmdline", "echo" }) do
		if type(result[section]) ~= "table" then
			warnings[#warnings + 1] = ("'%s' must be a table, using defaults"):format(section)
			result[section] = vim.deepcopy(M.defaults[section])
		end
	end

	check_unknown(opts, KNOWN.top, "", warnings)
	check_unknown(file_opts or {}, KNOWN.top, "", warnings)
	check_unknown(result.detect, KNOWN.detect, "detect.", warnings)
	check_unknown(result.langmap, KNOWN.langmap, "langmap.", warnings)
	check_unknown(result.mappings, KNOWN.mappings, "mappings.", warnings)
	check_unknown(result.cmdline, KNOWN.cmdline, "cmdline.", warnings)
	check_unknown(result.echo, KNOWN.echo, "echo.", warnings)

	result.notify = normalize_notify(result.notify, warnings)
	result.active_layouts = normalize_active(result.active_layouts, warnings)
	result.mappings.modes = normalize_modes(result.mappings.modes, warnings)
	result.mappings.exclude = normalize_strings(result.mappings.exclude, "mappings.exclude", warnings)

	if type(result.mappings.extra) ~= "table" then
		warnings[#warnings + 1] = "mappings.extra must be a table"
		result.mappings.extra = {}
	end

	result.cmdline.aliases = normalize_strings(result.cmdline.aliases, "cmdline.aliases", warnings)
	local extra_aliases, extra_pairs = normalize_cmdline_extra(result.cmdline.extra, warnings)
	for _, alias in ipairs(extra_aliases) do
		result.cmdline.aliases[#result.cmdline.aliases + 1] = alias
	end
	result.cmdline.extra = extra_pairs

	if result.fallback ~= "unique" and result.fallback ~= false and result.fallback ~= nil then
		if type(result.fallback) ~= "string" or not layouts.get(result.fallback) then
			warnings[#warnings + 1] = ("unknown fallback '%s', using 'unique'"):format(
				tostring(result.fallback)
			)
			result.fallback = "unique"
		end
	end

	if type(result.detect.min_interval) ~= "number" or result.detect.min_interval < 0 then
		warnings[#warnings + 1] = "detect.min_interval must be a non-negative number"
		result.detect.min_interval = M.defaults.detect.min_interval
	end
	if type(result.detect.timeout) ~= "number" or result.detect.timeout <= 0 then
		warnings[#warnings + 1] = "detect.timeout must be a positive number"
		result.detect.timeout = M.defaults.detect.timeout
	end
	if result.detect.remote ~= "auto" and result.detect.remote ~= true and result.detect.remote ~= false then
		warnings[#warnings + 1] = "detect.remote must be 'auto', true or false"
		result.detect.remote = M.defaults.detect.remote
	end
	if result.detect.events ~= nil then
		result.detect.events = normalize_strings(result.detect.events, "detect.events", warnings)
	end
	if result.detect.providers ~= nil then
		result.detect.providers = normalize_strings(result.detect.providers, "detect.providers", warnings)
	end
	if result.detect.provider ~= nil and type(result.detect.provider) ~= "string" then
		warnings[#warnings + 1] = "detect.provider must be a string"
		result.detect.provider = nil
	end
	if result.detect.on_change ~= nil and type(result.detect.on_change) ~= "function" then
		warnings[#warnings + 1] = "detect.on_change must be a function"
		result.detect.on_change = nil
	end

	if result.toggle_key ~= nil and type(result.toggle_key) ~= "string" and result.toggle_key ~= false then
		warnings[#warnings + 1] = "toggle_key must be a string or false"
		result.toggle_key = false
	end

	result.config_file = file_path or attempted_file or false
	result.env = result.env ~= false
	result.warnings = warnings
	result.source = {
		file = file_path,
		attempted = attempted_file,
		env = used,
	}

	apply_env(result, warnings, used)
	result.source.file = file_path
	result.source.attempted = attempted_file
	result.source.env = used

	-- Environment overrides may change active layouts, so normalize again.
	if used.layout then
		local requested = result.env_layout
		result.active_layouts = normalize_active(result.active_layouts, warnings)
		if requested and layouts.get(requested) then
			result.env_layout = requested
		elseif requested and (requested:lower() == "en" or requested:lower() == "us") then
			result.env_layout = requested
		else
			result.env_layout = nil
		end
	end

	return result
end

--- Returns a JSON-safe copy of a config table.
---@param value any
---@return any
function M.sanitize(value)
	if type(value) == "function" then
		return "<function>"
	end
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, item in pairs(value) do
		result[key] = M.sanitize(item)
	end
	return result
end

return M
