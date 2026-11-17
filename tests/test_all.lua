-- Test suite for physical-keyboard.nvim
-- Run with:
--   nvim --headless --clean -u NONE -l tests/test_all.lua

vim.opt.rtp:prepend(vim.fn.getcwd())

local override_path = vim.fn.tempname() .. "-pkb-overrides.json"
vim.env.PKB_OVERRIDES = override_path
vim.fn.delete(override_path)

local pkb = require("physical-keyboard")
local config = require("physical-keyboard.config")
local layouts = require("physical-keyboard.layouts")
local langmap = require("physical-keyboard.langmap")
local mappings = require("physical-keyboard.mappings")
local cmdline = require("physical-keyboard.cmdline")
local echo = require("physical-keyboard.echo")
local options = require("physical-keyboard.options")

local passed = 0
local failed = 0

local function report(ok, message, detail)
	if ok then
		passed = passed + 1
		print("[PASS] " .. message)
	else
		failed = failed + 1
		print("[FAIL] " .. message .. (detail and (": " .. detail) or ""))
	end
end

local function eq(actual, expected, message)
	local ok = actual == expected
	report(ok, message, ok and nil or ("expected %s, got %s"):format(tostring(expected), tostring(actual)))
end

local function truthy(value, message)
	report(not not value, message)
end

local function contains(value, needle, message)
	truthy(type(value) == "string" and value:find(needle, 1, true) ~= nil, message)
end

local function disable()
	pcall(pkb.disable)
end

