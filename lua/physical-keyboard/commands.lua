local layouts = require("physical-keyboard.layouts")
local cmdline = require("physical-keyboard.cmdline")

local M = {}

local core

local function to_bool(value)
	if value == nil or value == "" then
		return nil
	end
	local lowered = tostring(value):lower()
	if lowered == "on" or lowered == "true" or lowered == "1" or lowered == "yes" then
		return true
	end
	if lowered == "off" or lowered == "false" or lowered == "0" or lowered == "no" then
		return false
	end
	return nil
end

local function layout_complete(arglead)
	local result = { "en" }
	for _, id in ipairs(layouts.ids()) do
		if arglead == "" or id:find(arglead, 1, true) then
			result[#result + 1] = id
		end
	end
	return result
end

local function echo_modes()
	return require("physical-keyboard.echo").modes()
end

local function register(name, fn, opts)
	opts = opts or {}
	opts.desc = opts.desc or name
	vim.api.nvim_create_user_command(name, fn, opts)
end

local function print_status()
	local status = core.status()
	local lines = { "=== Physical Keyboard ===" }
	lines[#lines + 1] = ("Enabled: %s"):format(status.enabled and "yes" or "no")
	lines[#lines + 1] = ("Active layouts: %s"):format(table.concat(status.active_layouts, ", "))
	if status.english then
		lines[#lines + 1] = "Current layout: English (translation off)"
	else
		lines[#lines + 1] = ("Current layout: %s"):format(status.current_layout or "auto/none")
	end

	if status.detect.remote then
		lines[#lines + 1] = "Detection: disabled for this session (remote or detect.remote = false)"
	elseif status.detect.disabled == "config" then
		lines[#lines + 1] = "Detection: disabled by config (detect.enabled = false)"
	elseif status.detect.provider then
		lines[#lines + 1] = (
			"Detection: %s (%s -> %s)"
		):format(
			status.detect.provider,
			status.detect.raw or "?",
			status.detect.layout or "english"
		)
	else
		lines[#lines + 1] = "Detection: unavailable"
	end

	lines[#lines + 1] = ("langmap pairs: %d"):format(status.langmap_pairs)
	lines[#lines + 1] = ("Mirrored mappings: %d"):format(status.mappings.created)
	lines[#lines + 1] = ("Command-line aliases: %d"):format(status.cmdline.count)
	lines[#lines + 1] = ("Echo: %s"):format(
		status.echo.enabled and status.echo.mode or "off"
	)
	lines[#lines + 1] = ("Notifications: %s"):format(status.notify)
	lines[#lines + 1] = ("Config file: %s"):format(
		status.config_file or "not used (set config_file = true)"
	)
	if status.config_source and status.config_source.file then
		lines[#lines + 1] = ("Config source: %s"):format(status.config_source.file)
	end

	core.print(table.concat(lines, "\n"), vim.log.levels.INFO)
end

local function print_layouts()
	local lines = { "=== Layouts ===" }
	for _, id in ipairs(layouts.ids()) do
		local layout = layouts.get(id)
		lines[#lines + 1] = ("  %-8s %s"):format(id, layout and layout.title or "?")
	end
	core.print(table.concat(lines, "\n"), vim.log.levels.INFO)
end

local function print_detection()
	local result = core.detect_now(true)
	local lines = { "=== Detection ===" }
	lines[#lines + 1] = ("provider: %s"):format(result.provider or "none")
	lines[#lines + 1] = ("raw: %s"):format(result.raw or "none")
	lines[#lines + 1] = ("matched layout: %s"):format(result.layout or "english/unknown")
	lines[#lines + 1] = ("english: %s"):format(result.english and "yes" or "no")
	lines[#lines + 1] = ("remote session: %s"):format(
		require("physical-keyboard.detect").is_remote() and "yes" or "no"
	)
	if result.disabled then
		lines[#lines + 1] = ("disabled: %s"):format(result.disabled)
	end
	core.print(table.concat(lines, "\n"), vim.log.levels.INFO)
end

local function print_config(args)
	local config = require("physical-keyboard.config")
	local values = config.sanitize(core.status().config)
	if args.fargs[1] == "--json" then
		print(vim.json.encode(values))
		return
	end
	core.print(vim.inspect(values), vim.log.levels.INFO)
end

local function print_doctor(args)
	local info = core.doctor({ probe = true })
	if args.fargs[1] == "--json" then
		print(vim.json.encode(info))
		return
	end
	core.print(require("physical-keyboard.doctor").format(info), vim.log.levels.INFO)
end

local function print_aliases()
	local lines = { "=== Command-line abbreviations ===" }
	local added = cmdline.added()
	local extra = cmdline.extra()
	local keys = {}
	for native in pairs(added) do
		keys[native] = true
	end
	for native in pairs(extra) do
		keys[native] = true
	end
	local sorted = vim.tbl_keys(keys)
	table.sort(sorted)
	for _, native in ipairs(sorted) do
		lines[#lines + 1] = ("  %-12s -> %s"):format(
			native,
			added[native] or extra[native] or "?"
		)
	end
	if #sorted == 0 then
		lines[#lines + 1] = "  (none)"
	end
	core.print(table.concat(lines, "\n"), vim.log.levels.INFO)
end

---@param instance table
function M.register(instance)
	core = instance

	register("PhyKeyboard", function()
		core.print(
			("=== Physical Keyboard ===\nVersion: %s\nLayouts: %d\nCommands: :PhyKeyboardStatus, :PhyKeyboardConfig, :PhyKeyboardDoctor, :PhyKeyboardList, :PhyKeyboardUse, :PhyKeyboardRefresh, :PhyKeyboardDetect, :PhyKeyboardEcho"):format(
				core.version,
				#layouts.ids()
			),
			vim.log.levels.INFO
		)
	end, { nargs = 0 })

	register("PhyKeyboardStatus", print_status, { nargs = 0 })
	register("PhyKeyboardList", print_layouts, { nargs = 0 })
	register("PhyKeyboardDetect", print_detection, { nargs = 0 })
	register("PhyKeyboardConfig", print_config, {
		nargs = "?",
		complete = function()
			return { "--json" }
		end,
	})
	register("PhyKeyboardDoctor", print_doctor, {
		nargs = "?",
		complete = function()
			return { "--json" }
		end,
	})

	register("PhyKeyboardEnable", function()
		core.enable()
	end, { nargs = 0 })

	register("PhyKeyboardDisable", function()
		core.disable()
	end, { nargs = 0 })

	register("PhyKeyboardToggle", function()
		local enabled = core.toggle()
		core.print("Plugin: " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO)
	end, { nargs = 0 })

	register("PhyKeyboardRefresh", function()
		core.refresh(true)
	end, { nargs = 0 })

	register("PhyKeyboardUse", function(args)
		local id = args.fargs[1]
		if not core.use_layout(id) then
			core.print("Unknown layout: " .. tostring(id), vim.log.levels.ERROR)
		end
	end, { nargs = 1, complete = layout_complete })

	register("PhyKeyboardAuto", function()
		core.use_layout(nil)
	end, { nargs = 0 })

	register("PhyKeyboardMappings", function()
		local created = core.refresh_mappings()
		core.print(("Mirrored %d mapping(s)"):format(created), vim.log.levels.INFO)
	end, { nargs = 0 })

	register("PhyKeyboardEcho", function(args)
		local value = to_bool(args.fargs[1])
		local enabled = core.echo_toggle(value)
		core.print("Echo keyboard: " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO)
	end, { nargs = "?", complete = function()
		return { "on", "off" }
	end })

	register("PhyKeyboardEchoMode", function(args)
		local mode = args.fargs[1]
		if not mode then
			core.print("Echo mode: " .. core.echo_mode(), vim.log.levels.INFO)
			return
		end
		if not core.echo_mode(mode) then
			core.print("Invalid echo mode: " .. mode, vim.log.levels.ERROR)
		end
	end, { nargs = "?", complete = echo_modes })

	register("PhyKeyboardNotify", function(args)
		local mode = core.set_notify(args.fargs[1])
		core.print("Notifications: " .. mode, vim.log.levels.INFO)
	end, { nargs = "?", complete = function()
		return { "all", "errors", "off" }
	end })

	register("PhyKeyboardCmdline", function(args)
		local value = to_bool(args.fargs[1])
		local enabled = core.set_cmdline(value)
		core.print("Command-line aliases: " .. (enabled and "enabled" or "disabled"), vim.log.levels.INFO)
	end, { nargs = "?", complete = function()
		return { "on", "off" }
	end })

	register("PhyKeyboardAliases", function(args)
		local action = args.fargs[1] or "list"
		if action == "add" then
			local native = args.fargs[2]
			local english = args.fargs[3]
			if not native or not english then
				core.print("Usage: :PhyKeyboardAliases add <native> <english>", vim.log.levels.ERROR)
				return
			end
			if cmdline.add(native, english) then
				core.print(("Alias added: %s -> %s"):format(native, english), vim.log.levels.INFO)
			else
				core.print("Could not add alias", vim.log.levels.ERROR)
			end
		elseif action == "remove" then
			local native = args.fargs[2]
			if not native then
				core.print("Usage: :PhyKeyboardAliases remove <native>", vim.log.levels.ERROR)
				return
			end
			if cmdline.remove(native) then
				core.print("Alias removed: " .. native, vim.log.levels.INFO)
			else
				core.print("Alias not found: " .. native, vim.log.levels.WARN)
			end
		else
			print_aliases()
		end
	end, { nargs = "*", complete = function(arglead)
		local actions = { "list", "add", "remove" }
		if arglead == "" then
			return actions
		end
		return actions
	end })

	register("PhyKeyboardEditConfig", function()
		core.edit_config()
	end, { nargs = 0 })

	register("PhyKeyboardReload", function()
		local ok, err = core.reload()
		if not ok then
			core.print("Reload failed: " .. tostring(err), vim.log.levels.ERROR)
		end
	end, { nargs = 0 })

	-- Backwards compatible commands from the previous version.
	register("PhyKeyboardEnableLayout", function(args)
		local id = args.fargs[1]
		if not core.use_layout(id) then
			core.print("Unknown layout: " .. tostring(id), vim.log.levels.ERROR)
		end
	end, { nargs = 1, complete = layout_complete })

	register("PhyKeyboardDisableLayout", function()
		core.use_layout(nil)
	end, { nargs = 0 })

	register("PhyKeyboardSet", function(args)
		local id = args.fargs[1]
		local active = to_bool(args.fargs[2])
		if active == false then
			core.use_layout(nil)
		elseif id then
			if not core.use_layout(id) then
				core.print("Unknown layout: " .. tostring(id), vim.log.levels.ERROR)
			end
		end
	end, { nargs = "*", complete = layout_complete })
end

return M
