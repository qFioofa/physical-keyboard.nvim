-- Test suite for physical-keyboard.nvim
-- Run with:
--   nvim --headless --clean -u NONE -l tests/test_all.lua

vim.opt.rtp:prepend(vim.fn.getcwd())

local pkb = require("physical-keyboard")
local config = require("physical-keyboard.config")
local layouts = require("physical-keyboard.layouts")
local langmap = require("physical-keyboard.langmap")
local mappings = require("physical-keyboard.mappings")
local cmdline = require("physical-keyboard.cmdline")
local echo = require("physical-keyboard.echo")

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
-- 7. Echo keyboard
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
		"PhyKeyboardStatus",
		"PhyKeyboardConfig",
		"PhyKeyboardDoctor",
		"PhyKeyboardList",
		"PhyKeyboardDetect",
		"PhyKeyboardMappings",
		"PhyKeyboardAliases",
	}) do
		local ok = pcall(vim.cmd, command)
		truthy(ok, "command exists: " .. command)
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
-- Summary
---------------------------------------------------------------------------
print(("\n%d passed, %d failed"):format(passed, failed))
if failed > 0 then
	vim.cmd("cquit 1")
else
	vim.cmd("qa!")
end
