local F = require("physical-keyboard.ui.format")
local options = require("physical-keyboard.options")

local M = {}

local function C(text, hl)
	return { text = tostring(text == nil and "" or text), hl = hl }
end

local function L(...)
	return { ... }
end

local function kv(label, value, value_hl, label_width)
	label_width = label_width or 18
	return L(
		C(F.pad(label, label_width), "PhyKeyboardUIKey"),
		C(tostring(value == nil and "—" or value), value_hl or "PhyKeyboardUIValue")
	)
end

local function badge(value, yes, no, yes_hl, no_hl)
	if value then
		return C(yes or "yes", yes_hl or "PhyKeyboardUIOK")
	end
	return C(no or "no", no_hl or "PhyKeyboardUIError")
end

local function health(label, value, detail, ok_hl)
	local color = value and (ok_hl or "PhyKeyboardUIOK") or "PhyKeyboardUIWarn"
	local glyph = value and "✓" or "!"
	return L(
		C(" " .. glyph .. " ", color),
		C(F.pad(label, 24), "PhyKeyboardUIKey"),
		C(detail or (value and "ok" or "check"), color)
	)
end

local function bool_text(value)
	return value and "true" or "false"
end

local function list_text(value)
	if type(value) ~= "table" then
		return tostring(value)
	end
	if #value == 0 then
		return "(none)"
	end
	return table.concat(value, ", ")
end

local function doc(title, lines)
	return { title = title, lines = lines }
end

local function section(width, title)
	return F.rule(width, title)
end

local function sorted_keys(value)
	if type(value) ~= "table" then
		return {}
	end
	local keys = vim.tbl_keys(value)
	table.sort(keys)
	return keys
end

local function layout_id(data)
	local status = data.status or {}
	return status.current_layout
		or (data.effective_layouts and data.effective_layouts[1])
		or "ru"
end

local function find_layout(data, id)
	for _, layout in ipairs(data.layout_details or {}) do
		if layout.id == id then
			return layout
		end
	end
	for _, layout in ipairs(data.all_layout_details or {}) do
		if layout.id == id then
			return layout
		end
	end
	return nil
end

