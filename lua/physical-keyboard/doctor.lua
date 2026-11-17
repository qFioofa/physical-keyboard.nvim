local config = require("physical-keyboard.config")
local layouts = require("physical-keyboard.layouts")
local providers = require("physical-keyboard.detect.providers")

--- Environment report used by `:PhyKeyboardDoctor` and AI configuration flows.
local M = {}

local function uname()
	local uv = vim.uv or vim.loop
	if uv and uv.os_uname then
		local ok, value = pcall(uv.os_uname)
		if ok then
			return value
		end
	end
	return {}
end

local function nvim_version()
	if vim.version then
		local v = vim.version()
		return ("%d.%d.%d"):format(v.major or 0, v.minor or 0, v.patch or 0)
	end
	return tostring(vim.fn.has("nvim-0.10") == 1 and "0.10+" or "unknown")
end

local function session()
	local uv = uname()
	return {
		os = uv.sysname or "unknown",
		release = uv.release,
		machine = uv.machine,
		session_type = vim.env.XDG_SESSION_TYPE,
		desktop = vim.env.XDG_CURRENT_DESKTOP,
		wayland_display = vim.env.WAYLAND_DISPLAY,
		display = vim.env.DISPLAY,
		term = vim.env.TERM,
		remote = providers.is_remote(),
		wsl = vim.fn.has("wsl") == 1,
		ssh_connection = vim.env.SSH_CONNECTION,
	}
end

local function available(probes)
	local result = {}
	for _, item in ipairs(probes or {}) do
		if item.available then
			result[#result + 1] = item.name
		end
	end
	return result
end

local function recommendations(cfg, env, probes, status)
	local result = {}
	if env.remote and cfg.detect.remote == "auto" then
		result[#result + 1] = "Remote SSH session: automatic detection is disabled. "
			.. "Use active_layouts, or set detect.remote = false to disable it explicitly."
	end

	if probes and cfg.detect.enabled and not env.remote then
		local names = available(probes)
		if #names == 0 then
			if env.windows or env.macos then
				result[#result + 1] = "No detection adapter responded. Install im-select for "
					.. "reliable macOS/Windows detection."
			elseif env.x11 then
				result[#result + 1] = "No detection adapter responded. Install xkb-switch "
					.. "(X11) or configure the compositor adapter."
			else
				result[#result + 1] = "No detection adapter responded. For Wayland use a "
					.. "supported compositor (niri, sway, Hyprland, GNOME, KDE) or install "
					.. "its CLI helper."
			end
		end
	end

	if status and status.detect and status.detect.remote then
		result[#result + 1] = "Detection is currently disabled for this session "
			.. "(remote or detect.remote = false)."
	end

	if cfg.config_file == false and cfg.env ~= false then
		result[#result + 1] = "Settings live only in setup(). To use a file, set "
			.. "config_file = true and edit the generated template."
	end

	if status and status.mappings and status.mappings.created == 0 and cfg.mappings.enabled then
		result[#result + 1] = "No plugin mappings are mirrored yet. Run "
			.. ":PhyKeyboardMappings after plugins have loaded."
	end

	return result
end

---@param core table
---@param opts { probe: boolean|nil }|nil
---@return table
function M.collect(core, opts)
	opts = opts or {}
	local cfg = core.config or config.resolve({})
	local status = core.status()
	local env = providers.environment()
	local probe = opts.probe ~= false
	local probes = nil
	if probe then
		probes = providers.probe({
			provider = cfg.detect.provider,
			providers = cfg.detect.providers,
			timeout = cfg.detect.timeout,
		})
	end

	local info = {
		plugin = "physical-keyboard.nvim",
		version = core.version,
		nvim = nvim_version(),
		os = uname(),
		session = session(),
		config = {
			source = cfg.source,
			file = cfg.config_file,
			values = config.sanitize(cfg),
		},
		layouts = {
			bundled = layouts.ids(),
			active = (core.config and core.effective_layouts()) or cfg.active_layouts or {},
			current = core.current_layout(),
		},
		detection = {
			last = config.sanitize(status.detect),
			provider_order = (function()
				local names = {}
				for _, provider in ipairs(providers.list()) do
					names[#names + 1] = provider.name
				end
				return names
			end)(),
			probes = probes,
			environment = env,
		},
		which_key = config.sanitize(status.which_key or {}),
		native = config.sanitize(status.native or {}),
		status = config.sanitize(status),
	}

	info.recommendations = recommendations(cfg, env, probes, status)
	return info
end

---@param info table
---@return string
function M.format(info)
	local lines = {
		"=== Physical Keyboard doctor ===",
		("version: %s (Neovim %s)"):format(info.version, info.nvim),
		("os: %s %s (%s)"):format(
			info.session.os or "?",
			info.session.release or "",
			info.session.machine or ""
		),
		("session: type=%s desktop=%s ssh=%s wsl=%s"):format(
			tostring(info.session.session_type),
			tostring(info.session.desktop),
			tostring(info.session.remote),
			tostring(info.session.wsl)
		),
		("config file: %s"):format(tostring(info.config.file)),
		("active layouts: %s"):format(table.concat(info.layouts.active, ", ")),
		("current layout: %s"):format(tostring(info.layouts.current)),
		("which-key: available=%s version=%s hidden=%s groups=%s alongside=%s"):format(
			tostring(info.which_key.available),
			tostring(info.which_key.version),
			tostring(info.which_key.hidden),
			tostring(info.which_key.groups),
			tostring(info.which_key.alongside)
		),
		("native listings: enabled=%s commandline=%s api=%s suspended=%s"):format(
			tostring(info.native.enabled),
			tostring(info.native.commandline),
			tostring(info.native.api_patched),
			tostring(info.native.suspended)
		),
		("detected: provider=%s raw=%s layout=%s"):format(
			tostring(info.detection.last.provider),
			tostring(info.detection.last.raw),
			tostring(info.detection.last.layout)
		),
	}

	if info.detection.probes then
		lines[#lines + 1] = "providers:"
		for _, item in ipairs(info.detection.probes) do
			lines[#lines + 1] = ("  %-18s %s"):format(
				item.name,
				item.available and ("ok: " .. tostring(item.raw)) or "unavailable"
			)
		end
	end

	if info.recommendations and #info.recommendations > 0 then
		lines[#lines + 1] = "recommendations:"
		for _, item in ipairs(info.recommendations) do
			lines[#lines + 1] = "  - " .. item
		end
	end

	return table.concat(lines, "\n")
end

return M
