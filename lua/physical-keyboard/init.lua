local config = require("physical-keyboard.config")
local layouts = require("physical-keyboard.layouts")
local langmap = require("physical-keyboard.langmap")
local detect = require("physical-keyboard.detect")
local mappings = require("physical-keyboard.mappings")
local cmdline = require("physical-keyboard.cmdline")
local echo = require("physical-keyboard.echo")
local commands = require("physical-keyboard.commands")
local options = require("physical-keyboard.options")
local overrides_store = require("physical-keyboard.overrides")

--- physical-keyboard.nvim
---
--- Translates Normal/Visual/Operator-pending keys and plugin mappings from a
--- national keyboard layout to the equivalent English keys, so `ciw`, `gcc` or
--- a plugin's `<leader>ff` keep working without switching layouts.
local M = {
	version = "1.1.0",
	config = nil,
	_enabled = false,
	_notify_mode = "errors",
	_forced = nil,
	_forced_english = false,
	_current_layout = nil,
	_detected_english = false,
	_extra_layouts = {},
	_extra_set = {},
	_last_detect = { provider = nil, raw = nil, layout = nil, english = false },
	_setup_opts = nil,
	_session_overrides = {},
	_toggle_key = nil,
	_apply_generation = 0,
}

local function is_active_layout(id)
	for _, value in ipairs((M.config and M.config.active_layouts) or {}) do
		if value == id then
			return true
		end
	end
	return false
end