local function render_overview(data, ctx)
	local status = data.status or {}
	local detect = status.detect or {}
	local mappings = status.mappings or {}
	local cmdline = status.cmdline or {}
	local echo = status.echo or {}
	local cfg = data.cfg or {}
	local warnings = cfg.warnings or {}
	local width = ctx.width
	local layout = status.current_layout or (status.english and "English") or "auto/none"
	local provider = detect.provider or (detect.disabled and "disabled") or "unavailable"
	local lines = {
		section(width),
		kv("Plugin", "physical-keyboard.nvim", "PhyKeyboardUITitle"),
		kv("Version", status.version or data.core and data.core.version or "?"),
		L(
			C(F.pad("Enabled", 18), "PhyKeyboardUIKey"),
			badge(status.enabled, "● enabled", "○ disabled")
		),
		kv("Layout", layout, status.english and "PhyKeyboardUIMuted" or "PhyKeyboardUIValue"),
		kv("Provider", provider, detect.provider and "PhyKeyboardUIValue" or "PhyKeyboardUIWarn"),
		kv("Raw", detect.raw or "—", "PhyKeyboardUIMuted"),
		kv("Fallback", cfg.fallback or "—"),
		kv("langmap", ("%d pairs"):format(status.langmap_pairs or 0)),
		kv("Mappings", ("%d mirrored"):format(mappings.created or 0)),
		kv("Cmdline", ("%d aliases"):format(cmdline.count or 0)),
		kv("Echo", (echo.enabled and "on / " or "off / ") .. (echo.mode or "all")),
		kv("Notify", status.notify or cfg.notify or "—"),
		kv("Warnings", #warnings, #warnings > 0 and "PhyKeyboardUIWarn" or "PhyKeyboardUIMuted"),
		{},
		section(width, "HEALTH"),
		health("plugin enabled", status.enabled, status.enabled and "translations active" or "disabled"),
		health(
			"langmap applied",
			(status.langmap_pairs or 0) > 0 or status.english == true,
			status.english and "English: translation off" or ("%d pairs"):format(status.langmap_pairs or 0)
		),
		health(
			"detection",
			detect.provider ~= nil or detect.disabled ~= nil,
			detect.provider and ("provider " .. detect.provider) or (detect.disabled and ("disabled: " .. tostring(detect.disabled)) or "no provider"),
			detect.provider and "PhyKeyboardUIOK" or "PhyKeyboardUIInfo"
		),
		health(
			"keymap hook",
			mappings.hacked == true or not (cfg.mappings and cfg.mappings.enabled),
			mappings.hacked and "mappings mirrored automatically" or "hook inactive",
			mappings.hacked and "PhyKeyboardUIOK" or "PhyKeyboardUIInfo"
		),
		health("config warnings", #warnings == 0, #warnings == 0 and "no warnings" or (#warnings .. " warning(s)")),
		{},
		section(width, "SESSION"),
		kv("OS", data.session and data.session.os or "—"),
		kv("Session", data.session and data.session.session_type or "—"),
		kv("Desktop", data.session and data.session.desktop or "—"),
		kv("Remote", bool_text(data.session and data.session.remote), "PhyKeyboardUIMuted"),
	}
	local events = ctx.events or {}
	lines[#lines + 1] = {}
	lines[#lines + 1] = section(width, "LAST EVENT")
	if #events == 0 then
		lines[#lines + 1] = L(C("No plugin events since the panel was opened.", "PhyKeyboardUIMuted"))
	else
		local ev = events[#events]
		lines[#lines + 1] = L(
			C(ev.at or "--:--:--", "PhyKeyboardUIMuted"),
			C("  " .. (ev.name or "?"), "PhyKeyboardUIBadge"),
			C("  " .. (ev.detail or ""), "PhyKeyboardUIValue")
		)
	end
	return doc("Overview", lines)
end

local function render_statusline(data, ctx)
	local core = data.core
	local info = core and core.layout_info() or {}
	local lines = {
		section(ctx.width),
		kv("Default", core and core.statusline(), "PhyKeyboardUIValue"),
		kv("Uppercase", core and core.statusline({ uppercase = true }), "PhyKeyboardUIValue"),
		kv("English", core and core.statusline({ english = "ENG" }), "PhyKeyboardUIValue"),
		kv("Unknown", core and core.statusline({ unknown = "--" }), "PhyKeyboardUIValue"),
		{},
		section(ctx.width, "LAYOUT INFO"),
	}
	for _, key in ipairs({ "id", "layout", "english", "raw", "provider", "forced" }) do
		local value = info[key]
		lines[#lines + 1] = kv(key, type(value) == "boolean" and bool_text(value) or value, "PhyKeyboardUIValue")
	end
	lines[#lines + 1] = kv("vim.g", vim.g.physical_keyboard_layout or "", "PhyKeyboardUIValue")
	lines[#lines + 1] = {}
	lines[#lines + 1] = section(ctx.width, "USAGE")
	lines[#lines + 1] = L(C('vim.o.statusline = "%{v:lua.require\'physical-keyboard\'.statusline()} %f"', "PhyKeyboardUIMuted"))
	return doc("Statusline", lines)
end

local function render_events(data, ctx)
	local lines = {
		section(ctx.width),
		kv("Enabled", "PhysicalKeyboardEnabled"),
		kv("Disabled", "PhysicalKeyboardDisabled"),
		kv("Layout", "PhysicalKeyboardLayoutChanged"),
		kv("Config", "PhysicalKeyboardConfigReloaded"),
		{},
		section(ctx.width, "EVENT LOG"),
	}
	local events = ctx.events or {}
	if #events == 0 then
		lines[#lines + 1] = L(C("No events captured while this panel is open.", "PhyKeyboardUIMuted"))
	else
		for index = #events, math.max(1, #events - 14), -1 do
			local ev = events[index]
			lines[#lines + 1] = L(
				C(vim.trim(ev.at or ""), "PhyKeyboardUIMuted"),
				C("  " .. (ev.name or "?"), "PhyKeyboardUIBadge"),
				C("  " .. (ev.detail or ""), "PhyKeyboardUIValue")
			)
		end
	end
	return doc("Events", lines)
end

local function render_warnings(data, ctx)
	local cfg = data.cfg or {}
	local lines = { section(ctx.width, "CONFIG WARNINGS") }
	local warnings = cfg.warnings or {}
	if #warnings == 0 then
		lines[#lines + 1] = L(C("✓ No config warnings.", "PhyKeyboardUIOK"))
	else
		for _, warning in ipairs(warnings) do
			lines[#lines + 1] = L(C("! ", "PhyKeyboardUIWarn"), C(warning, "PhyKeyboardUIValue"))
		end
	end
	lines[#lines + 1] = {}
	lines[#lines + 1] = section(ctx.width, "RECOMMENDATIONS")
	local recs = data.doctor and data.doctor.recommendations or {}
	if #recs == 0 then
		lines[#lines + 1] = L(C("✓ No recommendations.", "PhyKeyboardUIOK"))
	else
		for _, item in ipairs(recs) do
			lines[#lines + 1] = L(C("• ", "PhyKeyboardUIInfo"), C(item, "PhyKeyboardUIValue"))
		end
	end
	return doc("Warnings", lines)
end

local function render_layouts_active(data, ctx)
	local status = data.status or {}
	local cfg = data.cfg or {}
	local lines = {
		section(ctx.width),
		kv("Active", list_text(status.active_layouts), "PhyKeyboardUIValue"),
		kv("Effective", list_text(data.effective_layouts), "PhyKeyboardUIValue"),
		kv("Current", status.current_layout or (status.english and "English") or "auto/none"),
		kv("Fallback", cfg.fallback or "—"),
		kv("English", bool_text(status.english), status.english and "PhyKeyboardUIMuted" or "PhyKeyboardUIBoolean"),
		{},
		section(ctx.width, "EFFECTIVE LAYOUTS"),
	}
	if #(data.layout_details or {}) == 0 then
		lines[#lines + 1] = L(C("No active layouts resolved.", "PhyKeyboardUIWarn"))
	else
		for _, layout in ipairs(data.layout_details) do
			lines[#lines + 1] = L(
				C(F.pad(layout.id, 10), "PhyKeyboardUIKey"),
				C(F.pad(layout.title or "?", 28), "PhyKeyboardUIValue"),
				C(("%d pairs"):format(layout.pair_count or 0), "PhyKeyboardUINumber")
			)
		end
	end
	return doc("Active layouts", lines)
end

local function render_layouts_bundled(data, ctx)
	local active = {}
	for _, id in ipairs(data.effective_layouts or {}) do
		active[id] = true
	end
	local lines = { section(ctx.width, "BUNDLED LAYOUTS") }
	for _, layout in ipairs(data.bundled or {}) do
		lines[#lines + 1] = L(
			C(active[layout.id] and "● " or "  ", active[layout.id] and "PhyKeyboardUIOK" or "PhyKeyboardUIMuted"),
			C(F.pad(layout.id, 10), "PhyKeyboardUIKey"),
			C(F.pad(layout.title or "?", 28), "PhyKeyboardUIValue"),
			C(tostring(layout.pair_count or 0), "PhyKeyboardUINumber")
		)
	end
	lines[#lines + 1] = {}
	lines[#lines + 1] = L(C("● = active or discovered layout", "PhyKeyboardUIMuted"))
	return doc("Bundled layouts", lines)
end

local function render_keyboard_map(data, ctx)
	local id = layout_id(data)
	local layout = find_layout(data, id)
	local lines = { section(ctx.width), kv("Layout", id), kv("Title", layout and layout.title or "not found") }
	if not layout then
		lines[#lines + 1] = L(C("Layout data is not available.", "PhyKeyboardUIWarn"))
		return doc("Keyboard map", lines)
	end
	local rows = {
		"`1234567890-=",
		"qwertyuiop[]",
		"asdfghjkl;'",
		"zxcvbnm,./",
	}
	lines[#lines + 1] = {}
	lines[#lines + 1] = section(ctx.width, "EN → NATIVE")
	for _, row in ipairs(rows) do
		local en = { C("EN  ", "PhyKeyboardUIMuted") }
		local ru = { C("RU  ", "PhyKeyboardUIMuted") }
		for char in row:gmatch(".") do
			local native = layout.forward[char]
			en[#en + 1] = C(F.pad(char, 2), "PhyKeyboardUIKey")
			ru[#ru + 1] = C(F.pad(native or "·", 2), native and "PhyKeyboardUIValue" or "PhyKeyboardUIMuted")
		end
		lines[#lines + 1] = en
		lines[#lines + 1] = ru
	end
	lines[#lines + 1] = {}
	lines[#lines + 1] = L(C("· = no translation for this physical key", "PhyKeyboardUIMuted"))
	return doc("Keyboard map", lines)
end

local function render_reverse_map(data, ctx)
	local id = layout_id(data)
	local layout = find_layout(data, id)
	local lines = { section(ctx.width), kv("Layout", id), kv("Title", layout and layout.title or "not found") }
	if not layout then
		return doc("Reverse map", lines)
	end
	local keys = sorted_keys(layout.reverse)
	lines[#lines + 1] = {}
	lines[#lines + 1] = section(ctx.width, "NATIVE → EN")
	for _, native in ipairs(keys) do
		lines[#lines + 1] = L(
			C(F.pad(native, 4), "PhyKeyboardUIKey"),
			C("→ ", "PhyKeyboardUISeparator"),
			C(layout.reverse[native], "PhyKeyboardUIValue")
		)
	end
	return doc("Reverse map", lines)
end

local function render_mappings_settings(data, ctx)
	local cfg = data.cfg or {}
	local mappings = cfg.mappings or {}
	local status = data.status or {}
	local stats = status.mappings or {}
	local lines = {
		section(ctx.width),
		kv("enabled", bool_text(mappings.enabled), "PhyKeyboardUIBoolean"),
		kv("hack_keymap", bool_text(mappings.hack_keymap), "PhyKeyboardUIBoolean"),
		kv("automapping", bool_text(mappings.automapping), "PhyKeyboardUIBoolean"),
		kv("modes", list_text(mappings.modes), "PhyKeyboardUIValue"),
		kv("excluded", #(mappings.exclude or {}), "PhyKeyboardUINumber"),
		kv("extra", vim.tbl_count(mappings.extra or {}), "PhyKeyboardUINumber"),
		{},
		section(ctx.width, "RUNTIME"),
		kv("hooked", bool_text(stats.hacked), stats.hacked and "PhyKeyboardUIOK" or "PhyKeyboardUIWarn"),
		kv("mirrored", stats.created or 0, "PhyKeyboardUINumber"),
	}
	return doc("Mapping settings", lines)
end

local function mappings_by_mode(data)
	local groups = {}
	for _, item in ipairs(data.mappings.list or {}) do
		local mode = item.mode or "?"
		local group = groups[mode] or { total = 0, global = 0, buffer = 0, items = {} }
		group.total = group.total + 1
		if item.global then
			group.global = group.global + 1
		else
			group.buffer = group.buffer + 1
		end
		group.items[#group.items + 1] = item
		groups[mode] = group
	end
	local configured = data.cfg and data.cfg.mappings and data.cfg.mappings.modes or {}
	for _, mode in ipairs(configured) do
		if not groups[mode] then
			groups[mode] = { total = 0, global = 0, buffer = 0, items = {} }
		end
	end
	return groups
end

local function render_mappings_modes(data, ctx)
	local groups = mappings_by_mode(data)
	local modes = sorted_keys(groups)
	local expanded = ctx.mode_expanded or {}
	local selected = ctx.content_selected
	local lines = { section(ctx.width, "MODES · j/k move · i/o expand · h parent") }
	local selectables = {}
	for _, mode in ipairs(modes) do
		local group = groups[mode]
		local group_id = "group:" .. mode
		local active = selected == group_id
		local glyph = expanded[mode] and "▾ " or "▸ "
		local header_hl = active and "PhyKeyboardUITreeSelected" or "PhyKeyboardUIKey"
		lines[#lines + 1] = L(
			C(glyph, header_hl),
			C(F.pad(mode, 7), header_hl),
			C(
				("%d mappings  (global %d, buffer %d)"):format(group.total, group.global, group.buffer),
				active and "PhyKeyboardUITreeSelected" or "PhyKeyboardUIMuted"
			)
		)
		selectables[#selectables + 1] = { id = group_id, line = #lines }
		if expanded[mode] then
			local items = vim.deepcopy(group.items)
			table.sort(items, function(a, b)
				return (a.source_lhs or "") < (b.source_lhs or "")
			end)
			if #items == 0 then
				lines[#lines + 1] = L(C("    (no mirrored mappings)", "PhyKeyboardUIMuted"))
			else
				for index, item in ipairs(items) do
					local item_id = ("item:%s:%d"):format(mode, index)
					local item_active = selected == item_id
					local hl = item_active and "PhyKeyboardUITreeSelected" or nil
					lines[#lines + 1] = L(
						C("    " .. (item.global and "g " or "b "), hl or "PhyKeyboardUIMuted"),
						C(F.pad(item.source_lhs or "", 22), hl or "PhyKeyboardUIKey"),
						C(" → ", hl or "PhyKeyboardUISeparator"),
						C(item.lhs or "", hl or "PhyKeyboardUIValue")
					)
					selectables[#selectables + 1] = { id = item_id, line = #lines }
				end
			end
		end
		lines[#lines + 1] = {}
	end
	if #modes == 0 then
		lines[#lines + 1] = L(C("No mappings were mirrored yet. Run :PhyKeyboardMappings after plugins load.", "PhyKeyboardUIMuted"))
	end
	return { title = "By mode", lines = lines, selectables = selectables }
end

local function matches_query(item, query)
	if query == "" then
		return true
	end
	local scope = item.global and "global" or ("buffer " .. tostring(item.bufnr or 0))
	local haystack = table.concat({
		item.mode or "",
		item.source_lhs or "",
		item.lhs or "",
		scope,
	}, " "):lower()
	return haystack:find(query, 1, true) ~= nil
end

local function render_mappings_list(data, ctx)
	local query = vim.trim(ctx.search or ""):lower()
	local items = {}
	for _, item in ipairs(data.mappings.list or {}) do
		if matches_query(item, query) then
			items[#items + 1] = item
		end
	end
	local groups = {}
	for _, item in ipairs(items) do
		local mode = item.mode or "?"
		groups[mode] = groups[mode] or {}
		groups[mode][#groups[mode] + 1] = item
	end
	local modes = sorted_keys(groups)
	local lines = { section(ctx.width) }
	if query ~= "" then
		lines[#lines + 1] = L(C("Search: ", "PhyKeyboardUIKey"), C(ctx.search, "PhyKeyboardUIBadge"), C(("  %d match(es)"):format(#items), "PhyKeyboardUIMuted"))
		lines[#lines + 1] = {}
	else
		lines[#lines + 1] = L(C("Press / to search every binding.", "PhyKeyboardUIMuted"))
		lines[#lines + 1] = {}
	end
	for _, mode in ipairs(modes) do
		local group = groups[mode]
		table.sort(group, function(a, b)
			return (a.source_lhs or "") < (b.source_lhs or "")
		end)
		lines[#lines + 1] = section(ctx.width, ("MODE %s · %d"):format(mode, #group))
		for _, item in ipairs(group) do
			lines[#lines + 1] = L(
				C(F.pad(item.global and "global" or ("buf " .. tostring(item.bufnr or 0)), 10), "PhyKeyboardUIMuted"),
				C(F.pad(item.source_lhs or "", 24), "PhyKeyboardUIKey"),
				C(" → ", "PhyKeyboardUISeparator"),
				C(item.lhs or "", "PhyKeyboardUIValue")
			)
		end
		lines[#lines + 1] = {}
	end
	if #items == 0 then
		if query ~= "" then
			lines[#lines + 1] = L(C("No mirrored bindings match the search.", "PhyKeyboardUIWarn"))
		else
			lines[#lines + 1] = L(C("No mirrored mappings yet. Run :PhyKeyboardMappings after plugins load.", "PhyKeyboardUIMuted"))
		end
	end
	return { title = "Mirrored list", lines = lines }
end

local function render_mappings_filters(data, ctx)
	local cfg = data.cfg or {}
	local mappings = cfg.mappings or {}
	local lines = { section(ctx.width, "EXCLUDE") }
	for _, pattern in ipairs(mappings.exclude or {}) do
		lines[#lines + 1] = L(C("• ", "PhyKeyboardUIWarn"), C(pattern, "PhyKeyboardUIValue"))
	end
	if #(mappings.exclude or {}) == 0 then
		lines[#lines + 1] = L(C("(none)", "PhyKeyboardUIMuted"))
	end
	lines[#lines + 1] = {}
	lines[#lines + 1] = section(ctx.width, "EXTRA")
	local extra = mappings.extra or {}
	local keys = sorted_keys(extra)
	for _, key in ipairs(keys) do
		lines[#lines + 1] = L(
			C("• ", "PhyKeyboardUIBadge"),
			C(key, "PhyKeyboardUIKey"),
			C(" → ", "PhyKeyboardUISeparator"),
			C(tostring(extra[key]), "PhyKeyboardUIValue")
		)
	end
	if #keys == 0 then
		lines[#lines + 1] = L(C("(none)", "PhyKeyboardUIMuted"))
	end
	return doc("Excluded / Extra", lines)
end

local function render_cmdline_settings(data, ctx)
	local status = data.status or {}
	local cfg = data.cfg or {}
	local cmdline = cfg.cmdline or {}
	local stats = status.cmdline or {}
	local lines = {
		section(ctx.width),
		kv("enabled", bool_text(cmdline.enabled), "PhyKeyboardUIBoolean", 24),
		kv("active aliases", stats.count or 0, "PhyKeyboardUINumber", 24),
		kv("extra", stats.extra or 0, "PhyKeyboardUINumber", 24),
		kv("configured", #(cmdline.aliases or {}), "PhyKeyboardUINumber", 24),
	}
	return doc("Cmdline settings", lines)
end

local function render_cmdline_added(data, ctx)
	local added = data.cmdline.added or {}
	local extra = data.cmdline.extra or {}
	local keys = {}
	for key in pairs(added) do
		keys[key] = true
	end
	for key in pairs(extra) do
		keys[key] = true
	end
	local sorted = vim.tbl_keys(keys)
	table.sort(sorted)
	local lines = { section(ctx.width, "NATIVE → ENGLISH") }
	for _, native in ipairs(sorted) do
		lines[#lines + 1] = L(
			C(F.pad(native, 16), "PhyKeyboardUIKey"),
			C("→ ", "PhyKeyboardUISeparator"),
			C(added[native] or extra[native] or "?", "PhyKeyboardUIValue")
		)
	end
	if #sorted == 0 then
		lines[#lines + 1] = L(C("(none)", "PhyKeyboardUIMuted"))
	end
	return doc("Added aliases", lines)
end

local function render_cmdline_configured(data, ctx)
	local cfg = data.cfg or {}
	local cmdline = cfg.cmdline or {}
	local lines = { section(ctx.width, "ALIASES") }
	for _, alias in ipairs(cmdline.aliases or {}) do
		lines[#lines + 1] = L(C("• ", "PhyKeyboardUIBadge"), C(alias, "PhyKeyboardUIValue"))
	end
	if #(cmdline.aliases or {}) == 0 then
		lines[#lines + 1] = L(C("(none)", "PhyKeyboardUIMuted"))
	end
	lines[#lines + 1] = {}
	lines[#lines + 1] = section(ctx.width, "EXTRA")
	local extra = cmdline.extra or {}
	local keys = sorted_keys(extra)
	for _, key in ipairs(keys) do
		lines[#lines + 1] = L(C(key, "PhyKeyboardUIKey"), C(" → ", "PhyKeyboardUISeparator"), C(tostring(extra[key]), "PhyKeyboardUIValue"))
	end
	if #keys == 0 then
		lines[#lines + 1] = L(C("(none)", "PhyKeyboardUIMuted"))
	end
	return doc("Configured aliases", lines)
end

local function render_echo_state(data, ctx)
	local echo = data.echo or {}
	local lines = {
		section(ctx.width),
		kv("enabled", bool_text(echo.enabled), echo.enabled and "PhyKeyboardUIOK" or "PhyKeyboardUIMuted"),
		kv("mode", echo.mode or "all"),
		kv("modes", list_text(echo.modes), "PhyKeyboardUIValue"),
		{},
		L(C("Echo is a diagnostic on_key capture. Enable it with :PhyKeyboardEcho on.", "PhyKeyboardUIMuted")),
		L(C("The panel only reads state and history; it never toggles echo.", "PhyKeyboardUIMuted")),
	}
	return doc("Echo state", lines)
end

local function render_echo_modes(data, ctx)
	local lines = { section(ctx.width, "MODE PREVIEW"), C("MODE      RESULT", "PhyKeyboardUISection") }
	local sample = "й"
	for _, mode in ipairs(data.echo.modes or {}) do
		local preview = data.echo.preview and data.echo.preview(mode, sample) or "?"
		lines[#lines + 1] = L(
			C(F.pad(mode, 10), "PhyKeyboardUIKey"),
			C(tostring(preview), "PhyKeyboardUIValue")
		)
	end
	lines[#lines + 1] = {}
	lines[#lines + 1] = L(C("Preview uses the character " .. sample .. " (Russian short i).", "PhyKeyboardUIMuted"))
	return doc("Modes & preview", lines)
end

local function render_echo_history(data, ctx)
	local history = data.echo.history or {}
	local lines = { section(ctx.width, "LAST KEYS") }
	if not data.echo.enabled then
		lines[#lines + 1] = L(C("Echo is off. No keys are captured.", "PhyKeyboardUIMuted"))
		return doc("Last keys", lines)
	end
	if #history == 0 then
		lines[#lines + 1] = L(C("No keys captured yet.", "PhyKeyboardUIMuted"))
		return doc("Last keys", lines)
	end
	lines[#lines + 1] = C("#     CHAR   MODE     OUTPUT", "PhyKeyboardUISection")
	for index = #history, 1, -1 do
		local item = history[index]
		lines[#lines + 1] = L(
			C(F.pad(tostring(index), 6), "PhyKeyboardUIMuted"),
			C(F.pad(item.char or "", 7), "PhyKeyboardUIKey"),
			C(F.pad(item.mode or "", 9), "PhyKeyboardUIBadge"),
			C(item.text or "", "PhyKeyboardUIValue")
		)
	end
	return doc("Last keys", lines)
end

local function render_detection_current(data, ctx)
	local status = data.status or {}
	local detect = status.detect or {}
	local info = data.core and data.core.layout_info() or {}
	local lines = {
		section(ctx.width),
		kv("provider", detect.provider or "none"),
		kv("raw", detect.raw or "—", "PhyKeyboardUIMuted"),
		kv("layout", detect.layout or "english/unknown"),
		kv("english", bool_text(detect.english), detect.english and "PhyKeyboardUIMuted" or "PhyKeyboardUIBoolean"),
		kv("disabled", tostring(detect.disabled or "no")),
		kv("remote", detect.remote and "yes" or "no"),
		kv("async", bool_text(detect.async), "PhyKeyboardUIBoolean"),
		{},
		section(ctx.width, "LAYOUT INFO"),
	}
	for _, key in ipairs({ "id", "raw", "provider", "forced" }) do
		lines[#lines + 1] = kv(key, info[key], "PhyKeyboardUIValue")
	end
	return doc("Detection", lines)
end

local function render_detection_providers(data, ctx)
	local lines = { section(ctx.width, "PROVIDER ORDER") }
	for index, name in ipairs(data.providers.order or {}) do
		lines[#lines + 1] = L(C(F.pad(tostring(index), 4), "PhyKeyboardUIMuted"), C(name, "PhyKeyboardUIValue"))
	end
	lines[#lines + 1] = {}
	lines[#lines + 1] = section(ctx.width, "PROBE")
	local probe = ctx.probe or {}
	if probe.status == "running" then
		lines[#lines + 1] = L(C("… probing providers asynchronously", "PhyKeyboardUIInfo"))
	elseif probe.status == "done" then
		for _, item in ipairs(probe.results or {}) do
			lines[#lines + 1] = L(
				C(F.pad(item.name or "?", 18), "PhyKeyboardUIKey"),
				C(item.available and "✓ " or "· ", item.available and "PhyKeyboardUIOK" or "PhyKeyboardUIMuted"),
				C(item.available and tostring(item.raw or "") or "unavailable", item.available and "PhyKeyboardUIValue" or "PhyKeyboardUIMuted")
			)
		end
	else
		lines[#lines + 1] = L(C("Press r to probe all detection providers.", "PhyKeyboardUIMuted"))
	end
	return doc("Providers", lines)
end

local function render_detection_environment(data, ctx)
	local session = data.session or {}
	local env = data.providers.environment or {}
	local lines = {
		section(ctx.width, "SESSION"),
		kv("os", session.os or "—"),
		kv("release", session.release or "—"),
		kv("machine", session.machine or "—"),
		kv("session", session.session_type or "—"),
		kv("desktop", session.desktop or "—"),
		kv("wayland", session.wayland_display or "—"),
		kv("display", session.display or "—"),
		kv("term", session.term or "—"),
		kv("remote", bool_text(session.remote), "PhyKeyboardUIBoolean"),
		kv("wsl", bool_text(session.wsl), "PhyKeyboardUIBoolean"),
		{},
		section(ctx.width, "PLATFORM"),
		kv("linux", bool_text(env.linux), "PhyKeyboardUIBoolean"),
		kv("x11", bool_text(env.x11), "PhyKeyboardUIBoolean"),
		kv("macos", bool_text(env.macos), "PhyKeyboardUIBoolean"),
		kv("windows", bool_text(env.windows), "PhyKeyboardUIBoolean"),
	}
	return doc("Environment", lines)
end

local function render_config_effective(data, ctx)
	local cfg = data.cfg_sanitized or {}
	local live = data.cfg or {}
	local lines = {}
	local selectables = {}

	local function add(line, path)
		lines[#lines + 1] = line
		if path then
			selectables[#selectables + 1] = { id = "setting:" .. path, line = #lines }
		end
	end

	local function editable_row(path, label_width)
		local spec = options.spec(path)
		local text, hl = options.format(spec, live)
		text = F.truncate(text, 22)
		add(
			L(
				C("● ", "PhyKeyboardUIBadge"),
				C(F.pad(path, label_width), "PhyKeyboardUIKey"),
				C(F.pad(text, 22), hl),
				C(spec.kind == "bool" and "toggle" or "choose", "PhyKeyboardUIMuted")
			),
			path
		)
	end

	local function readonly_row(path, value, label_width)
		local text, hl = F.value(value)
		add(L(C("  ", "PhyKeyboardUIMuted"), C(F.pad(path, label_width), "PhyKeyboardUIKey"), C(text, hl)))
	end

	lines[#lines + 1] = section(ctx.width, "EDITABLE")
	lines[#lines + 1] = L(
		C("● editable · Enter/Space change · R reset overrides", "PhyKeyboardUIMuted")
	)
	lines[#lines + 1] = {}

	local label_width = 22
	for _, key in ipairs({ "enable", "notify", "active_layouts", "fallback" }) do
		if options.spec(key) then
			editable_row(key, label_width)
		else
			readonly_row(key, cfg[key], label_width)
		end
	end
	for _, key in ipairs({ "toggle_key", "config_file", "env" }) do
		readonly_row(key, cfg[key], label_width)
	end

	lines[#lines + 1] = {}
	lines[#lines + 1] = section(ctx.width, "OVERRIDES")
	local override = data.overrides or {}
	local override_path = override.file or "—"
	add(L(C("  ", "PhyKeyboardUIMuted"), C(F.pad("loading", label_width), "PhyKeyboardUIKey"), badge(override.enabled, "on", "off")))
	add(L(
		C("  ", "PhyKeyboardUIMuted"),
		C(F.pad("file", label_width), "PhyKeyboardUIKey"),
		C(F.truncate(override_path, 34), "PhyKeyboardUIValue")
	))
	if override.exists then
		add(
			L(
				C("● ", "PhyKeyboardUIWarn"),
				C(F.pad("Delete override file", label_width), "PhyKeyboardUIKey"),
				C("Enter delete", "PhyKeyboardUIMuted")
			),
			nil
		)
		selectables[#selectables + 1] = { id = "action:overrides.delete", line = #lines }
	else
		add(L(C("  ", "PhyKeyboardUIMuted"), C(F.pad("(no override file)", label_width), "PhyKeyboardUIMuted")))
	end
	add(L(C("  Set overrides = false in setup() to ignore this file.", "PhyKeyboardUIMuted")))

	for _, section_name in ipairs({ "detect", "langmap", "mappings", "cmdline", "echo" }) do
		lines[#lines + 1] = {}
		lines[#lines + 1] = section(ctx.width, section_name:upper())
		local values = cfg[section_name] or {}
		local keys = {}
		for _, key in ipairs(sorted_keys(values)) do
			keys[key] = true
		end
		for _, path in ipairs(options.paths()) do
			if path:sub(1, #section_name + 1) == section_name .. "." then
				keys[path:sub(#section_name + 2)] = true
			end
		end
		local names = vim.tbl_keys(keys)
		table.sort(names)
		for _, key in ipairs(names) do
			local path = section_name .. "." .. key
			if options.spec(path) then
				editable_row(path, label_width)
			else
				readonly_row(path, values[key], label_width)
			end
		end
	end

	return { title = "Effective config", lines = lines, selectables = selectables }
end

local function render_config_source(data, ctx)
	local source = data.config_source or {}
	local status = data.status or {}
	local lines = {
		section(ctx.width, "SOURCE"),
		kv("file", source.file or "not used"),
		kv("attempted", source.attempted or "—", "PhyKeyboardUIMuted"),
		kv("env", bool_text(source.env), "PhyKeyboardUIBoolean"),
		kv("config_file", tostring(data.config_file or false)),
		kv("notify", status.notify or "—"),
		{},
		section(ctx.width, "ENVIRONMENT"),
	}
	for _, name in ipairs({ "PKB_CONFIG", "PKB_LAYOUT", "PKB_DISABLE", "PKB_DEBUG", "PKB_NOTIFY" }) do
		local value = vim.env[name]
		lines[#lines + 1] = L(
			C(F.pad(name, 16), "PhyKeyboardUIKey"),
			C(value and (value ~= "" and value or "set") or "unset", value and "PhyKeyboardUIValue" or "PhyKeyboardUIMuted")
		)
	end
	return doc("Source & env", lines)
end

local function render_doctor_summary(data, ctx)
	local info = data.doctor or {}
	local session = info.session or {}
	local lines = {
		section(ctx.width),
		kv("version", info.version or "?"),
		kv("neovim", info.nvim or "?"),
		kv("os", session.os or "?"),
		kv("release", session.release or "—"),
		kv("machine", session.machine or "—"),
		kv("session", session.session_type or "—"),
		kv("desktop", session.desktop or "—"),
		kv("remote", bool_text(session.remote), "PhyKeyboardUIBoolean"),
		kv("wsl", bool_text(session.wsl), "PhyKeyboardUIBoolean"),
		{},
		section(ctx.width, "LAYOUT"),
		kv("active", list_text(info.layouts and info.layouts.active), "PhyKeyboardUIValue"),
		kv("current", info.layouts and info.layouts.current or "—"),
	}
	return doc("Doctor summary", lines)
end

local function render_doctor_tools(data, ctx)
	local env = data.providers.environment or {}
	local execs = env.executables or {}
	local keys = sorted_keys(execs)
	local lines = { section(ctx.width, "EXECUTABLES") }
	for _, name in ipairs(keys) do
		local found = execs[name]
		lines[#lines + 1] = L(
			C(found and "✓ " or "· ", found and "PhyKeyboardUIOK" or "PhyKeyboardUIMuted"),
			C(F.pad(name, 20), "PhyKeyboardUIKey"),
			C(found and "available" or "missing", found and "PhyKeyboardUIValue" or "PhyKeyboardUIMuted")
		)
	end
	if #keys == 0 then
		lines[#lines + 1] = L(C("No executable information available.", "PhyKeyboardUIMuted"))
	end
	return doc("Tools", lines)
end

local function render_doctor_recommendations(data, ctx)
	local recs = data.doctor and data.doctor.recommendations or {}
	local lines = { section(ctx.width, "RECOMMENDATIONS") }
	if #recs == 0 then
		lines[#lines + 1] = L(C("✓ Nothing to fix.", "PhyKeyboardUIOK"))
	else
		for _, item in ipairs(recs) do
			lines[#lines + 1] = L(C("• ", "PhyKeyboardUIInfo"), C(item, "PhyKeyboardUIValue"))
		end
	end
	return doc("Recommendations", lines)
end

local nodes = {
	{ id = "status", title = "Status", render = render_overview, children = {
		{ id = "status.overview", title = "Overview", render = render_overview },
		{ id = "status.statusline", title = "Statusline", render = render_statusline },
		{ id = "status.events", title = "Events", render = render_events },
		{ id = "status.warnings", title = "Warnings", render = render_warnings },
	} },
	{ id = "layouts", title = "Layouts", render = render_layouts_active, children = {
		{ id = "layouts.active", title = "Active", render = render_layouts_active },
		{ id = "layouts.bundled", title = "Bundled", render = render_layouts_bundled },
		{ id = "layouts.keyboard", title = "Keyboard map", render = render_keyboard_map },
		{ id = "layouts.reverse", title = "Reverse map", render = render_reverse_map },
	} },
	{ id = "detection", title = "Detection", render = render_detection_current, children = {
		{ id = "detection.current", title = "Current", render = render_detection_current },
		{ id = "detection.providers", title = "Providers", render = render_detection_providers, probe = true },
		{ id = "detection.environment", title = "Environment", render = render_detection_environment },
	} },
	{ id = "mappings", title = "Mappings", render = render_mappings_settings, children = {
		{ id = "mappings.settings", title = "Settings", render = render_mappings_settings },
		{ id = "mappings.modes", title = "By mode", render = render_mappings_modes },
		{ id = "mappings.list", title = "Mirrored list", render = render_mappings_list },
		{ id = "mappings.filters", title = "Excluded / Extra", render = render_mappings_filters },
	} },
	{ id = "cmdline", title = "Cmdline", render = render_cmdline_settings, children = {
		{ id = "cmdline.settings", title = "Settings", render = render_cmdline_settings },
		{ id = "cmdline.added", title = "Added aliases", render = render_cmdline_added },
		{ id = "cmdline.configured", title = "Configured aliases", render = render_cmdline_configured },
	} },
	{ id = "echo", title = "Echo", render = render_echo_state, children = {
		{ id = "echo.state", title = "State", render = render_echo_state },
		{ id = "echo.modes", title = "Modes & preview", render = render_echo_modes },
		{ id = "echo.history", title = "Last keys", render = render_echo_history },
	} },
	{ id = "config", title = "Config", render = render_config_effective, children = {
		{ id = "config.effective", title = "Effective", render = render_config_effective },
		{ id = "config.source", title = "Source", render = render_config_source },
		{ id = "config.warnings", title = "Warnings", render = render_warnings },
	} },
	{ id = "doctor", title = "Doctor", render = render_doctor_summary, probe = true, children = {
		{ id = "doctor.summary", title = "Summary", render = render_doctor_summary, probe = true },
		{ id = "doctor.tools", title = "Tools", render = render_doctor_tools },
		{ id = "doctor.recommendations", title = "Recommendations", render = render_doctor_recommendations },
	} },
}

local descriptions = {
	status = "Overview of the plugin state: enabled flag, active layout, detection provider, langmap size, mirrored mappings, command-line aliases, echo mode and configuration warnings.",
	["status.overview"] = "Overview of the plugin state: enabled flag, active layout, detection provider, langmap size, mirrored mappings, command-line aliases, echo mode and configuration warnings.",
	["status.statusline"] = "Preview of the statusline component in its default, uppercase, English and unknown variants, together with the current layout_info values.",
	["status.events"] = "User events emitted by the plugin while this panel is open. The log is local to the UI session and is never persisted.",
	["status.warnings"] = "Configuration warnings and doctor recommendations. Fix warnings in the setup table or in the external configuration file.",
	layouts = "Active and effective layouts, fallback behavior and whether English translation is currently disabled.",
	["layouts.active"] = "Active and effective layouts, fallback behavior and whether English translation is currently disabled.",
	["layouts.bundled"] = "Every bundled layout with its title and number of valid one-to-one character pairs.",
	["layouts.keyboard"] = "Physical US key positions compared with the selected national layout. A dot means that the physical key has no translation in this layout.",
	["layouts.reverse"] = "Reverse mapping from national characters back to English keys.",
	detection = "Latest detection result, configured provider policy and the raw value reported by the operating system.",
	["detection.current"] = "Latest detection result, configured provider policy and the raw value reported by the operating system.",
	["detection.providers"] = "Detection adapters in priority order. Provider probing runs asynchronously so the panel stays responsive.",
	["detection.environment"] = "Operating system, session type, compositor, remote and platform flags used to select a detection adapter.",
	mappings = "Mapping mirroring settings, the keymap hook state and the number of mirrored bindings.",
	["mappings.settings"] = "Mapping mirroring settings, the keymap hook state and the number of mirrored bindings.",
	["mappings.modes"] = "Bindings grouped by Vim mode. Press ] or l to focus the content pane, move with j/k, press i or o to expand a mode, Left to return to the group and Right to enter it.",
	["mappings.list"] = "All mirrored bindings grouped by mode and scope. Press / to search by mode, source binding, mirrored binding or scope.",
	["mappings.filters"] = "Exclude patterns and explicit native variants from the effective configuration.",
	cmdline = "Command-line alias settings and the abbreviations registered at runtime.",
	["cmdline.settings"] = "Command-line alias settings and the number of active abbreviations.",
	["cmdline.added"] = "Native-to-English abbreviations currently registered by the plugin.",
	["cmdline.configured"] = "Aliases and explicit extra pairs loaded from the effective configuration.",
	echo = "Echo is a diagnostic on_key capture. This page shows state, mode previews and the keys captured while echo is enabled.",
	["echo.state"] = "Echo is a diagnostic on_key capture. This page shows state, mode previews and the keys captured while echo is enabled.",
	["echo.modes"] = "Preview of every echo mode using the Russian character й as a sample.",
	["echo.history"] = "Last captured keys while echo is enabled. The panel only reads history and never toggles echo.",
	config = "Effective configuration after defaults, external file, setup options and environment overrides.",
	["config.effective"] = "Effective configuration after defaults, external file, setup options and environment overrides.",
	["config.source"] = "Where the configuration came from, which file was attempted and which PKB_* environment variables are set.",
	["config.warnings"] = "Configuration warnings and recommendations from the doctor report.",
	doctor = "Environment report used to diagnose detection problems and to configure the plugin safely.",
	["doctor.summary"] = "Environment report used to diagnose detection problems and to configure the plugin safely.",
	["doctor.tools"] = "Availability of helper executables used by the platform detection adapters.",
	["doctor.recommendations"] = "Actionable suggestions generated from the current configuration and environment.",
}

for _, root in ipairs(nodes) do
	root.description = descriptions[root.id]
	for _, child in ipairs(root.children or {}) do
		child.description = descriptions[child.id] or root.description
	end
end

function M.tree()
	return nodes
end

function M.find(id)
	for _, node in ipairs(nodes) do
		if node.id == id then
			return node
		end
		for _, child in ipairs(node.children or {}) do
			if child.id == id then
				return child, node
			end
		end
	end
	return nil
end

function M.first_child(root)
	return root.children and root.children[1] or root
end

function M.render(node, data, ctx)
	if not node then
		return doc("Not found", { L(C("The selected panel does not exist.", "PhyKeyboardUIError")) })
	end
	local ok, result = pcall(node.render, data, ctx)
	if not ok then
		return doc(node.title or "Error", {
			L(C("Render failed: " .. tostring(result), "PhyKeyboardUIError")),
		})
	end
	local lines = {}
	if node.description and node.description ~= "" then
		lines[#lines + 1] = section(ctx.width, "ABOUT")
		for _, text in ipairs(F.wrap(node.description, math.max(8, ctx.width - 2))) do
			lines[#lines + 1] = L(C("  ", "PhyKeyboardUISeparator"), C(text, "PhyKeyboardUIInfo"))
		end
		lines[#lines + 1] = {}
	end
	local offset = #lines
	for _, line in ipairs(result.lines or {}) do
		lines[#lines + 1] = line
	end
	if result.selectables then
		local selectables = {}
		for _, item in ipairs(result.selectables) do
			selectables[#selectables + 1] = { id = item.id, line = item.line + offset }
		end
		result.selectables = selectables
	end
	result.lines = lines
	return result
end

function M.help(ctx)
	local lines = {
		section(ctx.width, "PHYSICAL-KEYBOARD UI"),
		kv("j / k", "move selection"),
		kv("h / l", "focus tree / content (same as [ / ])"),
		kv("Tab", "next root section"),
		kv("S-Tab", "previous root section"),
		kv("g / G", "first / last item"),
		kv("[ / ]", "focus tree / content pane"),
		kv("i / o", "open item or expand mode group"),
		kv("Left / Right", "parent group / enter mode group"),
		kv("/", "search mirrored bindings in the bottom help window"),
		kv("Ctrl-d / Ctrl-u", "scroll content"),
		kv("r", "refresh snapshot and probes"),
		kv("?", "toggle this help"),
		kv("Esc", "content → tree, then close"),
		kv("q", "close panel"),
		{},
		L(C("This panel is display-only. Change settings with :PhyKeyboard commands.", "PhyKeyboardUIMuted")),
	}
	return doc("Help", lines)
end

return M
