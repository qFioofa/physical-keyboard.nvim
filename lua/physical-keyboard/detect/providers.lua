--- Platform specific keyboard layout detection.
---
--- There is no single cross-platform tool that reports the active keyboard
--- layout, so this module tries a list of small, dependency-free adapters and
--- returns the first one that produces a usable answer.
local M = {}

local function uname()
	local ok, value = pcall(vim.uv.os_uname)
	if ok then
		return value
	end
	return {}
end

local function sysname()
	return uname().sysname or ""
end

local function is_linux()
	return sysname() == "Linux"
end

local function is_mac()
	return sysname() == "Darwin"
end

local function is_windows()
	local name = sysname()
	return name == "Windows_NT" or name == "Windows" or name == "MS-DOS"
end

local function exe(name)
	return vim.fn.executable(name) == 1
end

local function desktop()
	return (vim.env.XDG_CURRENT_DESKTOP or ""):lower()
end

local function desktop_matches(names)
	local value = desktop()
	for _, name in ipairs(names) do
		if value:find(name, 1, true) then
			return true
		end
	end
	return false
end

--- X11-only adapters must not run inside a Wayland session, where DISPLAY
--- usually points to XWayland and does not reflect the real layout.
local function is_x11()
	if not is_linux() then
		return false
	end
	if (vim.env.XDG_SESSION_TYPE or ""):lower() == "wayland" then
		return false
	end
	return vim.env.WAYLAND_DISPLAY == nil or vim.env.WAYLAND_DISPLAY == ""
end

--- True when Neovim runs on a remote machine (SSH, container exec, ...).
--- The local OS layout on the client is irrelevant in that case.
---@return boolean
function M.is_remote()
	for _, name in ipairs({ "SSH_CONNECTION", "SSH_CLIENT", "SSH_TTY" }) do
		local value = vim.env[name]
		if value ~= nil and value ~= "" then
			return true
		end
	end
	return false
end

local current_co = nil

--- Runs a command without a shell and returns trimmed stdout or nil.
---
--- When called from `detect_async()` the function yields a request table and
--- the coroutine runner executes it through `vim.system`, so detection never
--- blocks the editor.
---@param cmd string[]
---@return string|nil
local function run(cmd)
	if current_co then
		return coroutine.yield({ cmd = cmd })
	end
	local ok, out = pcall(vim.fn.system, cmd)
	if not ok or vim.v.shell_error ~= 0 or type(out) ~= "string" then
		return nil
	end
	out = vim.trim(out)
	if out == "" then
		return nil
	end
	return out
end

local function decode(value)
	local ok, result = pcall(vim.json.decode, value)
	if ok and type(result) == "table" then
		return result
	end
	return nil
end

local function first_token(value)
	if type(value) ~= "string" then
		return nil
	end
	return value:match("^%s*([^,%s]+)")
end

