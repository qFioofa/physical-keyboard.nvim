local mappings = require("physical-keyboard.mappings")

--- Presents mappings mirrored by physical-keyboard in which-key.
---
--- The module only adds display descriptions; it never creates or removes
--- keymaps. which-key 3.x is supported directly, 2.x through its legacy
--- `register()` API.
local M = {}

local MARK = "pkb:"

local state = {
	enabled = true,
	display = nil,
	relative_group = false,
	alongside = false,
	separator = "\\",
	suspended = false,
	hooked = false,
	scheduled = false,
	retries = 0,
	v3_internal = false,
	stats = {
		available = false,
		version = nil,
		pending = false,
		hidden = 0,
		groups = 0,
		visible = 0,
		alongside = 0,
	},
}

local function which_key()
	local loaded = package.loaded["which-key"]
	if loaded then
		return loaded
	end
	local ok, module = pcall(require, "which-key")
	if ok and type(module) == "table" then
		return module
	end
	return nil
end

local function version(wk)
	local ok, cfg = pcall(require, "which-key.config")
	if ok and type(cfg) == "table" and type(cfg.version) == "string" then
		return tonumber(cfg.version:match("^(%d+)")) or 0
	end
	if wk and type(wk._queue) == "table" then
		return 3
	end
	return 2
end

local function clean_desc(value, fallback)
	value = tostring(value or "")
	value = value:gsub("^" .. vim.pesc(mappings.MIRROR_MARK or (MARK .. "mirror:")), "")
	value = value:gsub("^" .. vim.pesc(MARK), "")
	if value == "" then
		return fallback or ""
	end
	return value
end

local function scope_key(item)
	return ("%s|%s|%s|%s"):format(
		item.global and "g" or "b",
		tostring(item.bufnr or 0),
		item.mode,
		item.source_lhs
	)
end

local function spec_key(spec)
	return ("%s|%s|%s|%s"):format(
		spec.buffer and ("b" .. tostring(spec.buffer)) or "g",
		tostring(spec.mode),
		spec.group and "group" or "map",
		spec.lhs
	)
end