---------------------------------------------------------------------------
-- 1. Bundled layout data
---------------------------------------------------------------------------
do
	print("\n== layout registry ==")
	local ids = layouts.ids()
	truthy(#ids >= 18, "bundles many layouts (" .. #ids .. ")")
	truthy(layouts.get("ru") ~= nil, "Russian layout exists")
	truthy(layouts.get("de") ~= nil, "German layout exists")
	truthy(layouts.get("fr") ~= nil, "French layout exists")

	eq(layouts.get("ru").forward["q"], "й", "ru: q -> й")
	eq(layouts.get("ru").forward["Q"], "Й", "ru: uppercase Q -> Й is generated")
	eq(layouts.get("de").forward["y"], "z", "de: y -> z (QWERTZ)")
	eq(layouts.get("fr").forward["a"], "q", "fr: a -> q (AZERTY)")

	eq(layouts.match("Russian", { "ru", "de" }), "ru", "match provider name 'Russian'")
	eq(layouts.match("com.apple.keylayout.German", { "de" }), "de", "match macOS layout id")
	eq(layouts.match("us", { "ru" }), nil, "plain US layout does not match")
	truthy(layouts.is_english("com.apple.keylayout.US"), "detects English layout id")
	truthy(layouts.is_english("xkb:us::eng"), "detects IBus English id")
end

---------------------------------------------------------------------------
-- 2. Pure translation
---------------------------------------------------------------------------
do
	print("\n== translation ==")
	mappings.setup({ active_ids = { "ru" } })
	eq(mappings.translate("ciw"), "сшц", "ru: ciw -> сшц")
	mappings.setup({ active_ids = { "fr" } })
	eq(mappings.translate("ciw"), "ciz", "fr: ciw -> ciz")
	mappings.setup({ active_ids = { "ru" } })
	eq(mappings.translate("<C-w>"), "<C-ц>", "ru: <C-w> -> <C-ц>")
	eq(mappings.translate("<Leader>ff"), "<Leader>аа", "ru: <Leader>ff -> <Leader>аа")
	eq(mappings.translate("<Plug>(test)"), "<Plug>(test)", "skips <Plug>")
	eq(mappings.translate("<SID>Test"), "<SID>Test", "skips <SID>")
	eq(mappings.translate("<CR>"), "<CR>", "keeps special keys")
	eq(select(2, mappings.translate("123")), false, "text without mapping is unchanged")

	mappings.setup({ active_ids = { "ru", "de" } })
	local variants = mappings.variants("yy")
	local by_layout = {}
	for _, variant in ipairs(variants) do
		by_layout[variant.layout] = variant.lhs
	end
	eq(by_layout.ru, "нн", "multi-layout: ru variant is generated")
	eq(by_layout.de, "zz", "multi-layout: de variant is generated")
	mappings.setup({ active_ids = { "ru" } })
end

---------------------------------------------------------------------------
-- 3. langmap builder
---------------------------------------------------------------------------
do
	print("\n== langmap ==")
	local value = langmap.build({ "ru" }, false)
	contains(value, "й;q", "langmap contains ru pair")
	truthy(langmap.count(value) >= 40, "langmap has many pairs")
	truthy(langmap.set(value), "langmap can be applied")
	eq(vim.o.langremap, false, "langremap is disabled")
	eq(vim.o.langmap, value, "langmap option is set")

	local full = langmap.build({ "de", "fr" }, false)
	local unique = langmap.build({ "de", "fr" }, true)
	truthy(#unique <= #full, "unique map is not bigger than full map")
	truthy(#unique > 0, "unique map keeps non-conflicting pairs")

	langmap.restore()
end

---------------------------------------------------------------------------
-- 4. Full setup, keymap hook, cmdline, status
---------------------------------------------------------------------------
do
	print("\n== setup / mappings / cmdline ==")
	disable()
	mappings.setup({ active_ids = { "ru" } })

	local instance = pkb.setup({
		enable = true,
		notify = false,
		active_layouts = { "ru" },
		detect = { enabled = false },
		mappings = { automapping = false, hack_keymap = true },
	})

	truthy(instance.config.enable, "setup stores config")
	truthy(mappings.is_hacked(), "keymap API is hooked")

	vim.keymap.set("n", "<Leader>qw", function()
		vim.g.pkb_hit = true
	end, { desc = "test mapping" })

	truthy(vim.fn.maparg("<Leader>йц", "n") ~= "", "vim.keymap.set is mirrored to ru")
	vim.api.nvim_feedkeys(
		vim.api.nvim_replace_termcodes("<Leader>йц", true, false, true),
		"x",
		false
	)
	truthy(vim.g.pkb_hit, "mirrored mapping callback runs")

	eq(cmdline.resolve("w"), "ц", "cmdline: w -> ц")
	eq(cmdline.resolve("wq"), "цй", "cmdline: wq -> цй")
	truthy(cmdline.count() > 0, "command-line abbreviations are registered")

	local status = pkb.status()
	truthy(status.enabled, "status reports enabled")
	truthy(status.mappings.created > 0, "status reports mirrored mappings")
	truthy(status.langmap_pairs > 0, "status reports langmap pairs")

	local use_ok = pkb.use_layout("de")
	truthy(use_ok, "use_layout accepts a known layout")
	eq(pkb.status().current_layout, "de", "forced layout is applied")
	eq(pkb.use_layout("nope"), false, "use_layout rejects unknown layout")
	pkb.use_layout(nil)

	disable()
	truthy(not mappings.is_hacked(), "disable unhooks keymap API")
	eq(vim.fn.maparg("<Leader>йц", "n"), "", "disable removes mirrored mappings")
	eq(vim.o.langmap, "", "disable restores langmap")
	eq(cmdline.count(), 0, "disable removes command-line abbreviations")
end

---------------------------------------------------------------------------
-- 5. Automapping of pre-existing mappings
---------------------------------------------------------------------------
do
	print("\n== automapping ==")
	disable()
	vim.keymap.set("n", "<Leader>aa", function()
		vim.g.pkb_pre = true
	end, { desc = "pre-existing" })

	pkb.setup({
		enable = true,
		notify = false,
		active_layouts = { "ru" },
		detect = { enabled = false },
		mappings = { automapping = false, hack_keymap = true },
	})

	local created = pkb.refresh_mappings()
	truthy(created > 0, "refresh_mappings mirrors existing mappings")
	truthy(vim.fn.maparg("<Leader>фф", "n") ~= "", "pre-existing mapping is mirrored")
	vim.api.nvim_feedkeys(
		vim.api.nvim_replace_termcodes("<Leader>фф", true, false, true),
		"x",
		false
	)
	truthy(vim.g.pkb_pre, "mirrored pre-existing callback runs")

	disable()
	vim.keymap.del("n", "<Leader>aa")
end

---------------------------------------------------------------------------
-- 6. Buffer-local mappings
---------------------------------------------------------------------------
do
	print("\n== buffer-local mappings ==")
	disable()
	pkb.setup({
		enable = true,
		notify = false,
		active_layouts = { "ru" },
		detect = { enabled = false },
		mappings = { automapping = false, hack_keymap = true },
	})

	vim.cmd("enew")
	local bufnr = vim.api.nvim_get_current_buf()
	vim.keymap.set("n", "<Leader>bd", function() end, { buffer = bufnr, desc = "buffer" })

	local found = vim.fn.maparg("<Leader>ив", "n", false, true)
	truthy(type(found) == "table" and found.buffer == 1, "buffer-local mapping is mirrored")

	eq(
		mappings.automapping({ buffer = true, bufnr = 999999 }),
		0,
		"invalid buffer is ignored"
	)

	disable()
end

---------------------------------------------------------------------------
-- 6b. Read-only UI data APIs
---------------------------------------------------------------------------
do
	print("\n== ui data apis ==")
	disable()
	pkb.setup({
		enable = true,
		notify = false,
		active_layouts = { "ru" },
		detect = { enabled = false },
		mappings = { automapping = false, hack_keymap = true },
	})

	vim.keymap.set("n", "<Leader>ui-test", function() end, { desc = "ui test" })
	local mirrored = mappings.list()
	local found = false
	for _, item in ipairs(mirrored) do
		if item.source_lhs == "<Leader>ui-test" then
			found = true
			eq(item.mode, "n", "mappings.list records mode")
			eq(item.global, true, "mappings.list records scope")
			truthy(item.lhs ~= item.source_lhs, "mappings.list records translated lhs")
		end
	end
	truthy(found, "mappings.list exposes mirrored mapping source")

	local preview = echo.preview("hex", "й")
	truthy(type(preview) == "string" and preview:find("0x", 1, true) ~= nil, "echo.preview formats hex")
	eq(echo.preview("bogus", "й"), nil, "echo.preview rejects invalid mode")
	eq(echo.preview("code", "й"), "1081", "echo.preview reports unicode codepoint")
	truthy(type(echo.history()) == "table", "echo.history returns a list")

	local providers = require("physical-keyboard.detect.providers")
	local probe_done = false
	local probe_results = nil
	providers.probe_async({ providers = { "__none__" }, timeout = 50 }, function(results)
		probe_done = true
		probe_results = results
	end)
	vim.wait(1000, function()
		return probe_done
	end, 10)
	truthy(probe_done, "providers.probe_async completes")
	truthy(type(probe_results) == "table" and #probe_results == 0, "providers.probe_async handles empty selection")

	disable()
end

---------------------------------------------------------------------------
-- 6c. Floating UI
---------------------------------------------------------------------------
do
	print("\n== floating ui ==")
	disable()
	pkb.setup({
		enable = true,
		notify = false,
		active_layouts = { "ru" },
		detect = { enabled = false },
		mappings = { automapping = false, hack_keymap = true },
	})

	local ui = require("physical-keyboard.ui")
	local pages = require("physical-keyboard.ui.pages")
	vim.keymap.set("n", "<Leader>ui-bind", function() end, { desc = "ui bind" })
	local ok, err = pcall(ui.open)
	truthy(ok, "ui.open succeeds")
	truthy(ui.is_open(), "ui reports open")
	eq(ui.current(), "status.overview", "ui starts on overview")

	local buf = vim.api.nvim_get_current_buf()
	eq(vim.bo[buf].buftype, "nofile", "ui buffer is nofile")
	eq(vim.bo[buf].filetype, "physical-keyboard-ui", "ui buffer filetype")
	contains(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"), "physical-keyboard", "ui header is rendered")

	local ui_keys = {}
	for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
		ui_keys[map.lhs] = true
	end
	truthy(ui_keys["ш"] and ui_keys["щ"], "ui i/o keys have Russian variants")
	truthy(ui_keys["х"] and ui_keys["ъ"], "ui [ ] keys have Russian variants")
	truthy(ui_keys["."], "ui / search key has a Russian variant")

	for _, root in ipairs(pages.tree()) do
		local select_ok, select_err = pcall(ui.select, root.id)
		truthy(select_ok, "ui renders section: " .. root.id .. " " .. tostring(select_err))
		for _, child in ipairs(root.children or {}) do
			local child_ok, child_err = pcall(ui.select, child.id)
			truthy(child_ok, "ui renders page: " .. child.id .. " " .. tostring(child_err))
		end
	end

	ui.select("status.overview")
	contains(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"), "ABOUT", "ui page starts with an explanation section")
	ui.select("layouts")
	eq(ui.current(), "layouts.active", "selecting a category focuses its first item")
	ui.tree_move(-1)
	eq(ui.current(), "layouts", "tree can move back up to the category")
	ui.tree_move(1)
	eq(ui.current(), "layouts.active", "tree can move back down to the first item")
	ui.select("status.overview")
	ui.set_pane("content")
	truthy((ui.content_selected() or ""):match("^line:") ~= nil, "plain content lines are selectable")
	local first_line = ui.content_selected()
	ui.content_move(1)
	truthy(ui.content_selected() ~= first_line, "content moves between plain text lines")
	ui.set_pane("tree")

	local help_buf = ui.help_buffer()
	truthy(type(help_buf) == "number" and vim.api.nvim_buf_is_valid(help_buf), "ui creates a separate help buffer")
	truthy(help_buf ~= buf, "help buffer is separate from the main panel")

	truthy(ui.set_pane("content"), "ui switches to content pane")
	eq(ui.pane(), "content", "ui reports content pane")
	truthy(vim.api.nvim_win_get_cursor(0)[2] > 0, "cursor moves into the content pane")
	contains(vim.wo[0].winhl, "PhyKeyboardUIBorderContent", "content pane changes the window focus color")
	ui.set_pane("tree")
	eq(ui.pane(), "tree", "ui reports tree pane")
	contains(vim.wo[0].winhl, "PhyKeyboardUIBorderTree", "tree pane changes the window focus color")

	ui.select("mappings.modes")
	ui.set_pane("content")
	eq(ui.content_selected(), "group:n", "by mode starts on the first group")
	ui.content_activate()
	contains(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"), "ui-bind", "by mode expands a group")
	ui.content_move(1)
	truthy((ui.content_selected() or ""):match("^item:n:") ~= nil, "content moves into bindings")
	ui.content_move(-1)
	eq(ui.content_selected(), "group:n", "content moves back to the group")

	ui.search("ui-bind")
	local search_text = table.concat(vim.api.nvim_buf_get_lines(help_buf, 0, -1, false), "\n")
	local body_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	truthy(search_text:find("SEARCH", 1, true) ~= nil, "search block is rendered in the help window")
	truthy(search_text:find("ui-bind", 1, true) ~= nil, "search block shows the query")
	truthy(body_text:find("ui-bind", 1, true) ~= nil, "search finds a mirrored binding")
	truthy(body_text:find("│", 1, true) ~= nil, "panes are separated by a divider")
	ui.search("__no_such_binding__")
	contains(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"), "No mirrored bindings match", "search renders an empty result")
	ui.search("")
	ui.select("mappings.list")
	contains(table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n"), "MODE n", "mirrored list groups bindings by mode")

	local hl = vim.api.nvim_get_hl(0, { name = "PhyKeyboardUIOK" })
	truthy(next(hl) ~= nil, "ui highlight group is defined")

	pkb.disable()
	ui.select("status.overview")
	local disabled_text = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
	truthy(disabled_text:find("disabled", 1, true) ~= nil, "ui renders disabled plugin state")

	local esc_callback
	for _, map in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
		if map.lhs == "<Esc>" then
			esc_callback = map.callback
		end
	end
	if type(esc_callback) == "function" then
		ui.set_pane("content")
		esc_callback()
		eq(ui.pane(), "tree", "Esc returns from content to tree")
		esc_callback()
		truthy(not ui.is_open(), "Esc closes the window from the tree")
	end
	ui.close()
	truthy(not ui.is_open(), "ui.close closes the panel")
	truthy(pcall(ui.refresh), "ui.refresh after close is safe")
	ui.open()
	ui.close()

	disable()
end

---------------------------------------------------------------------------
-- 7. Options and override file
---------------------------------------------------------------------------
do
	print("\n== options and overrides ==")
	vim.fn.delete(override_path)
	pkb.setup({
		enable = true,
		notify = "errors",
		active_layouts = { "ru" },
		detect = { enabled = false },
		fallback = "ru",
		mappings = { automapping = false },
	})
	truthy(options.spec("notify") ~= nil, "option spec is registered")
	eq(pkb.get_option("notify"), "errors", "option getter reads the current config")
	truthy(langmap.count(langmap.current()) > 0, "langmap is applied before option changes")

	local ok, err, persisted = pkb.set_option("notify", "off")
	truthy(ok, "set_option applies an enum " .. tostring(err))
	truthy(persisted, "set_option persists when overrides are enabled")
	eq(pkb.get_option("notify"), "off", "enum value changes at runtime")
	eq(vim.fn.filereadable(override_path), 1, "override file is created")
	local raw = vim.json.decode(table.concat(vim.fn.readfile(override_path), "\n"))
	eq(raw.notify, "off", "override file stores the changed value")

	pkb.setup({
		enable = true,
		notify = "errors",
		active_layouts = { "ru" },
		detect = { enabled = false },
		fallback = "ru",
		mappings = { automapping = false },
	})
	eq(pkb.get_option("notify"), "off", "override is loaded by the next setup")

	local reset_ok = pkb.reset_overrides()
	truthy(reset_ok, "reset_overrides succeeds")
	eq(vim.fn.filereadable(override_path), 0, "reset removes the override file")
	eq(pkb.get_option("notify"), "errors", "reset restores the base config")

	eq(pkb.set_option("langmap.enabled", false), true, "langmap can be disabled")
	eq(langmap.count(langmap.current()), 0, "disabling langmap clears pairs")
	pkb.set_option("langmap.enabled", true)
	truthy(langmap.count(langmap.current()) > 0, "enabling langmap reapplies pairs")

	pkb.set_option("mappings.modes", { "n", "i" })
	eq(table.concat(pkb.get_option("mappings.modes"), ","), "n,i", "multi option changes")
	local bad, bad_err = pkb.set_option("mappings.modes", {})
	truthy(not bad, "empty multi is rejected: " .. tostring(bad_err))

	pkb.set_option("detect.provider", "niri")
	eq(pkb.config.detect.provider, "niri", "provider can be forced")
	pkb.set_option("detect.provider", "auto")
	eq(pkb.config.detect.provider, nil, "auto removes the provider override")

	pkb.set_option("active_layouts", { "ru", "de" })
	eq(table.concat(pkb.get_option("active_layouts"), ","), "ru,de", "active layouts change")
	truthy(not pkb.set_option("no.such.option", true), "unknown options are rejected")

	local disabled_path = vim.fn.tempname() .. "-disabled.json"
	vim.env.PKB_OVERRIDES = disabled_path
	pkb.setup({ overrides = false, active_layouts = { "ru" }, detect = { enabled = false } })
	eq(pkb.overrides_info().enabled, false, "overrides loading can be disabled in setup")
	local session_ok, _, session_persisted = pkb.set_option("notify", "all")
	truthy(session_ok, "set_option still works when overrides are disabled")
	truthy(not session_persisted, "nothing is persisted when overrides are disabled")
	eq(vim.fn.filereadable(disabled_path), 0, "disabled overrides do not create a file")
	eq(pkb.get_option("notify"), "all", "disabled overrides change the session")

	vim.env.PKB_OVERRIDES = override_path
	vim.fn.delete(disabled_path)
	vim.fn.delete(override_path)
	disable()
end

---------------------------------------------------------------------------
-- 8. Settings UI and picker
---------------------------------------------------------------------------
do
	print("\n== settings UI ==")
	vim.fn.delete(override_path)
	pkb.setup({
		enable = true,
		notify = "errors",
		active_layouts = { "ru" },
		detect = { enabled = false },
		fallback = "ru",
		mappings = { automapping = false },
	})

	local ui = require("physical-keyboard.ui")
	ui.open()
	ui.select("config.effective")
	ui.set_pane("content")
	eq(ui.content_selected(), "setting:enable", "effective config selects the first editable row")
	local selectables = ui.content_selectables()
	local seen = {}
	for _, item in ipairs(selectables) do
		seen[item.id] = true
	end
	truthy(seen["setting:notify"], "notify row is editable")
	truthy(seen["setting:detect.provider"], "nil provider is still editable")
	truthy(seen["setting:mappings.modes"], "multi option row is editable")

	ui.activate_setting("notify")
	local picker = ui.picker()
	truthy(picker.open, "enum option opens the picker")
	eq(picker.items[1].label, "all — every message", "picker shows enum choices")
	ui.picker_move(2)
	ui.picker_confirm()
	eq(pkb.get_option("notify"), "off", "picker applies the chosen enum value")
	truthy(not ui.picker().open, "picker closes after apply")

	ui.activate_setting("detect.provider")
	ui.picker_move(1)
	ui.picker_cancel()
	eq(pkb.config.detect.provider, nil, "picker cancel leaves the value unchanged")
	truthy(not ui.picker().open, "picker closes on cancel")

	ui.activate_setting("mappings.modes")
	ui.picker_move(4)
	ui.picker_toggle()
	ui.picker_confirm()
	local modes = table.concat(pkb.get_option("mappings.modes"), ",")
	truthy(modes:find("i", 1, true) ~= nil, "multi picker toggles a mode")
	truthy(vim.fn.filereadable(override_path) == 1, "UI changes write the override file")

	ui.select("config.effective")
	ui.set_pane("content")
	ui.delete_overrides()
	truthy(ui.picker().open, "delete override opens a confirmation picker")
	ui.picker_confirm()
	eq(pkb.overrides_info().exists, false, "confirmation deletes the override file")
	eq(pkb.get_option("notify"), "errors", "deleting overrides reloads base config")

	ui.close()
	vim.fn.delete(override_path)
	disable()
end

---------------------------------------------------------------------------
-- 9. Echo keyboard
---------------------------------------------------------------------------
do
	print("\n== echo ==")
	echo.setup({ notify = function() end })
	echo.enable(true)
	truthy(echo.is_enabled(), "echo enables")
	echo.set_mode("hex")
	eq(echo.mode(), "hex", "echo mode can be changed")
	eq(echo.set_mode("invalid"), false, "echo rejects invalid mode")
	echo.enable(false)
	truthy(not echo.is_enabled(), "echo disables")
end

---------------------------------------------------------------------------
-- 8. Config compatibility and custom layouts
---------------------------------------------------------------------------
do
	print("\n== config ==")
	local resolved = config.resolve({ active_layouts = "ru" })
	eq(resolved.active_layouts[1], "ru", "string active_layouts is normalized")

	local custom_ok = layouts.register("test-custom", {
		title = "Custom",
		names = { "custom" },
		map = { ["q"] = "x" },
	})
	truthy(custom_ok, "custom layout can be registered")
	eq(layouts.get("test-custom").forward["q"], "x", "custom layout mapping is available")
	eq(layouts.match("custom", { "test-custom" }), "test-custom", "custom layout is matched")

	local override_file = vim.fn.tempname() .. ".json"
	vim.fn.writefile({ vim.json.encode({ notify = "all" }) }, override_file)
	vim.env.PKB_OVERRIDES = override_file
	local loaded = config.resolve({ notify = "off" })
	eq(loaded.notify, "all", "override file wins over setup options")
	local ignored = config.resolve({ overrides = false, notify = "off" })
	eq(ignored.notify, "off", "overrides=false ignores the override file")
	eq(ignored.overrides.enabled, false, "overrides=false is reported in the resolved config")
	vim.env.PKB_OVERRIDES = override_path
	vim.fn.delete(override_file)
end

---------------------------------------------------------------------------
-- 9. External config file and environment overrides
---------------------------------------------------------------------------
do
	print("\n== external config ==")
	disable()
	local path = vim.fn.tempname() .. ".lua"
	vim.fn.writefile({
		"return {",
		'  active_layouts = { "de" },',
		'  notify = "off",',
		'  mappings = { exclude = { "<Leader>skip" } },',
		'  cmdline = { extra = { ["цц"] = "w" } },',
		"}",
	}, path)

	local resolved = config.resolve({ config_file = path, detect = { enabled = false } })
	eq(resolved.active_layouts[1], "de", "config file active_layouts is loaded")
	eq(resolved.notify, "off", "config file notify is loaded")
	eq(resolved.source.file, path, "config source records the file")
	eq(resolved.mappings.exclude[1], "<Leader>skip", "config file exclusions are loaded")
	eq(resolved.cmdline.extra["цц"], "w", "config file cmdline extras are loaded")

	local old_config = vim.env.PKB_CONFIG
	local old_layout = vim.env.PKB_LAYOUT
	local old_disable = vim.env.PKB_DISABLE
	local old_debug = vim.env.PKB_DEBUG
	vim.env.PKB_CONFIG = path
	vim.env.PKB_LAYOUT = "ru"
	vim.env.PKB_DISABLE = "1"
	vim.env.PKB_DEBUG = "1"
	local from_env = config.resolve({})
	eq(from_env.active_layouts[1], "ru", "PKB_LAYOUT overrides active layouts")
	eq(from_env.enable, false, "PKB_DISABLE disables the plugin")
	eq(from_env.echo.enabled, true, "PKB_DEBUG enables echo")
	eq(from_env.echo.mode, "debug", "PKB_DEBUG selects debug mode")
	eq(from_env.notify, "all", "PKB_DEBUG enables all notifications")
	truthy(from_env.source.env.layout ~= nil, "environment overrides are recorded")
	local env_off = config.resolve({ env = false })
	eq(env_off.config_file, false, "env=false ignores PKB_CONFIG")
	eq(env_off.enable, true, "env=false ignores PKB_DISABLE")

	vim.env.PKB_CONFIG = old_config
	vim.env.PKB_LAYOUT = old_layout
	vim.env.PKB_DISABLE = old_disable
	vim.env.PKB_DEBUG = old_debug

	local missing = config.resolve({ config_file = path .. ".missing" })
	truthy(#missing.warnings > 0, "missing config file produces a warning")
	vim.fn.delete(path)
end

---------------------------------------------------------------------------
-- 10. Config validation
---------------------------------------------------------------------------
do
	print("\n== config validation ==")
	local resolved = config.resolve({
		active_layouts = { "ru" },
		fallback = "not-a-layout",
		detect = { min_interval = -1, remote = "sometimes" },
		mappings = { modes = { "n", "bogus" } },
		bogus_key = true,
	})
	eq(resolved.fallback, "unique", "unknown fallback is replaced")
	truthy(#resolved.warnings > 0, "validation warnings are collected")
	local joined = table.concat(resolved.warnings, "\n")
	contains(joined, "unknown config key 'bogus_key'", "unknown top-level key is reported")
	contains(joined, "unknown fallback", "unknown fallback is reported")
	contains(joined, "unknown mapping mode", "unknown mapping mode is reported")
	truthy(#resolved.mappings.modes >= 1, "valid mapping modes are kept")
	eq(resolved.detect.remote, "auto", "invalid detect.remote falls back to auto")

	eq(config.resolve({ notify = false }).notify, "errors", "notify=false means errors only")
	eq(config.resolve({ notify = true }).notify, "all", "notify=true means all")
	eq(config.resolve({ notify = "off" }).notify, "off", "notify=off is accepted")
	truthy(config.should_notify("errors", vim.log.levels.WARN), "errors mode shows warnings")
	truthy(not config.should_notify("errors", vim.log.levels.INFO), "errors mode hides info")
	truthy(config.should_notify("all", vim.log.levels.INFO), "all mode shows info")
	truthy(not config.should_notify("off", vim.log.levels.ERROR), "off mode hides errors")
end

---------------------------------------------------------------------------
-- 11. Command-line extras
---------------------------------------------------------------------------
do
	print("\n== cmdline extras ==")
	disable()
	cmdline.setup({
		enabled = true,
		active_ids = { "ru" },
		aliases = {},
		extra = { ["цц"] = "w" },
	})
	cmdline.enable()
	eq(cmdline.added()["цц"], "w", "explicit cmdline extra is registered")
	truthy(cmdline.remove("цц"), "explicit cmdline extra can be removed")
	eq(cmdline.added()["цц"], nil, "removed cmdline extra is gone")
	truthy(cmdline.add("цц", "w"), "cmdline.add works")
	eq(cmdline.added()["цц"], "w", "cmdline.add registers immediately")
	cmdline.disable()

	disable()
	pkb.setup({
		enable = true,
		notify = false,
		active_layouts = { "ru" },
		detect = { enabled = false },
		mappings = { automapping = false, hack_keymap = false },
	})
	pkb.set_cmdline(false)
	eq(cmdline.count(), 0, "set_cmdline(false) removes aliases")
	pkb.set_cmdline(true)
	truthy(cmdline.count() > 0, "set_cmdline(true) restores aliases")
	disable()
end

---------------------------------------------------------------------------
-- 12. Mapping exclusions and extras
---------------------------------------------------------------------------
do
	print("\n== mapping filters ==")
	disable()
	mappings.setup({
		active_ids = { "ru" },
		exclude = { "<Leader>skip" },
		extra = { ["<Leader>zz"] = "<Leader>ZZ" },
	})
	eq(#mappings.variants("<Leader>skip"), 0, "excluded mapping has no variants")
	truthy(mappings.is_excluded("<Leader>skip"), "exclusion can be queried")
	eq(mappings.is_excluded("<Leader>keep"), false, "unrelated mapping is not excluded")
	local variants = mappings.variants("<Leader>zz")
	local found = false
	for _, variant in ipairs(variants) do
		if variant.layout == "extra" and variant.lhs == "<Leader>ZZ" then
			found = true
		end
	end
	truthy(found, "explicit mapping extra is generated")
	mappings.setup({ active_ids = { "ru" } })
end

---------------------------------------------------------------------------
-- 13. Statusline, events and callbacks
---------------------------------------------------------------------------
do
	print("\n== statusline / events ==")
	disable()
	pkb.setup({
		enable = true,
		notify = false,
		active_layouts = { "ru" },
		detect = {
			enabled = false,
			on_change = function(info)
				vim.g.pkb_on_change = info.id or "en"
			end,
		},
		mappings = { automapping = false, hack_keymap = false },
	})
	pkb.use_layout("ru")
	eq(pkb.statusline(), "RU", "statusline shows uppercase layout id")
	eq(pkb.statusline({ uppercase = false }), "ru", "statusline can show lowercase")
	pkb.use_layout("en")
	eq(pkb.statusline(), "EN", "statusline shows EN for English")
	eq(pkb.statusline({ english = "ENG" }), "ENG", "statusline English label is configurable")
	truthy(pkb.layout_info().english, "layout_info reports English")

	local group = vim.api.nvim_create_augroup("PkbTestEvents", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = "PhysicalKeyboardLayoutChanged",
		callback = function(args)
			vim.g.pkb_event_layout = args.data and args.data.id or "nil"
		end,
	})
	pkb.use_layout("de")
	vim.wait(500, function()
		return vim.g.pkb_event_layout ~= nil and vim.g.pkb_on_change ~= nil
	end, 10)
	eq(vim.g.pkb_event_layout, "de", "LayoutChanged User event is emitted")
	eq(vim.g.pkb_on_change, "de", "detect.on_change callback is called")
	eq(vim.g.physical_keyboard_layout, "de", "vim.g.physical_keyboard_layout is updated")
	vim.g.pkb_event_layout = nil
	vim.g.pkb_on_change = nil

	local enabled = pkb.toggle()
	eq(enabled, false, "toggle disables an enabled plugin")
	eq(pkb.toggle(), true, "toggle re-enables the plugin")
	disable()
end

---------------------------------------------------------------------------
-- 14. Doctor
---------------------------------------------------------------------------
do
	print("\n== doctor ==")
	disable()
	pkb.setup({
		enable = true,
		notify = false,
		active_layouts = { "ru" },
		detect = { enabled = false },
		mappings = { automapping = false, hack_keymap = false },
	})
	local info = pkb.doctor({ probe = false })
	eq(info.plugin, "physical-keyboard.nvim", "doctor reports plugin name")
	eq(info.version, pkb.version, "doctor reports version")
	truthy(type(info.session) == "table", "doctor reports session")
	truthy(type(info.layouts.active) == "table", "doctor reports active layouts")
	truthy(type(info.recommendations) == "table", "doctor reports recommendations")
	local encoded_ok, encoded = pcall(vim.json.encode, info)
	truthy(encoded_ok, "doctor output is JSON serializable")
	truthy(type(encoded) == "string" and #encoded > 10, "doctor JSON is not empty")
	contains(require("physical-keyboard.doctor").format(info), "Physical Keyboard doctor", "doctor formatter works")
	disable()
end

---------------------------------------------------------------------------
-- 15. Detection options and async path
---------------------------------------------------------------------------
do
	print("\n== detection options ==")
	local providers = require("physical-keyboard.detect.providers")
	local names = {}
	for _, provider in ipairs(providers.select({ provider = "niri" })) do
		names[#names + 1] = provider.name
	end
	eq(#names, 1, "detect.provider limits providers")
	eq(names[1], "niri", "detect.provider selects the requested provider")
	local allowed = providers.select({ providers = { "sway", "niri" } })
	eq(#allowed, 2, "detect.providers accepts a list")

	local detect = require("physical-keyboard.detect")
	detect.setup({ enabled = false, remote = "auto" })
	local disabled = detect.detect(true)
	eq(disabled.disabled, "config", "disabled detection reports config reason")

	local old_ssh = vim.env.SSH_CONNECTION
	vim.env.SSH_CONNECTION = "10.0.0.1 22 10.0.0.2 22"
	detect.setup({ enabled = true, remote = "auto", min_interval = 0 })
	local remote = detect.detect(true)
	eq(remote.disabled, "remote", "remote session disables detection")
	detect.setup({ enabled = true, remote = true, min_interval = 0 })
	truthy(not detect.remote_disabled(), "detect.remote=true overrides auto")
	vim.env.SSH_CONNECTION = old_ssh

	detect.setup({ enabled = false })
	local done = false
	detect.detect_async(true, function(result)
		done = true
		eq(result.disabled, "config", "async detection reports disabled state")
	end)
	vim.wait(500, function()
		return done
	end, 10)
	truthy(done, "async detection calls back")

	local empty_done = false
	providers.detect_async({ providers = { "nonexistent" } }, function(raw, name, err)
		empty_done = true
		eq(raw, nil, "unknown provider allowlist returns no raw layout")
		eq(name, nil, "unknown provider allowlist returns no provider")
		eq(err, nil, "unknown provider allowlist has no error")
	end)
	vim.wait(500, function()
		return empty_done
	end, 10)
	truthy(empty_done, "provider async runner handles an empty selection")
end

---------------------------------------------------------------------------
-- 16. Commands
---------------------------------------------------------------------------
do
	print("\n== commands ==")
	disable()
	pkb.setup({
		enable = true,
		notify = false,
		active_layouts = { "ru" },
		detect = { enabled = false },
		mappings = { automapping = false, hack_keymap = false },
	})
	local real_notify = vim.notify
	vim.notify = function() end
	for _, command in ipairs({
		"PhyKeyboard",
		"PhyKeyboardUI",
		"PhyKeyboardStatus",
		"PhyKeyboardConfig",
		"PhyKeyboardConfigReset",
		"PhyKeyboardDoctor",
		"PhyKeyboardList",
		"PhyKeyboardDetect",
		"PhyKeyboardMappings",
		"PhyKeyboardAliases",
	}) do
		local ok = pcall(vim.cmd, command)
		truthy(ok, "command exists: " .. command)
	end
	if vim.fn.exists(":PhyKeyboardUI") == 2 then
		pcall(vim.cmd, "PhyKeyboardUI")
		pcall(require("physical-keyboard.ui").close)
	end
	pcall(vim.cmd, "PhyKeyboardAliases add цц w")
	eq(cmdline.added()["цц"], "w", "alias add command registers")
	pcall(vim.cmd, "PhyKeyboardAliases remove цц")
	eq(cmdline.added()["цц"], nil, "alias remove command unregisters")
	local ok, err = pcall(vim.cmd, "PhyKeyboardReload")
	truthy(ok, "reload command works")
	vim.notify = real_notify
	truthy(pkb.config_file() ~= nil, "config_file returns a path")

	local edit_path = vim.fn.tempname() .. ".lua"
	local previous_file = pkb.config.config_file
	pkb.config.config_file = edit_path
	local edit_ok = pcall(pkb.edit_config)
	truthy(edit_ok, "edit_config opens/creates the file")
	eq(vim.fn.filereadable(edit_path), 1, "edit_config writes a template")
	contains(table.concat(vim.fn.readfile(edit_path), "\n"), "active_layouts", "template contains config keys")
	vim.cmd("silent! bwipeout!")
	pkb.config.config_file = previous_file
	vim.fn.delete(edit_path)

	pcall(vim.cmd, "PhyKeyboardToggle")
	eq(pkb.status().enabled, false, "toggle command disables")
	pcall(vim.cmd, "PhyKeyboardToggle")
	eq(pkb.status().enabled, true, "toggle command re-enables")
	disable()
end

---------------------------------------------------------------------------
-- 17. which-key integration
---------------------------------------------------------------------------
do
	print("\n== which-key integration ==")
	disable()

	local invalid = config.resolve({
		which_key = { enabled = "yes", display = "sometimes", separator = "" },
	})
	eq(invalid.which_key.display, nil, "invalid which-key display falls back to hide")
	eq(invalid.which_key.separator, "\\", "empty separator falls back to a backslash")
	truthy(#invalid.warnings > 0, "invalid which-key options warn")
	eq(config.resolve({ which_key = false }).which_key.enabled, false, "which_key=false disables it")
	truthy(options.spec("which_key.alongside") ~= nil, "which-key options are editable")
	local separator, separator_err = options.normalize(options.spec("which_key.separator"), "|")
	eq(separator, "|", "which-key separator accepts a custom string")
	eq(separator_err, nil, "which-key separator validation succeeds")

	local which_key = require("physical-keyboard.which_key")
	local fake_cfg = {
		loaded = true,
		version = "3.17.0",
		mappings = {
			{ lhs = "<Leader>wkt", group = true, desc = "find", mode = "n" },
		},
	}
	local cleared = 0
	local fake_wk = {
		_queue = {},
		add = function() end,
	}
	local saved = {
		wk = package.loaded["which-key"],
		cfg = package.loaded["which-key.config"],
		mp = package.loaded["which-key.mappings"],
		buf = package.loaded["which-key.buf"],
	}
	package.loaded["which-key"] = fake_wk
	package.loaded["which-key.config"] = fake_cfg
	package.loaded["which-key.mappings"] = {
		parse = function(specs)
			return vim.deepcopy(specs)
		end,
	}
	package.loaded["which-key.buf"] = {
		clear = function()
			cleared = cleared + 1
		end,
	}

	mappings.setup({ active_ids = { "ru" } })
	mappings.hack()
	vim.keymap.set("n", "<Leader>wktff", "<cmd>echo 1<cr>", { desc = "Find files" })
	mappings.unhack()
	which_key.setup({ enabled = true })
	which_key.refresh()

	local function find_spec(lhs)
		for _, spec in ipairs(fake_cfg.mappings) do
			if spec.lhs == lhs then
				return spec
			end
		end
		return nil
	end

	local hidden = find_spec("<Leader>цлеаа")
	truthy(hidden and hidden.hidden, "default which-key display hides mirrored mappings")
	truthy(find_spec("<Leader>цле") == nil, "hidden mode does not create a mirror group")
	truthy(cleared > 0, "which-key buffer cache is cleared")

	which_key.setup({ enabled = true, relative_group = true })
	which_key.refresh()
	local group = find_spec("<Leader>цле")
	truthy(group and group.group == "find", "relative_group copies the original group label")
	local visible = find_spec("<Leader>цлеаа")
	truthy(visible and visible.desc == "Find files", "relative_group shows the original description")
	truthy(not visible.hidden, "relative_group mapping is visible")

	which_key.setup({ enabled = true, relative_group = true, alongside = true, separator = "\\" })
	which_key.refresh()
	local alongside = find_spec("<Leader>wktff")
	truthy(
		alongside
			and alongside.desc:find("Find files", 1, true)
			and alongside.desc:find("\\", 1, true)
			and alongside.desc:find("<Leader>цлеаа", 1, true),
		"alongside appends mirrored keys to the original label"
	)
	truthy(find_spec("<Leader>цле") == nil, "alongside takes precedence over relative_group")
	local hidden_along = find_spec("<Leader>цлеаа")
	truthy(hidden_along and hidden_along.hidden, "alongside hides the separate mirrored entry")

	which_key.cleanup()
	local leftovers = 0
	for _, spec in ipairs(fake_cfg.mappings) do
		if spec._pkb then
			leftovers = leftovers + 1
		end
	end
	eq(leftovers, 0, "which-key cleanup removes registered specs")

	which_key.setup({ enabled = true })
	which_key.refresh()
	which_key.setup({ enabled = false })
	local disabled_leftovers = 0
	for _, spec in ipairs(fake_cfg.mappings) do
		if spec._pkb then
			disabled_leftovers = disabled_leftovers + 1
		end
	end
	eq(disabled_leftovers, 0, "disabling which_key removes registered specs")

	local v2_calls = {}
	package.loaded["which-key"] = {
		register = function(spec, opts)
			v2_calls[#v2_calls + 1] = { spec = spec, opts = opts }
		end,
	}
	package.loaded["which-key.config"] = nil
	package.loaded["which-key.mappings"] = nil
	package.loaded["which-key.buf"] = nil
	which_key.setup({ enabled = true })
	which_key.refresh()
	truthy(#v2_calls > 0, "which-key 2.x uses the legacy register API")
	local v2_hidden = nil
	for _, call in ipairs(v2_calls) do
		if call.spec["<Leader>цлеаа"] then
			v2_hidden = call.spec["<Leader>цлеаа"]
			eq(call.opts.mode, "n", "which-key 2.x receives the mapping mode")
		end
	end
	truthy(v2_hidden and v2_hidden.hidden, "which-key 2.x hides mirrored mappings")

	which_key.cleanup()
	mappings.cleanup()
	pcall(vim.keymap.del, "n", "<Leader>wktff")

	package.loaded["which-key"] = saved.wk
	package.loaded["which-key.config"] = saved.cfg
	package.loaded["which-key.mappings"] = saved.mp
	package.loaded["which-key.buf"] = saved.buf
end


---------------------------------------------------------------------------
-- 18. native listings
---------------------------------------------------------------------------
do
	print("\n== native listings ==")
	disable()
	local native = require("physical-keyboard.native")

	local cfg = config.resolve({ native = false })
	eq(cfg.native.enabled, false, "native=false disables native listings")
	local partial = config.resolve({ native = { api = false } })
	eq(partial.native.api, false, "native.api can be disabled independently")
	eq(partial.native.commandline, true, "native.commandline keeps its default")
	local invalid = config.resolve({ native = { api = "yes" } })
	eq(invalid.native.api, true, "invalid native.api falls back to true")
	truthy(#invalid.warnings > 0, "invalid native options warn")
	truthy(options.spec("native.api") ~= nil, "native options are editable")

	eq(native.analyze("nmap") and native.analyze("nmap").listing, true, "nmap is a listing")
	eq(native.analyze("nm") and native.analyze("nm").listing, true, "abbreviated nmap is a listing")
	eq(native.analyze("nmap <buffer>") and native.analyze("nmap <buffer>").listing, true, "nmap <buffer> is a listing")
	eq(native.analyze("nmap <leader>f") and native.analyze("nmap <leader>f").listing, true, "single LHS is a listing")
	eq(native.analyze("verbose nmap") and native.analyze("verbose nmap").listing, true, "verbose nmap is a listing")
	eq(native.analyze("filter /x/ nmap") and native.analyze("filter /x/ nmap").listing, true, "filtered nmap is a listing")
	eq(native.analyze("map!") and native.analyze("map!").listing, true, "map! is a listing")
	eq(
		native.analyze("nmap <expr> <leader>f") and native.analyze("nmap <expr> <leader>f").listing,
		true,
		"nmap <expr> with only an LHS is a listing"
	)
	eq(native.analyze("nmap <leader>f x").listing, false, "nmap lhs rhs is a definition")
	eq(native.analyze("nmap <expr> <leader>f x").listing, false, "expr definition is not a listing")
	eq(native.analyze("nmap <buffer> <leader>f x").listing, false, "buffer definition is not a listing")
	eq(native.analyze("nunmap x"), nil, "nunmap is not a listing")
	eq(native.analyze("mapclear"), nil, "mapclear is not a listing")
	eq(native.analyze("nmap | echo 1"), nil, "multi-command lines are ignored")

	mappings.cleanup()
	mappings.setup({ active_ids = { "ru" } })
	mappings.hack()

	vim.keymap.set("n", "zqzx", function() end, { desc = "native global" })
	local global_variant = mappings.variants("zqzx")[1].lhs
	truthy(vim.fn.maparg(global_variant, "n") ~= "", "global mirror exists before native filtering")
	local mirror = vim.fn.maparg(global_variant, "n", false, true)
	truthy(mappings.is_mirror(mirror), "mirrors use the dedicated pkb:mirror: marker")

	local buf = vim.api.nvim_create_buf(false, true)
	vim.keymap.set("n", "bqbz", function() end, { buffer = buf, desc = "native buffer" })
	local buffer_variant = mappings.variants("bqbz")[1].lhs

	native.setup({ enabled = true, commandline = true, api = true })
	truthy(native.status().api_patched, "native patches Lua keymap getters")

	local function lhs_list(list)
		local result = {}
		for _, item in ipairs(list) do
			result[item.lhs] = true
		end
		return result
	end

	local global_list = lhs_list(vim.api.nvim_get_keymap("n"))
	truthy(global_list["zqzx"], "getter keeps the original global mapping")
	truthy(not global_list[global_variant], "getter hides the global mirror")
	local buffer_list = lhs_list(vim.api.nvim_buf_get_keymap(buf, "n"))
	truthy(buffer_list["bqbz"], "buffer getter keeps the original mapping")
	truthy(not buffer_list[buffer_variant], "buffer getter hides the buffer mirror")
	truthy(vim.fn.maparg(global_variant, "n") ~= "", "getter filtering leaves the real mirror active")

	vim.keymap.set("n", "uiq", function() end, { desc = "pkb: UI internal" })
	local ui_mapping = nil
	for _, item in ipairs(vim.api.nvim_get_keymap("n")) do
		if item.lhs == "uiq" then
			ui_mapping = item
		end
	end
	truthy(ui_mapping ~= nil, "internal pkb: mappings are not treated as mirrors")

	local removed = mappings.suspend_mirrors()
	truthy(removed > 0, "suspend_mirrors removes mirrors")
	truthy(mappings.is_suspended(), "mapper reports a suspended state")
	eq(vim.fn.maparg(global_variant, "n"), "", "suspended global mirror is absent")
	local restored = mappings.resume_mirrors()
	truthy(restored > 0, "resume_mirrors restores mirrors")
	truthy(vim.fn.maparg(global_variant, "n") ~= "", "restored global mirror is active")
	truthy(not mappings.is_suspended(), "mapper clears the suspended state")

	native.setup({ enabled = true, commandline = true, api = false })
	local unfiltered = lhs_list(vim.api.nvim_get_keymap("n"))
	truthy(unfiltered[global_variant], "native.api=false exposes mirrors again")
	native.setup({ enabled = true, commandline = true, api = true })
	truthy(not lhs_list(vim.api.nvim_get_keymap("n"))[global_variant], "native.api=true hides mirrors again")

	native.disable()
	truthy(not native.status().api_patched, "native.disable restores the getters")
	local after_disable = lhs_list(vim.api.nvim_get_keymap("n"))
	truthy(after_disable[global_variant], "getters expose mirrors after native.disable")

	mappings.unhack()
	mappings.cleanup()
	pcall(vim.keymap.del, "n", "zqzx")
	pcall(vim.keymap.del, "n", "uiq")
	pcall(vim.api.nvim_buf_delete, buf, { force = true })
end

---------------------------------------------------------------------------
-- Summary
---------------------------------------------------------------------------
print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
