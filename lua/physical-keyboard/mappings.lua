local layouts = require("physical-keyboard.layouts")

--- Translates mapping left-hand sides between the English layout and one or
--- more national layouts.
---
--- 'langmap' already translates keys typed by the user, but mappings registered
--- by plugins are matched on the raw left-hand side.  This module mirrors every
--- mapping to its national-layout variant so shortcuts keep working regardless
--- of the active layout.
local M = {}

local MARK = "pkb:"

local state = {
	enabled = true,
	modes = { "n", "x", "s", "o" },
	forward = {},
	forwards = {},
	hacked = false,
	orig = {},
	created = {},
	created_set = {},
	exclude = {},
	extra = {},
	on_change = nil,
}

local function is_special_sequence(lhs)
	local lower = lhs:lower()
	return lower:find("<plug>", 1, true)
		or lower:find("<sid>", 1, true)
		or lower:find("<snr>", 1, true)
end

local function translate_plain(run, forward)
	local out = {}
	local changed = false
	for _, char in ipairs(vim.fn.split(run, "\\zs")) do
		local mapped = forward[char]
		if mapped then
			out[#out + 1] = mapped
			changed = true
		else
			out[#out + 1] = char
		end
	end
	return table.concat(out), changed
end

local function translate_special(spec, forward)
	if spec:sub(1, 1) ~= "<" or spec:sub(-1) ~= ">" then
		return spec, false
	end

	local inner = spec:sub(2, -2)
	if inner == "" then
		return spec, false
	end

	local lower = inner:lower()
	if lower:find("plug", 1, true) or lower:find("sid", 1, true) or lower:find("snr", 1, true) then
		return spec, false
	end

	local parts = vim.split(inner, "-", { plain = true })
	local key = parts[#parts]
	if not key or vim.fn.strchars(key) ~= 1 then
		return spec, false
	end

	local mapped = forward[key]
	if not mapped then
		return spec, false
	end

	parts[#parts] = mapped
	return "<" .. table.concat(parts, "-") .. ">", true
end

local function translate_with(lhs, forward)
	if type(lhs) ~= "string" or lhs == "" then
		return lhs, false
	end
	if is_special_sequence(lhs) then
		return lhs, false
	end

	local out = {}
	local changed = false
	local index = 1

	while index <= #lhs do
		local open = lhs:find("<", index, true)
		if not open then
			local piece, piece_changed = translate_plain(lhs:sub(index), forward)
			out[#out + 1] = piece
			changed = changed or piece_changed
			break
		end

		if open > index then
			local piece, piece_changed = translate_plain(lhs:sub(index, open - 1), forward)
			out[#out + 1] = piece
			changed = changed or piece_changed
		end

		local close = lhs:find(">", open + 1, true)
		if close then
			local special, special_changed = translate_special(lhs:sub(open, close), forward)
			out[#out + 1] = special
			changed = changed or special_changed
			index = close + 1
		else
			local piece, piece_changed = translate_plain(lhs:sub(open, open), forward)
			out[#out + 1] = piece
			changed = changed or piece_changed
			index = open + 1
		end
	end

	local result = table.concat(out)
	return result, changed and result ~= lhs
end

--- Returns true when a mapping left-hand side should not be mirrored.
---@param lhs string
---@return boolean
function M.is_excluded(lhs)
	if type(lhs) ~= "string" then
		return false
	end
	for _, pattern in ipairs(state.exclude) do
		if lhs == pattern then
			return true
		end
		local ok, found = pcall(string.find, lhs, pattern)
		if ok and found then
			return true
		end
	end
	return false
end

--- Returns one translated variant per active layout plus explicit extras.
---@param lhs string
---@return { lhs: string, layout: string }[]
function M.variants(lhs)
	local result = {}
	local seen = {}
	if M.is_excluded(lhs) then
		return result
	end

	for _, item in ipairs(state.forwards) do
		local translated, changed = translate_with(lhs, item.forward)
		if changed and not seen[translated] then
			seen[translated] = true
			result[#result + 1] = { lhs = translated, layout = item.id }
		end
	end

	local extra = state.extra[lhs]
	if type(extra) == "string" and extra ~= "" and extra ~= lhs and not seen[extra] then
		result[#result + 1] = { lhs = extra, layout = "extra" }
	end

	return result
end

---@param lhs string
---@return string translated
---@return boolean changed
function M.translate(lhs)
	local variants = M.variants(lhs)
	if #variants == 0 then
		return lhs, false
	end
	return variants[1].lhs, true
end

---@param forward table<string, string>
---@param lhs string
---@return string translated
---@return boolean changed
function M.translate_with(forward, lhs)
	return translate_with(lhs, forward or {})
end

---@param active_ids string[]
function M.rebuild(active_ids)
	state.forwards = {}
	for _, id in ipairs(active_ids or {}) do
		local layout = layouts.get(id)
		if layout then
			state.forwards[#state.forwards + 1] = { id = id, forward = layout.forward }
		end
	end
	state.forward = state.forwards[1] and state.forwards[1].forward or {}
end

---@param opts table|nil
function M.setup(opts)
	opts = opts or {}
	if opts.enabled ~= nil then
		state.enabled = opts.enabled
	end
	if opts.modes then
		state.modes = opts.modes
	end
	state.exclude = opts.exclude or {}
	state.extra = opts.extra or {}
	M.rebuild(opts.active_ids or {})
end

function M.is_ours(opts)
	return type(opts) == "table"
		and type(opts.desc) == "string"
		and opts.desc:sub(1, #MARK) == MARK
end

local function capture_originals()
	if state.orig.set then
		return
	end
	state.orig.set = vim.api.nvim_set_keymap
	state.orig.buf_set = vim.api.nvim_buf_set_keymap
	state.orig.del = vim.api.nvim_del_keymap
	state.orig.buf_del = vim.api.nvim_buf_del_keymap
end

local function record(global, bufnr, mode, lhs, source_lhs, source_desc, layout)
	local key
	if global then
		key = "g|" .. mode .. "|" .. lhs
	else
		key = "b|" .. tostring(bufnr) .. "|" .. mode .. "|" .. lhs
	end
	if state.created_set[key] then
		return
	end
	state.created_set[key] = true
	state.created[#state.created + 1] = {
		global = global,
		bufnr = bufnr,
		mode = mode,
		lhs = lhs,
		source_lhs = source_lhs or lhs,
		source_desc = source_desc or source_lhs or lhs,
		layout = layout,
	}
end

local function changed()
	if state.on_change then
		state.on_change()
	end
end

local function duplicate_global(mode, lhs, rhs, opts)
	if not state.enabled or M.is_ours(opts) then
		return
	end

	local setter = state.orig.set or vim.api.nvim_set_keymap
	local source_desc = opts and opts.desc or lhs
	local created = false
	for _, variant in ipairs(M.variants(lhs)) do
		if variant.lhs ~= lhs then
			local merged = vim.deepcopy(opts or {})
			merged.desc = MARK .. (merged.desc or lhs)
			pcall(setter, mode, variant.lhs, rhs, merged)
			record(true, nil, mode, variant.lhs, lhs, source_desc, variant.layout)
			created = true
		end
	end
	if created then
		changed()
	end
end

local function duplicate_buffer(buffer, mode, lhs, rhs, opts)
	if not state.enabled or M.is_ours(opts) then
		return
	end

	local bufnr = (buffer == 0 or buffer == nil) and vim.api.nvim_get_current_buf() or buffer
	local setter = state.orig.buf_set or vim.api.nvim_buf_set_keymap
	local source_desc = opts and opts.desc or lhs
	local created = false
	for _, variant in ipairs(M.variants(lhs)) do
		if variant.lhs ~= lhs then
			local merged = vim.deepcopy(opts or {})
			merged.desc = MARK .. (merged.desc or lhs)
			pcall(setter, buffer, mode, variant.lhs, rhs, merged)
			record(false, bufnr, mode, variant.lhs, lhs, source_desc, variant.layout)
			created = true
		end
	end
	if created then
		changed()
	end
end

function M.hack()
	if state.hacked then
		return
	end
	capture_originals()
	state.hacked = true

	vim.api.nvim_set_keymap = function(mode, lhs, rhs, opts)
		state.orig.set(mode, lhs, rhs, opts)
		duplicate_global(mode, lhs, rhs, opts)
	end

	vim.api.nvim_buf_set_keymap = function(buffer, mode, lhs, rhs, opts)
		state.orig.buf_set(buffer, mode, lhs, rhs, opts)
		duplicate_buffer(buffer, mode, lhs, rhs, opts)
	end

	vim.api.nvim_del_keymap = function(mode, lhs)
		state.orig.del(mode, lhs)
		for _, variant in ipairs(M.variants(lhs)) do
			pcall(state.orig.del, mode, variant.lhs)
		end
	end

	vim.api.nvim_buf_del_keymap = function(buffer, mode, lhs)
		state.orig.buf_del(buffer, mode, lhs)
		for _, variant in ipairs(M.variants(lhs)) do
			pcall(state.orig.buf_del, buffer, mode, variant.lhs)
		end
	end
end

function M.unhack()
	if not state.hacked then
		return
	end
	vim.api.nvim_set_keymap = state.orig.set
	vim.api.nvim_buf_set_keymap = state.orig.buf_set
	vim.api.nvim_del_keymap = state.orig.del
	vim.api.nvim_buf_del_keymap = state.orig.buf_del
	state.hacked = false
end

--- Removes every mapping mirrored by this module.
function M.cleanup()
	local had = #state.created > 0
	for _, item in ipairs(state.created) do
		if item.global then
			pcall(vim.api.nvim_del_keymap, item.mode, item.lhs)
		else
			pcall(vim.api.nvim_buf_del_keymap, item.bufnr, item.mode, item.lhs)
		end
	end
	state.created = {}
	state.created_set = {}
	if had then
		changed()
	end
end

local function mapping_opts(mapping)
	local opts = {
		noremap = mapping.noremap ~= 0,
		silent = mapping.silent == 1,
		expr = mapping.expr == 1,
		nowait = mapping.nowait == 1,
		desc = MARK .. (mapping.desc or mapping.lhs),
	}
	if mapping.callback then
		opts.callback = mapping.callback
	end
	if mapping.script ~= nil then
		opts.script = mapping.script == 1
	end
	if mapping.replace_keycodes ~= nil then
		opts.replace_keycodes = mapping.replace_keycodes == 1
	end
	if mapping.unique ~= nil then
		opts.unique = mapping.unique == 1
	end
	return opts
end

local function scan_global(modes)
	local created = 0
	for _, mode in ipairs(modes) do
		local existing = {}
		local mapping_list = vim.api.nvim_get_keymap(mode)
		for _, mapping in ipairs(mapping_list) do
			existing[mapping.lhs] = true
		end

		for _, mapping in ipairs(mapping_list) do
			if not M.is_ours(mapping) then
				for _, variant in ipairs(M.variants(mapping.lhs)) do
					if variant.lhs ~= mapping.lhs and not existing[variant.lhs] then
						local setter = state.orig.set or vim.api.nvim_set_keymap
						local ok = pcall(
							setter,
							mode,
							variant.lhs,
							mapping.rhs or "",
							mapping_opts(mapping)
						)
						if ok then
							existing[variant.lhs] = true
							record(true, nil, mode, variant.lhs, mapping.lhs, mapping.desc, variant.layout)
							created = created + 1
						end
					end
				end
			end
		end
	end
	return created
end

local function scan_buffer(bufnr, modes)
	if not vim.api.nvim_buf_is_valid(bufnr) then
		return 0
	end

	local created = 0
	for _, mode in ipairs(modes) do
		local existing = {}
		local mapping_list = vim.api.nvim_buf_get_keymap(bufnr, mode)
		for _, mapping in ipairs(mapping_list) do
			existing[mapping.lhs] = true
		end

		for _, mapping in ipairs(mapping_list) do
			if not M.is_ours(mapping) then
				for _, variant in ipairs(M.variants(mapping.lhs)) do
					if variant.lhs ~= mapping.lhs and not existing[variant.lhs] then
						local setter = state.orig.buf_set or vim.api.nvim_buf_set_keymap
						local ok = pcall(
							setter,
							bufnr,
							mode,
							variant.lhs,
							mapping.rhs or "",
							mapping_opts(mapping)
						)
						if ok then
							existing[variant.lhs] = true
							record(false, bufnr, mode, variant.lhs, mapping.lhs, mapping.desc, variant.layout)
							created = created + 1
						end
					end
				end
			end
		end
	end
	return created
end

--- Mirrors already registered mappings to the national layouts.
---@param opts { global: boolean|nil, buffer: boolean|nil, bufnr: number|nil, modes: string[]|nil }|nil
---@return number
function M.automapping(opts)
	if not state.enabled then
		return 0
	end

	opts = opts or {}
	local modes = opts.modes or state.modes
	local created = 0

	if opts.global then
		created = created + scan_global(modes)
	end

	if opts.buffer then
		local bufnr = opts.bufnr or vim.api.nvim_get_current_buf()
		created = created + scan_buffer(bufnr, modes)
	end

	if created > 0 then
		changed()
	end
	return created
end

---@return number
function M.count_created()
	return #state.created
end

--- Returns a copy of the mappings mirrored by this module.
---@return { global: boolean, bufnr: number|nil, mode: string, lhs: string, source_lhs: string }[]
function M.list()
	local result = {}
	for _, item in ipairs(state.created) do
		result[#result + 1] = vim.deepcopy(item)
	end
	return result
end

--- Registers a callback invoked after mirrored mappings change.
---@param fn function|nil
function M.on_change(fn)
	state.on_change = fn
end

---@return boolean
function M.is_hacked()
	return state.hacked
end

---@return table<string, string>
function M.forward()
	return state.forward
end

function M.map(mode, lhs, rhs, opts)
	opts = vim.deepcopy(opts or {})
	if opts.buffer then
		local buffer = opts.buffer
		opts.buffer = nil
		vim.api.nvim_buf_set_keymap(buffer == true and 0 or buffer, mode, lhs, rhs, opts)
	else
		vim.api.nvim_set_keymap(mode, lhs, rhs, opts)
	end
end

function M.del(mode, lhs, opts)
	opts = opts or {}
	if opts.buffer then
		local buffer = opts.buffer == true and 0 or opts.buffer
		pcall(vim.api.nvim_buf_del_keymap, buffer, mode, lhs)
	else
		pcall(vim.api.nvim_del_keymap, mode, lhs)
	end
end

return M