--- Runtime set of layouts: configured layouts plus layouts discovered by the
--- detection layer (for example a German OS layout with the default `{ "ru" }`
--- configuration).
---@return string[]
function M.effective_layouts()
	local result = {}
	local seen = {}

	local function add(id)
		if id and not seen[id] and layouts.get(id) then
			seen[id] = true
			result[#result + 1] = id
		end
	end

	for _, id in ipairs((M.config and M.config.active_layouts) or {}) do
		add(id)
	end
	for _, id in ipairs(M._extra_layouts) do
		add(id)
	end

	return result
end

local function adopt_layout(id)
	if not id or not layouts.get(id) or is_active_layout(id) or M._extra_set[id] then
		return false
	end

	M._extra_set[id] = true
	M._extra_layouts[#M._extra_layouts + 1] = id

	local ids = M.effective_layouts()
	mappings.rebuild(ids)
	cmdline.set_active_ids(ids)
	if M._enabled and M.config and M.config.cmdline.enabled then
		cmdline.disable()
		cmdline.enable()
	end

	vim.schedule(function()
		if M._enabled then
			M.refresh_mappings()
		end
	end)

	return true
end

---@param message string
---@param level integer|nil
function M.notify(message, level)
	level = level or vim.log.levels.INFO
	if not config.should_notify(M._notify_mode, level) then
		return
	end
	vim.notify("[physical-keyboard] " .. message, level)
end

--- Always shows a message, regardless of the `notify` option.
--- Used by user commands.
---@param message string
---@param level integer|nil
function M.print(message, level)
	vim.notify("[physical-keyboard] " .. message, level or vim.log.levels.INFO)
end

---@param name string
---@param data table|nil
function M.emit(name, data)
	vim.schedule(function()
		pcall(vim.api.nvim_exec_autocmds, "User", {
			pattern = "PhysicalKeyboard" .. name,
			modeline = false,
			data = data or {},
		})
	end)
end

local function detected_or_last()
	return M._last_detect
		or detect.last()
		or { provider = nil, raw = nil, layout = nil, english = false }
end

local function set_langmap(value)
	local ok, err = langmap.set(value)
	if not ok then
		M.notify("Failed to apply 'langmap': " .. tostring(err), vim.log.levels.ERROR)
	end
	return ok
end

---@return table
function M.layout_info()
	local detected = detected_or_last()
	return {
		id = M._current_layout,
		layout = M._current_layout,
		english = M._detected_english,
		raw = detected.raw,
		provider = detected.provider,
		forced = M._forced or (M._forced_english and "en" or nil),
	}
end

---@return string|nil
function M.current_layout()
	return M._current_layout
end

--- A ready-to-use statusline component.
---@param opts table|nil
---@return string
function M.statusline(opts)
	opts = opts or {}
	local info = M.layout_info()
	local prefix = opts.prefix or ""
	local suffix = opts.suffix or ""
	if info.id then
		local text = opts.uppercase == false and info.id or info.id:upper()
		return prefix .. text .. suffix
	end
	if info.english then
		return prefix .. (opts.english or "EN") .. suffix
	end
	return prefix .. (opts.unknown or "--") .. suffix
end

local function emit_layout_change(info, previous_id, previous_english)
	vim.g.physical_keyboard_layout = info.id or (info.english and "en") or ""
	if info.id == previous_id and info.english == previous_english then
		return
	end

	local cfg = M.config
	local data = {
		id = info.id,
		layout = info.id,
		english = info.english,
		raw = info.raw,
		provider = info.provider,
		forced = info.forced,
	}
	M.emit("LayoutChanged", data)
	if cfg and type(cfg.detect.on_change) == "function" then
		vim.schedule(function()
			pcall(cfg.detect.on_change, data)
		end)
	end
end

local function apply_detected(detected)
	local cfg = M.config
	if not M._enabled or not cfg then
		return
	end

	local previous_id = M._current_layout
	local previous_english = M._detected_english
	M._current_layout = nil
	M._detected_english = false
	M._last_detect = detected

	if not cfg.langmap.enabled then
		emit_layout_change(M.layout_info(), previous_id, previous_english)
		return
	end

	if detected.english then
		set_langmap("")
		M._detected_english = true
	elseif detected.layout then
		adopt_layout(detected.layout)
		set_langmap(langmap.build({ detected.layout }, false))
		M._current_layout = detected.layout
	else
		local effective = M.effective_layouts()

		if cfg.fallback == "unique" then
			local unique = #effective > 1
			set_langmap(langmap.build(effective, unique))
			if #effective == 1 then
				M._current_layout = effective[1]
			end
		elseif type(cfg.fallback) == "string" and layouts.get(cfg.fallback) then
			set_langmap(langmap.build({ cfg.fallback }, false))
			M._current_layout = cfg.fallback
		else
			set_langmap("")
		end
	end

	emit_layout_change(M.layout_info(), previous_id, previous_english)
end

local function apply_langmap(force)
	local cfg = M.config
	if not M._enabled or not cfg then
		return
	end

	local detected
	if M._forced then
		detected = {
			provider = "override",
			raw = M._forced,
			layout = M._forced,
			english = false,
		}
	elseif M._forced_english then
		detected = {
			provider = "override",
			raw = "en",
			layout = nil,
			english = true,
		}
	elseif cfg.detect.enabled then
		detected = detect.detect(force)
	else
		detected = { provider = nil, raw = nil, layout = nil, english = false, disabled = "config" }
	end

	apply_detected(detected)
end

local function refresh_async(force)
	local cfg = M.config
	if not M._enabled or not cfg then
		return
	end
	if M._forced or M._forced_english or not cfg.detect.enabled or not cfg.detect.async then
		apply_langmap(force)
		return
	end

	local generation = M._apply_generation
	detect.detect_async(force, function(result)
		if not M._enabled or generation ~= M._apply_generation then
			return
		end
		if M._forced or M._forced_english then
			return
		end
		apply_detected(result)
	end)
end

local function automap_global(force)
	local cfg = M.config
	if not M._enabled or not cfg or not cfg.mappings.enabled then
		return 0
	end
	if not force and not cfg.mappings.automapping then
		return 0
	end
	return mappings.automapping({ global = true })
end

local function automap_buffer(bufnr, force)
	local cfg = M.config
	if not M._enabled or not cfg or not cfg.mappings.enabled then
		return 0
	end
	if not force and not cfg.mappings.automapping then
		return 0
	end
	return mappings.automapping({ buffer = true, bufnr = bufnr })
end

local function schedule_automap()
	vim.schedule(function()
		automap_global()
		for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
			if vim.api.nvim_buf_is_loaded(bufnr) then
				automap_buffer(bufnr)
			end
		end
	end)
end

local function setup_autocmds()
	local cfg = M.config
	local group = vim.api.nvim_create_augroup("PhysicalKeyboard", { clear = true })

	local function refresh()
		if not M._enabled or M._forced or M._forced_english then
			return
		end
		refresh_async(false)
	end

	if cfg.detect.enabled then
		local events = cfg.detect.events or { "FocusGained", "VimResume", "InsertLeave" }
		if #events > 0 then
			local ok, err = pcall(vim.api.nvim_create_autocmd, events, {
				group = group,
				callback = refresh,
			})
			if not ok then
				M.notify("Invalid detect.events: " .. tostring(err), vim.log.levels.WARN)
			end
		end
	end

	vim.api.nvim_create_autocmd("VimEnter", {
		group = group,
		once = true,
		callback = function()
			automap_global()
		end,
	})

	vim.api.nvim_create_autocmd({ "BufWinEnter", "FileType", "LspAttach" }, {
		group = group,
		callback = function(args)
			if args.buf and args.buf > 0 then
				vim.schedule(function()
					automap_buffer(args.buf)
				end)
			end
		end,
	})
end

--- Re-applies a resolved configuration without resetting runtime choices such
--- as a forced layout or layouts discovered by detection.
---@param cfg table
local function wire(cfg)
	M.config = cfg
	M._notify_mode = cfg.notify

	if M._enabled and not cfg.langmap.enabled then
		set_langmap("")
	end

	if not cfg.enable and M._enabled then
		M.disable()
	end

	echo.setup({
		notify = function(message)
			M.notify(message, vim.log.levels.INFO)
		end,
		mode = cfg.echo.mode,
	})
	echo.enable(not not cfg.echo.enabled)

	detect.setup({
		enabled = cfg.detect.enabled,
		min_interval = cfg.detect.min_interval,
		timeout = cfg.detect.timeout,
		provider = cfg.detect.provider,
		providers = cfg.detect.providers,
		remote = cfg.detect.remote,
		async = cfg.detect.async,
		active_ids = M.effective_layouts(),
	})

	mappings.cleanup()
	mappings.setup({
		enabled = cfg.mappings.enabled,
		modes = cfg.mappings.modes,
		exclude = cfg.mappings.exclude,
		extra = cfg.mappings.extra,
		active_ids = M.effective_layouts(),
	})
	if cfg.enable and cfg.mappings.enabled and cfg.mappings.hack_keymap then
		mappings.hack()
	else
		mappings.unhack()
	end

	cmdline.set_active_ids(M.effective_layouts())
	cmdline.disable()
	if cfg.enable and cfg.cmdline.enabled then
		cmdline.enable()
	end

	setup_autocmds()

	if M._toggle_key then
		pcall(vim.keymap.del, "n", M._toggle_key)
		M._toggle_key = nil
	end
	if type(cfg.toggle_key) == "string" and cfg.toggle_key ~= "" then
		local key = cfg.toggle_key
		vim.keymap.set("n", key, function()
			M.toggle()
		end, { desc = "Toggle physical-keyboard" })
		M._toggle_key = key
	end

	if cfg.enable then
		if not M._enabled then
			M.enable()
		else
			if cfg.mappings.enabled then
				M.refresh_mappings()
				if cfg.mappings.automapping then
					schedule_automap()
				end
			end
			M.refresh(true)
		end
	end
end

---@return table
function M.status()
	local cfg = M.config or config.resolve({})
	local detected = detected_or_last()
	local info = M.layout_info()

	return {
		enabled = M._enabled,
		version = M.version,
		active_layouts = M.config and M.effective_layouts() or cfg.active_layouts or {},
		forced_layout = M._forced or (M._forced_english and "en" or nil),
		current_layout = M._current_layout,
		english = M._detected_english,
		langmap_pairs = langmap.count(langmap.current()),
		detect = {
			provider = detected.provider,
			raw = detected.raw,
			layout = detected.layout,
			english = detected.english,
			disabled = detected.disabled,
			remote = detect.remote_disabled(),
			remote_session = detect.is_remote(),
			async = cfg.detect.async,
		},
		mappings = {
			hacked = mappings.is_hacked(),
			created = mappings.count_created(),
			excluded = #cfg.mappings.exclude,
		},
		cmdline = {
			enabled = cfg.cmdline.enabled,
			count = cmdline.count(),
			extra = vim.tbl_count(cmdline.extra()),
		},
		echo = {
			enabled = echo.is_enabled(),
			mode = echo.mode(),
		},
		config_source = cfg.source,
		config_file = cfg.config_file,
		overrides = {
			enabled = cfg.overrides and cfg.overrides.enabled or false,
			file = config.overrides_path(cfg.overrides),
			exists = overrides_store.exists(config.overrides_path(cfg.overrides)),
		},
		notify = M._notify_mode,
		layout = info,
		config = cfg,
	}
end

---@return string[]
function M.list_layouts()
	return layouts.ids()
end

---@param force boolean|nil
---@return table
function M.detect_now(force)
	if force then
		detect.invalidate()
	end
	local result = detect.detect(force)
	M._last_detect = result
	return result
end

---@param force boolean|nil
function M.refresh(force)
	M._apply_generation = M._apply_generation + 1
	apply_langmap(force)
end

---@param id string|nil
---@return boolean
function M.use_layout(id)
	if id == nil then
		M._apply_generation = M._apply_generation + 1
		M._forced = nil
		M._forced_english = false
		detect.set_override(nil)
		detect.invalidate()
		apply_langmap(true)
		M.notify("Automatic layout detection enabled")
		return true
	end

	local lowered = tostring(id):lower()
	if lowered == "en" or lowered == "us" or lowered == "english" then
		M._apply_generation = M._apply_generation + 1
		M._forced = nil
		M._forced_english = true
		detect.set_override(nil)
		detect.invalidate()
		apply_langmap(true)
		M.notify("Translation disabled (English layout)")
		return true
	end

	if not layouts.get(id) then
		return false
	end

	M._apply_generation = M._apply_generation + 1
	M._forced = id
	M._forced_english = false
	adopt_layout(id)
	detect.set_override(id)
	detect.invalidate()
	apply_langmap(true)
	M.notify("Using layout: " .. id)
	return true
end

---@return number
function M.refresh_mappings()
	mappings.rebuild(M.effective_layouts())
	local created = automap_global(true)
	for _, bufnr in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(bufnr) then
			created = created + automap_buffer(bufnr, true)
		end
	end
	return created
end

function M.enable()
	if M._enabled then
		return
	end

	local cfg = M.config or config.resolve({})
	M._enabled = true
	M._notify_mode = cfg.notify
	M._apply_generation = M._apply_generation + 1

	langmap.capture()

	mappings.rebuild(M.effective_layouts())
	if cfg.mappings.enabled and cfg.mappings.hack_keymap then
		mappings.hack()
	end

	apply_langmap(true)

	if cfg.cmdline.enabled then
		cmdline.set_active_ids(M.effective_layouts())
		cmdline.enable()
	end

	if cfg.mappings.enabled and cfg.mappings.automapping then
		schedule_automap()
	end

	M.emit("Enabled", {})
end

function M.disable()
	if not M._enabled then
		return
	end

	M._enabled = false
	M._apply_generation = M._apply_generation + 1
	detect.invalidate()

	mappings.unhack()
	mappings.cleanup()
	cmdline.disable()
	langmap.restore()
	M._current_layout = nil
	M._detected_english = false
	M._last_detect = { provider = nil, raw = nil, layout = nil, english = false }
	vim.g.physical_keyboard_layout = ""

	M.emit("Disabled", {})
end

---@return boolean enabled
function M.toggle()
	if M._enabled then
		M.disable()
	else
		M.enable()
	end
	return M._enabled
end

local function normalize_notify_mode(value)
	if value == nil then
		return M._notify_mode == "all" and "errors" or "all"
	end
	if type(value) == "boolean" then
		return value and "all" or "off"
	end
	local lowered = tostring(value):lower()
	if lowered == "on" or lowered == "true" or lowered == "all" or lowered == "always" then
		return "all"
	elseif lowered == "errors" or lowered == "warn" or lowered == "warning" then
		return "errors"
	elseif lowered == "off" or lowered == "false" or lowered == "none" or lowered == "silent" then
		return "off"
	end
	return M._notify_mode
end

---@param value boolean|string|nil
---@return string
function M.set_notify(value)
	local mode = normalize_notify_mode(value)
	M._notify_mode = mode
	if M.config then
		M.config.notify = mode
	end
	return mode
end

---@param value boolean|nil
---@return boolean
function M.set_cmdline(value)
	local cfg = M.config
	if not cfg then
		return false
	end
	if value == nil then
		value = not cfg.cmdline.enabled
	end
	cfg.cmdline.enabled = value
	cmdline.set_enabled(value)
	if value then
		cmdline.set_active_ids(M.effective_layouts())
		cmdline.enable()
	else
		cmdline.disable()
	end
	return value
end

---@param value boolean|nil
---@return boolean
function M.echo_toggle(value)
	local enabled = echo.enable(value)
	if M.config then
		M.config.echo.enabled = enabled
	end
	return enabled
end

---@param mode string|nil
---@return string|boolean
function M.echo_mode(mode)
	if mode == nil then
		return echo.mode()
	end
	local ok = echo.set_mode(mode)
	if ok and M.config then
		M.config.echo.mode = mode
	end
	return ok
end

---@param path string
---@return any
function M.get_option(path)
	local spec = options.spec(path)
	if not spec then
		return nil
	end
	local cfg = M.config or config.resolve(M._setup_opts or {}, M._session_overrides)
	return options.get(cfg, path)
end

--- Changes one whitelisted option at runtime and persists it to the override
--- file when override loading is enabled.
---@param path string
---@param value any
---@return boolean ok
---@return string|nil error
---@return boolean persisted
function M.set_option(path, value)
	local spec = options.spec(path)
	if not spec then
		return false, "unknown option: " .. tostring(path), false
	end

	local normalized, err, unset = options.normalize(spec, value)
	if err then
		return false, err, false
	end
	local stored = unset and nil or normalized

	local persist = not not (M.config and M.config.overrides and M.config.overrides.enabled)
	if persist then
		local file = config.overrides_path(M.config.overrides)
		local saved, save_err = overrides_store.set_value(path, stored, file)
		if not saved then
			return false, save_err, false
		end
	end

	if unset then
		overrides_store.unset_value_in(M._session_overrides, path)
	else
		overrides_store.set_value_in(M._session_overrides, path, stored)
	end

	M.config = config.resolve(M._setup_opts or {}, M._session_overrides)
	wire(M.config)
	M.emit("ConfigChanged", {
		path = path,
		value = stored,
		unset = unset,
		persisted = persist,
	})
	return true, nil, persist
end

---@return boolean
---@return string|nil
function M.reset_overrides()
	local path = config.overrides_path(M.config and M.config.overrides or nil)
	local ok, err = overrides_store.remove(path)
	if not ok then
		return false, err
	end
	M._session_overrides = {}
	M.config = config.resolve(M._setup_opts or {})
	wire(M.config)
	M.emit("ConfigChanged", { path = "<overrides>", value = nil, unset = true, persisted = true })
	return true, nil
end

---@return table
function M.overrides_info()
	local cfg = M.config or config.resolve(M._setup_opts or {}, M._session_overrides)
	local settings = cfg.overrides or { enabled = true }
	local path = config.overrides_path(settings)
	return {
		enabled = settings.enabled,
		file = path,
		exists = overrides_store.exists(path),
		values = (cfg.source and cfg.source.overrides) or {},
		session = vim.deepcopy(M._session_overrides or {}),
	}
end

---@return string
function M.config_file()
	if M.config and type(M.config.config_file) == "string" then
		return M.config.config_file
	end
	return config.default_file()
end

---@return boolean
function M.config_file_enabled()
	return not not (M.config and type(M.config.config_file) == "string")
end

local CONFIG_TEMPLATE = [[
-- physical-keyboard.nvim configuration
-- Docs: :help physical-keyboard-config
return {
  -- Layouts you use. An empty table enables every bundled layout.
  active_layouts = { "ru" },

  -- Detection runs automatically when an adapter is available.
  detect = {
    enabled = true,
    -- provider = "niri", -- force one adapter
    -- remote = "auto",   -- disable detection over SSH
  },

  -- mappings = { exclude = { "<leader>f" } },
  -- cmdline = { aliases = { "tabnew" } },
}
]]

--- Opens the external config file, creating a template when needed.
---@return string path
function M.edit_config()
	local path = M.config_file()
	local dir = vim.fn.fnamemodify(path, ":h")
	if dir ~= "" then
		vim.fn.mkdir(dir, "p")
	end
	if vim.fn.filereadable(path) == 0 then
		vim.fn.writefile(vim.split(CONFIG_TEMPLATE, "\n", { plain = true, trimempty = true }), path)
		M.notify("Created " .. path)
	end
	local open_ok, open_err = pcall(vim.cmd.edit, vim.fn.fnameescape(path))
	if not open_ok then
		M.notify("Could not open " .. path .. ": " .. tostring(open_err), vim.log.levels.ERROR)
	end
	if not M.config_file_enabled() then
		M.notify(
			"Set config_file = true in setup() (or PKB_CONFIG) to load this file",
			vim.log.levels.WARN
		)
	end
	return path
end

--- Re-runs setup() with the options passed to the first setup() call.
---@return boolean success
---@return string|nil error
function M.reload()
	if not M._setup_opts then
		return false, "setup() has not been called"
	end
	local ok, err = pcall(M.setup, vim.deepcopy(M._setup_opts))
	if not ok then
		return false, tostring(err)
	end
	M.emit("ConfigReloaded", { file = M.config and M.config.config_file or nil })
	M.print("Configuration reloaded")
	return true, nil
end

--- Machine-readable environment report for users and AI assistants.
---@param opts { probe: boolean|nil }|nil
---@return table
function M.doctor(opts)
	return require("physical-keyboard.doctor").collect(M, opts)
end

---@param opts table|nil
---@return table
function M.setup(opts)
	opts = opts or {}
	M._setup_opts = vim.deepcopy(opts)

	if M._enabled then
		M.disable()
	end

	M._session_overrides = {}
	M.config = config.resolve(opts)
	M._notify_mode = M.config.notify
	M._forced = nil
	M._forced_english = false
	M._current_layout = nil
	M._detected_english = false
	M._last_detect = { provider = nil, raw = nil, layout = nil, english = false }
	M._extra_layouts = {}
	M._extra_set = {}
	M._enabled = false
	M._apply_generation = M._apply_generation + 1
	vim.g.physical_keyboard_layout = ""

	for _, warning in ipairs(M.config.warnings or {}) do
		M.notify(warning, vim.log.levels.WARN)
	end

	if M.config.env_layout then
		local lowered = tostring(M.config.env_layout):lower()
		if lowered == "en" or lowered == "us" or lowered == "english" then
			M._forced_english = true
		else
			M._forced = M.config.env_layout
		end
	end

	if echo.is_enabled() then
		echo.enable(false)
	end

	cmdline.setup({
		enabled = M.config.cmdline.enabled,
		active_ids = M.config.active_layouts,
		aliases = M.config.cmdline.aliases,
		extra = M.config.cmdline.extra,
	})

	commands.register(M)
	wire(M.config)

	if M.config.enable then
		if M.config.echo.enabled then
			echo.enable(true)
		end
	else
		M.notify("Plugin is disabled (config.enable = false)", vim.log.levels.WARN)
	end

	return M
end

return M
