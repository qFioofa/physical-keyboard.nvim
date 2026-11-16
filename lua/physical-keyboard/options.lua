--- Editable option specifications shared by the core and the UI.
---
--- Each spec describes how a value is read, validated, formatted and which
--- choices a picker should offer. The core applies the actual runtime change;
--- this module only knows about the shape of the option.
local M = {}

local MODES = {
	{ value = "n", short = "n", label = "n — Normal", description = "Normal-mode commands and motions." },
	{ value = "x", short = "x", label = "x — Visual", description = "Visual-mode mappings." },
	{ value = "s", short = "s", label = "s — Select", description = "Select-mode mappings." },
	{ value = "o", short = "o", label = "o — Operator-pending", description = "Mappings while an operator waits for a motion." },
	{ value = "i", short = "i", label = "i — Insert", description = "Mirror Insert-mode mappings. Typed text is still never translated." },
	{ value = "c", short = "c", label = "c — Command-line", description = "Mirror Command-line-mode mappings." },
	{ value = "t", short = "t", label = "t — Terminal", description = "Mirror Terminal-mode mappings." },
}

local function nested(cfg, path)
	local node = cfg
	for part in tostring(path):gmatch("[^.]+") do
		if type(node) ~= "table" then
			return nil
		end
		node = node[part]
	end
	return node
end

local function layout_choices()
	local layouts = require("physical-keyboard.layouts")
	local result = {}
	for _, id in ipairs(layouts.ids()) do
		local layout = layouts.get(id)
		result[#result + 1] = {
			value = id,
			short = id,
			label = ("%s — %s"):format(id, layout and layout.title or id),
		}
	end
	return result
end