local function collect_sources()
	local list = mappings.list()
	local order = {}
	local sources = {}

	for _, item in ipairs(list) do
		local key = scope_key(item)
		local source = sources[key]
		if not source then
			source = {
				global = item.global,
				bufnr = item.bufnr,
				mode = item.mode,
				source_lhs = item.source_lhs,
				source_desc = clean_desc(item.source_desc, item.source_lhs),
				variants = {},
			}
			sources[key] = source
			order[#order + 1] = key
		end
		source.variants[#source.variants + 1] = item
	end

	local result = {}
	for _, key in ipairs(order) do
		result[#result + 1] = sources[key]
	end
	return result
end

local function collect_groups()
	local groups = {}
	local ok, cfg = pcall(require, "which-key.config")
	if not ok or type(cfg) ~= "table" or type(cfg.mappings) ~= "table" then
		return groups
	end

	for _, mapping in ipairs(cfg.mappings) do
		if mapping.group and type(mapping.lhs) == "string" and type(mapping.desc) == "string" and mapping.desc ~= "" then
			groups[#groups + 1] = {
				lhs = mapping.lhs,
				label = mapping.desc,
				icon = mapping.icon,
				mode = mapping.mode or "n",
				buffer = mapping.buffer,
			}
		end
	end
	return groups
end

local function ancestor_groups(groups, item)
	local result = {}
	local lhs = item.source_lhs:lower()
	for _, group in ipairs(groups) do
		local compatible_buffer = group.buffer == nil or group.buffer == 0 or group.buffer == item.bufnr
		if group.mode == item.mode and compatible_buffer then
			local prefix = group.lhs:lower()
			if #prefix < #lhs and lhs:sub(1, #prefix) == prefix then
				result[#result + 1] = group
			end
		end
	end
	table.sort(result, function(a, b)
		return #a.lhs < #b.lhs
	end)
	return result
end

local function translated_group(item, group)
	for _, variant in ipairs(mappings.variants(group.lhs)) do
		if variant.layout == item.layout then
			return variant.lhs
		end
	end
	return nil
end

local function add_spec(specs, seen, spec)
	local key = spec_key(spec)
	if seen[key] then
		return false
	end
	seen[key] = true
	specs[#specs + 1] = spec
	return true
end

local function build_specs()
	local specs = {}
	local seen = {}
	local groups = collect_groups()
	local stats = { hidden = 0, groups = 0, visible = 0, alongside = 0 }

	for _, source in ipairs(collect_sources()) do
		local variants = source.variants
		local base = { mode = source.mode, buffer = not source.global and source.bufnr or nil }

		if state.alongside then
			local labels = {}
			for _, item in ipairs(variants) do
				labels[#labels + 1] = item.lhs
			end
			if #labels > 0 then
				local separator = " " .. state.separator .. " "
				local desc = source.source_desc .. separator .. table.concat(labels, separator)
				local spec = vim.tbl_extend("force", base, { lhs = source.source_lhs, desc = desc })
				if add_spec(specs, seen, spec) then
					stats.alongside = stats.alongside + 1
				end
			end
			for _, item in ipairs(variants) do
				if add_spec(specs, seen, vim.tbl_extend("force", base, { lhs = item.lhs, hidden = true })) then
					stats.hidden = stats.hidden + 1
				end
			end
		else
			for _, item in ipairs(variants) do
				local item_base = { mode = item.mode, buffer = item.bufnr }
				if state.relative_group then
					local mirrored = {}
					for _, group in ipairs(ancestor_groups(groups, item)) do
						local lhs = translated_group(item, group)
						if lhs then
							mirrored[#mirrored + 1] = { lhs = lhs, label = group.label, icon = group.icon }
						end
					end
					if #mirrored > 0 then
						for _, group in ipairs(mirrored) do
							local spec = {
								lhs = group.lhs,
								group = group.label,
								icon = group.icon,
								mode = item.mode,
								buffer = item.bufnr,
							}
							if add_spec(specs, seen, spec) then
								stats.groups = stats.groups + 1
							end
						end
						local spec = vim.tbl_extend("force", item_base, {
							lhs = item.lhs,
							desc = clean_desc(item.source_desc, item.source_lhs),
						})
						if add_spec(specs, seen, spec) then
							stats.visible = stats.visible + 1
						end
					else
						if add_spec(specs, seen, vim.tbl_extend("force", item_base, { lhs = item.lhs, hidden = true })) then
							stats.hidden = stats.hidden + 1
						end
					end
				else
					if add_spec(specs, seen, vim.tbl_extend("force", item_base, { lhs = item.lhs, hidden = true })) then
						stats.hidden = stats.hidden + 1
					end
				end
			end
		end
	end

	return specs, stats
end

local function v3_forget()
	local ok, cfg = pcall(require, "which-key.config")
	if not ok or type(cfg) ~= "table" or type(cfg.mappings) ~= "table" then
		return
	end
	for index = #cfg.mappings, 1, -1 do
		if cfg.mappings[index]._pkb then
			table.remove(cfg.mappings, index)
		end
	end
	for index, mapping in ipairs(cfg.mappings) do
		mapping.idx = index
	end
	if cfg.loaded then
		pcall(function()
			require("which-key.buf").clear()
		end)
	end
	state.v3_internal = false
end

local function v3_add(wk, specs)
	local ok_mappings, WKMappings = pcall(require, "which-key.mappings")
	local ok_config, WKConfig = pcall(require, "which-key.config")
	if
		ok_mappings
		and ok_config
		and type(WKMappings) == "table"
		and type(WKMappings.parse) == "function"
		and type(WKConfig) == "table"
		and type(WKConfig.mappings) == "table"
	then
		local parsed = WKMappings.parse(vim.deepcopy(specs), { create = false })
		for _, mapping in ipairs(parsed) do
			mapping._pkb = true
			WKConfig.mappings[#WKConfig.mappings + 1] = mapping
			mapping.idx = #WKConfig.mappings
		end
		if WKConfig.loaded then
			pcall(function()
				require("which-key.buf").clear()
			end)
		end
		state.v3_internal = true
		return
	end

	wk.add(specs)
	state.v3_internal = false
end

local function v2_add(wk, specs)
	for _, spec in ipairs(specs) do
		local entry
		if spec.group then
			entry = { name = spec.group:sub(1, 1) == "+" and spec.group or ("+" .. spec.group) }
		else
			entry = { desc = spec.desc, hidden = spec.hidden }
		end
		local spec_table = { [spec.lhs] = entry }
		local opts = { mode = spec.mode }
		if spec.buffer then
			opts.buffer = spec.buffer
		end
		pcall(wk.register, spec_table, opts)
	end
end

local function apply(specs)
	local wk = which_key()
	state.stats.available = wk ~= nil
	state.stats.version = wk and version(wk) or nil
	if not wk or #specs == 0 then
		return
	end

	if state.stats.version and state.stats.version >= 3 then
		local ok, cfg = pcall(require, "which-key.config")
		if ok and type(cfg) == "table" and cfg.loaded == false then
			state.stats.pending = true
			return
		end
		if type(wk.add) == "function" then
			v3_add(wk, specs)
			return
		end
	end

	if type(wk.register) == "function" then
		v2_add(wk, specs)
	end
end

local function retry()
	if state.retries >= 5 or not state.stats.pending then
		return
	end
	state.retries = state.retries + 1
	vim.defer_fn(function()
		if state.enabled and not state.suspended then
			M.refresh()
		end
	end, 100)
end

function M.refresh()
	if not state.enabled or state.suspended then
		return
	end

	v3_forget()
	local wk = which_key()
	state.stats.available = wk ~= nil
	state.stats.version = wk and version(wk) or nil
	local specs, stats = build_specs()
	state.stats.pending = false
	state.stats.hidden = stats.hidden
	state.stats.groups = stats.groups
	state.stats.visible = stats.visible
	state.stats.alongside = stats.alongside
	apply(specs)
	if state.stats.pending then
		retry()
	else
		state.retries = 0
	end
end

function M.schedule_refresh()
	if state.scheduled or not state.enabled or state.suspended then
		return
	end
	state.scheduled = true
	vim.schedule(function()
		state.scheduled = false
		M.refresh()
	end)
end

function M.cleanup()
	v3_forget()
	state.stats.hidden = 0
	state.stats.groups = 0
	state.stats.visible = 0
	state.stats.alongside = 0
	state.stats.pending = false
	state.retries = 0
end

function M.enable()
	state.suspended = false
	M.refresh()
end

function M.disable()
	state.suspended = true
	M.cleanup()
end

local function install_hooks()
	if state.hooked then
		return
	end
	state.hooked = true

	mappings.on_change(M.schedule_refresh)

	local group = vim.api.nvim_create_augroup("PhysicalKeyboardWhichKey", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = group,
		pattern = { "VeryLazy", "LazyLoad" },
		callback = function()
			vim.schedule(function()
				M.refresh()
			end)
		end,
	})
	vim.api.nvim_create_autocmd("VimEnter", {
		group = group,
		once = true,
		callback = function()
			vim.schedule(function()
				M.refresh()
			end)
		end,
	})
end

---@param opts table|nil
function M.setup(opts)
	opts = opts or {}
	state.enabled = opts.enabled ~= false
	state.display = opts.display
	state.relative_group = opts.relative_group == true
	state.alongside = opts.alongside == true
	state.separator = type(opts.separator) == "string" and opts.separator ~= "" and opts.separator or "\\"
	state.suspended = false
	install_hooks()
	if state.enabled then
		M.refresh()
	else
		M.cleanup()
	end
end

---@return table
function M.status()
	local result = vim.deepcopy(state.stats)
	result.enabled = state.enabled
	result.display = state.display
	result.relative_group = state.relative_group
	result.alongside = state.alongside
	result.separator = state.separator
	return result
end

return M