---@type { name: string, get: fun(): string|nil }[]
local providers = {
	{
		name = "im-select",
		get = function()
			if not exe("im-select") then
				return nil
			end
			return run({ "im-select" })
		end,
	},
	{
		name = "macos-defaults",
		get = function()
			if not (is_mac() and exe("defaults")) then
				return nil
			end
			return run({
				"defaults",
				"read",
				"com.apple.HIToolbox",
				"AppleCurrentKeyboardLayoutInputSourceID",
			})
		end,
	},
	{
		name = "windows-powershell",
		get = function()
			if not is_windows() then
				return nil
			end
			local shell = exe("pwsh") and "pwsh" or (exe("powershell") and "powershell" or nil)
			if not shell then
				return nil
			end
			return run({
				shell,
				"-NoProfile",
				"-Command",
				"(Get-WinUserLanguageList)[0].LanguageTag",
			})
		end,
	},
	{
		name = "sway",
		get = function()
			if not (is_linux() and exe("swaymsg") and vim.env.SWAYSOCK) then
				return nil
			end
			local decoded = decode(run({ "swaymsg", "-t", "get_inputs", "-r" }) or "")
			if not decoded then
				return nil
			end
			for _, item in ipairs(decoded) do
				if
					type(item) == "table"
					and item.type == "keyboard"
					and item.xkb_active_layout_name
				then
					return item.xkb_active_layout_name
				end
			end
			return nil
		end,
	},
	{
		name = "hyprland",
		get = function()
			if
				not (
					is_linux()
					and exe("hyprctl")
					and vim.env.HYPRLAND_INSTANCE_SIGNATURE
				)
			then
				return nil
			end
			local decoded = decode(run({ "hyprctl", "devices", "-j" }) or "")
			if not decoded or type(decoded.keyboards) ~= "table" then
				return nil
			end
			for _, keyboard in ipairs(decoded.keyboards) do
				if type(keyboard) == "table" and keyboard.active_keymap then
					return keyboard.active_keymap
				end
			end
			return nil
		end,
	},
	{
		name = "niri",
		get = function()
			if not (is_linux() and exe("niri") and vim.env.NIRI_SOCKET) then
				return nil
			end
			local decoded = decode(run({ "niri", "msg", "-j", "keyboard-layouts" }) or "")
			if
				not decoded
				or type(decoded.names) ~= "table"
				or type(decoded.current_idx) ~= "number"
			then
				return nil
			end
			return decoded.names[decoded.current_idx + 1]
		end,
	},
	{
		name = "gnome",
		get = function()
			if
				not (
					is_linux()
					and exe("gsettings")
					and desktop_matches({ "gnome", "ubuntu", "unity", "pop" })
				)
			then
				return nil
			end
			local out = run({
				"gsettings",
				"get",
				"org.gnome.desktop.input-sources",
				"mru-sources",
			})
			if not out then
				return nil
			end
			for id in out:gmatch("'([%w%-_]+)'") do
				if id ~= "xkb" then
					return id
				end
			end
			return nil
		end,
	},
	{
		name = "kde",
		get = function()
			if not (is_linux() and desktop_matches({ "kde", "plasma" })) then
				return nil
			end
			for _, tool in ipairs({ "qdbus6", "qdbus" }) do
				if exe(tool) then
					local out = run({
						tool,
						"org.kde.keyboard",
						"/Layouts",
						"org.kde.KeyboardLayouts.getLayout",
					})
					if out then
						return out
					end
					out = run({
						tool,
						"org.kde.keyboard",
						"/Layouts",
						"org.kde.KeyboardLayouts.getLayoutsList",
					})
					if out then
						return first_token(out)
					end
				end
			end
			return nil
		end,
	},
	{
		name = "ibus",
		get = function()
			if not (is_linux() and exe("ibus")) then
				return nil
			end
			local out = run({ "ibus", "engine" })
			if not out then
				return nil
			end
			return out:match("xkb:([^:]+)") or out
		end,
	},
	{
		name = "fcitx",
		get = function()
			if not is_linux() then
				return nil
			end
			for _, tool in ipairs({ "fcitx5-remote", "fcitx-remote" }) do
				if exe(tool) then
					local out = run({ tool, "-n" })
					if out then
						return out:match("keyboard%-([%w%-]+)") or out
					end
				end
			end
			return nil
		end,
	},
	{
		name = "xkb-switch",
		get = function()
			if not (is_linux() and is_x11() and exe("xkb-switch")) then
				return nil
			end
			return run({ "xkb-switch", "-p" })
		end,
	},
	{
		name = "setxkbmap",
		get = function()
			if not (is_linux() and is_x11() and exe("setxkbmap")) then
				return nil
			end
			local out = run({ "setxkbmap", "-query" })
			if not out then
				return nil
			end
			return first_token(out:match("layout:%s*([^\n]+)") or "")
		end,
	},
}