local function provider_choices()
	local providers = require("physical-keyboard.detect.providers")
	local result = {
		{ value = "auto", short = "auto", label = "auto — use the best available adapter", unset = true },
	}
	for _, provider in ipairs(providers.list() or {}) do
		result[#result + 1] = { value = provider.name, short = provider.name, label = provider.name }
	end
	return result
end

local function echo_mode_choices()
	local echo = require("physical-keyboard.echo")
	local result = {}
	for _, mode in ipairs(echo.modes()) do
		result[#result + 1] = {
			value = mode,
			short = mode,
			label = mode,
			description = "Format captured keys as " .. mode .. " output.",
		}
	end
	return result
end

local function mode_key(value)
	return "mode:" .. tostring(value)
end

local function choice_key(value)
	if value == nil then
		return "nil"
	end
	return type(value) .. ":" .. tostring(value)
end

local function find_choice(choices, value)
	local key = choice_key(value)
	for _, choice in ipairs(choices or {}) do
		if choice_key(choice.value) == key then
			return choice
		end
	end
	return nil
end

M.specs = {
	{
		path = "enable",
		group = "General",
		kind = "bool",
		label = "enable",
		description = "Master switch for translation and mirrored mappings.",
		example = "Off is equivalent to :PhyKeyboardDisable.",
		notes = "Disabling restores the original 'langmap' and removes mappings created by the plugin.",
	},
	{
		path = "notify",
		group = "General",
		kind = "enum",
		label = "notify",
		description = "How much physical-keyboard reports through :messages.",
		example = "errors shows warnings and errors only.",
		notes = "Use off for a completely silent session.",
		choices = function()
			return {
				{ value = "all", short = "all", label = "all — every message" },
				{ value = "errors", short = "errors", label = "errors — warnings and errors only" },
				{ value = "off", short = "off", label = "off — silent" },
			}
		end,
	},
	{
		path = "active_layouts",
		group = "Layouts",
		kind = "multi",
		label = "active_layouts",
		description = "Layouts used to translate Normal, Visual and Operator-pending keys.",
		example = "ru, de, fr.",
		notes = "Unchecking everything removes the override and falls back to the configured list. Detection may add a layout at runtime.",
		empty = "unset",
		choices = layout_choices,
	},
	{
		path = "fallback",
		group = "Layouts",
		kind = "enum",
		label = "fallback",
		description = "What to translate when detection is unavailable or returns no layout.",
		example = "unique keeps only non-conflicting pairs; a layout id applies that layout.",
		notes = "The hard fallback is useful when only one national layout is used.",
		choices = function()
			local result = { { value = "unique", short = "unique", label = "unique — non-conflicting pairs only" } }
			for _, choice in ipairs(layout_choices()) do
				result[#result + 1] = choice
			end
			result[#result + 1] = { value = false, short = "off", label = "off — do not apply langmap" }
			return result
		end,
	},
	{
		path = "langmap.enabled",
		group = "Langmap",
		kind = "bool",
		label = "langmap.enabled",
		description = "Apply 'langmap' so national characters behave like the physical US keys.",
		example = "Russian сшц behaves like ciw.",
		notes = "This never changes Insert-mode text.",
	},
	{
		path = "detect.enabled",
		group = "Detection",
		kind = "bool",
		label = "detect.enabled",
		description = "Ask the OS or compositor for the active layout on focus and InsertLeave.",
		example = "Turn off when you always use one national layout.",
		notes = "Detection is throttled and asynchronous by default; there is no polling loop.",
	},
	{
		path = "detect.provider",
		group = "Detection",
		kind = "enum",
		label = "detect.provider",
		description = "Force one detection adapter instead of the automatic order.",
		example = "niri, sway, hyprland, xkb-switch, im-select.",
		notes = "auto removes the override and restores the automatic provider order.",
		choices = provider_choices,
	},
	{
		path = "detect.providers",
		group = "Detection",
		kind = "multi",
		label = "detect.providers",
		description = "Restrict detection to a subset of adapters.",
		example = "niri and gnome.",
		notes = "Unchecking everything removes the restriction and lets every adapter run.",
		empty = "unset",
		implicit = "(all)",
		choices = function()
			local result = provider_choices()
			table.remove(result, 1)
			return result
		end,
	},
	{
		path = "detect.remote",
		group = "Detection",
		kind = "enum",
		label = "detect.remote",
		description = "Whether detection runs in SSH, WSL or other remote sessions.",
		example = "auto disables detection for remote sessions.",
		notes = "The local layout is irrelevant over SSH; use active_layouts or a fallback instead.",
		choices = function()
			return {
				{ value = "auto", short = "auto", label = "auto — disable detection for remote sessions" },
				{ value = true, short = "on", label = "on — always run detection" },
				{ value = false, short = "off", label = "off — never run detection" },
			}
		end,
	},
	{
		path = "detect.async",
		group = "Detection",
		kind = "bool",
		label = "detect.async",
		description = "Run detection without blocking the editor.",
		example = "Keeps InsertLeave cheap on slow compositors.",
		notes = "Disable only if an adapter is known to require synchronous execution.",
	},
	{
		path = "mappings.enabled",
		group = "Mappings",
		kind = "bool",
		label = "mappings.enabled",
		description = "Mirror plugin and built-in Normal/Visual/Operator-pending mappings to national keys.",
		example = "A plugin mapping on <Leader>ff also answers to the national equivalent.",
		notes = "Built-in motions such as ciw are handled by 'langmap' and keep working on their own.",
	},
	{
		path = "mappings.hack_keymap",
		group = "Mappings",
		kind = "bool",
		label = "mappings.hack_keymap",
		description = "Intercept keymaps created after setup so they are mirrored too.",
		example = "Mappings defined by a plugin on LazyLoad are mirrored automatically.",
		notes = "Temporarily patches vim.api.nvim_set_keymap; the original functions are restored when disabled.",
	},
	{
		path = "mappings.automapping",
		group = "Mappings",
		kind = "bool",
		label = "mappings.automapping",
		description = "Scan buffers when they gain mappings.",
		example = "Runs on BufWinEnter, FileType and LspAttach.",
		notes = "Disable to mirror only once at startup.",
	},
	{
		path = "mappings.modes",
		group = "Mappings",
		kind = "multi",
		label = "mappings.modes",
		description = "Which modes receive mirrored mappings.",
		example = "n, x, s, o is the default.",
		notes = "Insert and Command-line mirroring is opt-in and can duplicate plugin behavior.",
		min = 1,
		choices = function()
			return vim.deepcopy(MODES)
		end,
		key = mode_key,
	},
	{
		path = "cmdline.enabled",
		group = "Cmdline",
		kind = "bool",
		label = "cmdline.enabled",
		description = "Alias native command names to their English Ex commands.",
		example = ":цй becomes :wq, so Ж ц й Enter still saves and quits.",
		notes = "The command line is not covered by 'langmap'.",
	},
	{
		path = "echo.enabled",
		group = "Echo",
		kind = "bool",
		label = "echo.enabled",
		description = "Diagnostic raw-key capture for checking what Neovim receives.",
		example = "Enable, press keys, then inspect Echo → Last keys.",
		notes = "Off by default; useful for layout and terminal debugging.",
	},
	{
		path = "echo.mode",
		group = "Echo",
		kind = "enum",
		label = "echo.mode",
		description = "How captured keys are formatted.",
		example = "debug shows characters, bytes, codepoint and length.",
		notes = "The panel previews each mode in Echo → Modes & preview.",
		choices = echo_mode_choices,
	},
}

local by_path = {}
for _, spec in ipairs(M.specs) do
	by_path[spec.path] = spec
end

---@param path string
---@return table|nil
function M.spec(path)
	return by_path[path]
end

---@return string[]
function M.paths()
	local result = {}
	for _, spec in ipairs(M.specs) do
		result[#result + 1] = spec.path
	end
	return result
end

---@param spec table
---@param cfg table
---@return table
function M.choices(spec, cfg)
	if type(spec.choices) == "function" then
		return spec.choices(cfg) or {}
	end
	return spec.choices or {}
end

---@param cfg table
---@param path string
---@return any
function M.get(cfg, path)
	local spec = by_path[path]
	if not spec then
		return nested(cfg, path)
	end
	if path == "detect.provider" then
		local value = nested(cfg, path)
		return value == nil and "auto" or value
	end
	if path == "detect.providers" then
		return nested(cfg, path) or {}
	end
	if path == "active_layouts" then
		return nested(cfg, path) or {}
	end
	if path == "fallback" then
		local value = nested(cfg, path)
		return value == nil and "unique" or value
	end
	if spec.kind == "bool" then
		local value = nested(cfg, path)
		return value == true
	end
	return nested(cfg, path)
end

---@param spec table
---@param value any
---@return any normalized
---@return string|nil error
---@return boolean unset
function M.normalize(spec, value)
	if spec.kind == "bool" then
		if type(value) ~= "boolean" then
			return nil, "expected true or false", false
		end
		return value, nil, false
	end

	local choices = spec.choices and (type(spec.choices) == "function" and spec.choices() or spec.choices) or {}

	if spec.kind == "enum" then
		local choice = find_choice(choices, value)
		if not choice then
			return nil, "invalid value for " .. spec.path, false
		end
		if choice.unset then
			return nil, nil, true
		end
		return choice.value, nil, false
	end

	if spec.kind == "multi" then
		if type(value) ~= "table" then
			value = { value }
		end
		local allowed = {}
		for _, choice in ipairs(choices) do
			allowed[choice_key(choice.value)] = choice
		end
		local requested = {}
		local result = {}
		for _, item in ipairs(value) do
			local key = choice_key(item)
			if not allowed[key] then
				return nil, "invalid value for " .. spec.path, false
			end
			if not requested[key] then
				requested[key] = true
				result[#result + 1] = item
			end
		end
		if #result == 0 and spec.empty ~= "unset" then
			return nil, "select at least one value", false
		end
		if #result == 0 then
			return {}, nil, true
		end
		return result, nil, false
	end

	return nil, "unsupported option kind", false
end

---@param spec table
---@param cfg table
---@return string
---@return string
function M.format(spec, cfg)
	local value = M.get(cfg, spec.path)
	if spec.kind == "bool" then
		return value and "on" or "off", value and "PhyKeyboardUIOK" or "PhyKeyboardUIMuted"
	end
	if spec.kind == "enum" then
		local choice = find_choice(M.choices(spec, cfg), value)
		return choice and (choice.short or choice.label) or tostring(value), "PhyKeyboardUIValue"
	end
	if spec.kind == "multi" then
		local choices = M.choices(spec, cfg)
		local labels = {}
		for _, item in ipairs(value or {}) do
			local choice = find_choice(choices, item)
			labels[#labels + 1] = choice and (choice.short or choice.label or tostring(item)) or tostring(item)
		end
		if #labels == 0 then
			return spec.implicit or "(none)", "PhyKeyboardUIMuted"
		end
		return table.concat(labels, ", "), "PhyKeyboardUIValue"
	end
	return tostring(value), "PhyKeyboardUIValue"
end

---@param spec table
---@param value any
---@return string
function M.choice_label(spec, value)
	local choice = find_choice(M.choices(spec), value)
	return choice and choice.label or tostring(value)
end

return M
