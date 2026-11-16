local layouts = require("physical-keyboard.layouts")
local langmap = require("physical-keyboard.langmap")
local providers = require("physical-keyboard.detect.providers")

local M = {}

local function ok(message)
	vim.health.ok(message)
end

local function warn(message)
	vim.health.warn(message)
end

local function info(message)
	vim.health.info(message)
end

local function report_providers(status)
	local env = providers.environment()
	local cfg = (status and status.config) or {}
	local detect_cfg = cfg.detect or {}
	if env.remote and detect_cfg.remote == "auto" then
		warn("remote SSH session detected; detection is disabled with detect.remote = 'auto'")
	end
	if env.x11 == false and env.linux then
		info("X11-only adapters are skipped (Wayland/XWayland session)")
	end
	local probes = providers.probe({
		provider = detect_cfg.provider,
		providers = detect_cfg.providers,
	})
	local any = false
	for _, item in ipairs(probes) do
		if item.available then
			any = true
			ok(("provider %s: %s"):format(item.name, item.raw))
		else
			info(("provider %s: unavailable"):format(item.name))
		end
	end
	if not any then
		warn("no layout detection provider responded")
		if env.macos or env.windows then
			info("install im-select: https://github.com/daipeihust/im-select")
		elseif env.x11 then
			info("install xkb-switch: https://github.com/sergei-mironov/xkb-switch")
		else
			info("use a supported compositor adapter (niri, sway, Hyprland, GNOME, KDE)")
		end
	end
end

function M.check()
	vim.health.start("physical-keyboard")

	local core = require("physical-keyboard")
	local status = core.status()

	if status.enabled then
		ok("plugin is enabled")
	else
		warn("plugin is disabled")
	end

	info(("bundled layouts: %d"):format(#layouts.ids()))
	info(("active layouts: %s"):format(table.concat(status.active_layouts, ", ")))
	if status.english then
		info("current layout: English (translation off)")
	else
		info(("current layout: %s"):format(status.current_layout or "none"))
	end
	local config_source = status.config_source
		and (status.config_source.file or status.config_source.attempted)
	info(("configuration: %s"):format(config_source or "setup() only"))

	for _, warning in ipairs(status.config and status.config.warnings or {}) do
		warn("config: " .. warning)
	end

	local langmap_value = langmap.current()
	if langmap_value == "" then
		warn("'langmap' is empty (English layout or disabled)")
	else
		ok(("'langmap' contains %d pairs"):format(langmap.count(langmap_value)))
	end

	if status.detect.remote then
		warn("detection is disabled for this session (remote or detect.remote = false)")
	elseif status.detect.disabled == "config" then
		info("detection is disabled by config (detect.enabled = false)")
	elseif status.detect.provider then
		ok(
			("layout detection: %s -> %s"):format(
				status.detect.provider,
				status.detect.raw or "unknown"
			)
		)
	else
		warn("no working layout detection provider found")
	end

	report_providers(status)

	if status.mappings.hacked then
		ok("keymap API is hooked (plugin mappings are mirrored)")
	else
		warn("keymap API hook is disabled; only built-in motions are translated")
	end
	info(("mirrored mappings: %d"):format(status.mappings.created))
	if status.mappings.excluded > 0 then
		info(("excluded mapping patterns: %d"):format(status.mappings.excluded))
	end

	if status.cmdline.enabled then
		ok(("command-line aliases: %d"):format(status.cmdline.count))
	else
		warn("command-line translation is disabled")
	end

	if status.echo.enabled then
		info(("echo keyboard enabled (mode: %s)"):format(status.echo.mode))
	end
end

return M