--- Returns the provider list selected by the user configuration.
---@param opts table|nil
---@return { name: string, get: fun(): string|nil }[]
function M.select(opts)
	opts = opts or {}
	local value = opts.providers
	if value == nil or (type(value) == "table" and #value == 0) then
		value = opts.provider
	end
	if type(value) == "string" and value ~= "" then
		value = { value }
	end

	if type(value) == "table" and #value > 0 then
		local by_name = {}
		for _, provider in ipairs(providers) do
			by_name[provider.name] = provider
		end
		local result = {}
		for _, name in ipairs(value) do
			if by_name[name] then
				result[#result + 1] = by_name[name]
			end
		end
		return result
	end

	return vim.deepcopy(providers)
end

---@param opts table|nil
---@return string|nil
---@return string|nil
function M.detect(opts)
	for _, provider in ipairs(M.select(opts)) do
		local ok, raw = pcall(provider.get)
		if ok and type(raw) == "string" and raw ~= "" then
			return raw, provider.name
		end
	end
	return nil, nil
end

--- Non-blocking detection.
---
--- Provider bodies are regular functions; the coroutine runner intercepts
--- `run()` calls and executes them with `vim.system`.  The first provider that
--- returns a non-empty string wins.
---@param opts table|nil
---@param callback fun(raw: string|nil, provider: string|nil, err: string|nil)
function M.detect_async(opts, callback)
	opts = opts or {}
	local list = M.select(opts)
	local timeout = opts.timeout or 500

	if not vim.system then
		local raw, provider = M.detect(opts)
		callback(raw, provider, nil)
		return
	end

	local co = coroutine.create(function()
		for _, provider in ipairs(list) do
			local ok, raw = pcall(provider.get)
			if ok and type(raw) == "string" and raw ~= "" then
				return raw, provider.name
			end
		end
		return nil, nil
	end)

	local function step(...)
		if coroutine.status(co) == "dead" then
			return
		end
		current_co = co
		local ok, first, second = coroutine.resume(co, ...)
		current_co = nil

		if not ok then
			callback(nil, nil, tostring(first))
			return
		end
		if coroutine.status(co) == "dead" then
			callback(first, second, nil)
			return
		end
		if type(first) ~= "table" or type(first.cmd) ~= "table" then
			callback(nil, nil, "provider yielded an invalid command")
			return
		end

		local spawn_ok, spawned = pcall(vim.system, first.cmd, { text = true, timeout = timeout }, function(obj)
			vim.schedule(function()
				local out = nil
				if obj and obj.code == 0 and type(obj.stdout) == "string" then
					out = vim.trim(obj.stdout)
					if out == "" then
						out = nil
					end
				end
				step(out)
			end)
		end)
		if not spawn_ok then
			callback(nil, nil, tostring(spawned))
		end
	end

	step()
end

--- Runs every selected provider once and reports its raw answer.
--- Intended for `:checkhealth` and `:PhyKeyboardDoctor`; this call is blocking.
---@param opts table|nil
---@return { name: string, available: boolean, raw: string|nil, error: string|nil }[]
function M.probe(opts)
	local result = {}
	for _, provider in ipairs(M.select(opts)) do
		local ok, raw = pcall(provider.get)
		if ok and type(raw) == "string" and raw ~= "" then
			result[#result + 1] = { name = provider.name, available = true, raw = raw }
		else
			local err = nil
			if not ok then
				err = tostring(raw)
			end
			result[#result + 1] = {
				name = provider.name,
				available = false,
				raw = nil,
				error = err,
			}
		end
	end
	return result
end

--- Environment information used by the doctor/AI configuration flow.
---@return table
function M.environment()
	local tools = {
		"im-select",
		"defaults",
		"pwsh",
		"powershell",
		"swaymsg",
		"hyprctl",
		"niri",
		"gsettings",
		"qdbus6",
		"qdbus",
		"ibus",
		"fcitx5-remote",
		"fcitx-remote",
		"xkb-switch",
		"setxkbmap",
	}
	local executables = {}
	for _, tool in ipairs(tools) do
		executables[tool] = exe(tool)
	end
	return {
		remote = M.is_remote(),
		x11 = is_x11(),
		linux = is_linux(),
		macos = is_mac(),
		windows = is_windows(),
		executables = executables,
	}
end

---@return { name: string, get: fun(): string|nil }[]
function M.list()
	return providers
end

return M
