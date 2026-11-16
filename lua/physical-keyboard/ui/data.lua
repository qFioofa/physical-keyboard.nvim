local M = {}

local cache = nil
local on_change = nil
local probe_generation = 0

local state = {
	probe = {
		status = "idle",
		results = {},
		at = nil,
	},
}

local function safe_require(name)
	local ok, module = pcall(require, name)
	if ok then
		return module
	end
	return nil
end

local function safe_call(fn, ...)
	if type(fn) ~= "function" then
		return nil
	end
	local ok, value = pcall(fn, ...)
	if ok then
		return value
	end
	return nil
end

local function collect_layouts(ids)
	local layouts = safe_require("physical-keyboard.layouts")
	local result = {}
	if not layouts then
		return result
	end
	for _, id in ipairs(ids or {}) do
		local layout = safe_call(layouts.get, id)
		if layout then
			result[#result + 1] = {
				id = id,
				title = layout.title,
				names = layout.names,
				forward = layout.forward,
				reverse = layout.reverse,
				pairs = layout.pairs,
				pair_count = #layout.pairs,
			}
		end
	end
	return result
end

local function build()
	local core = safe_require("physical-keyboard")
	local config = safe_require("physical-keyboard.config")
	local layouts = safe_require("physical-keyboard.layouts")
	local mappings = safe_require("physical-keyboard.mappings")
	local cmdline = safe_require("physical-keyboard.cmdline")
	local echo = safe_require("physical-keyboard.echo")
	local providers = safe_require("physical-keyboard.detect.providers")
	local doctor = safe_require("physical-keyboard.doctor")

	if not core or not config or not layouts then
		return {
			error = "physical-keyboard modules are not available",
			core = core,
		}
	end

	local status = safe_call(core.status) or {
		enabled = false,
		active_layouts = {},
		detect = {},
		mappings = {},
		cmdline = {},
		echo = {},
		config = config.resolve({}),
	}
	local cfg = status.config or config.resolve({})
	local effective = safe_call(core.effective_layouts) or cfg.active_layouts or {}
	local doctor_info = doctor and safe_call(doctor.collect, core, { probe = false }) or {}

	local bundled = {}
	for _, id in ipairs(safe_call(layouts.ids) or {}) do
		local layout = safe_call(layouts.get, id)
		if layout then
			bundled[#bundled + 1] = {
				id = id,
				title = layout.title,
				pair_count = #layout.pairs,
			}
		end
	end

	return {
		core = core,
		status = status,
		cfg = cfg,
		cfg_sanitized = config.sanitize(cfg),
		effective_layouts = effective,
		bundled = bundled,
		layout_details = collect_layouts(effective),
		all_layout_details = collect_layouts(safe_call(layouts.ids) or {}),
		mappings = {
			available = mappings ~= nil,
			list = mappings and safe_call(mappings.list) or {},
			forward = mappings and safe_call(mappings.forward) or {},
		},
		cmdline = {
			available = cmdline ~= nil,
			added = cmdline and safe_call(cmdline.added) or {},
			extra = cmdline and safe_call(cmdline.extra) or {},
			config = cfg.cmdline or {},
		},
		echo = {
			available = echo ~= nil,
			enabled = echo and safe_call(echo.is_enabled) or false,
			mode = echo and safe_call(echo.mode) or "all",
			modes = echo and safe_call(echo.modes) or {},
			history = echo and safe_call(echo.history, 30) or {},
			preview = echo and safe_call(echo.preview) or nil,
			config = cfg.echo or {},
		},
		providers = {
			available = providers ~= nil,
			list = providers and safe_call(providers.list) or {},
			environment = providers and safe_call(providers.environment) or {},
			order = doctor_info.detection and doctor_info.detection.provider_order or {},
			probes = doctor_info.detection and doctor_info.detection.probes or nil,
		},
		doctor = doctor_info,
		session = doctor_info.session or {},
		config_source = status.config_source or {},
		config_file = status.config_file,
		overrides = safe_call(core.overrides_info) or {},
	}
end

function M.snapshot()
	if cache then
		return cache
	end
	cache = build()
	return cache
end

function M.invalidate()
	cache = nil
end

function M.set_on_change(fn)
	on_change = fn
end

function M.probe_state()
	return state.probe
end

function M.start_probe()
	local data = M.snapshot()
	local cfg = (data and data.cfg) or {}
	local detect = cfg.detect or {}
	local providers = safe_require("physical-keyboard.detect.providers")
	if not providers or type(providers.probe_async) ~= "function" then
		state.probe = {
			status = "unavailable",
			results = {},
			at = os.time(),
		}
		if on_change then
			on_change()
		end
		return
	end

	probe_generation = probe_generation + 1
	local generation = probe_generation
	state.probe = {
		status = "running",
		results = {},
		at = os.time(),
	}

	providers.probe_async({
		provider = detect.provider,
		providers = detect.providers,
		timeout = detect.timeout,
	}, function(results)
		if generation ~= probe_generation then
			return
		end
		state.probe = {
			status = "done",
			results = results or {},
			at = os.time(),
		}
		cache = nil
		if on_change then
			on_change()
		end
	end)
end

function M.reset_probe()
	probe_generation = probe_generation + 1
	state.probe = {
		status = "idle",
		results = {},
		at = nil,
	}
end

return M
