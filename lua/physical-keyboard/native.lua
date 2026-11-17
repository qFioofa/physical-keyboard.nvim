local mappings = require("physical-keyboard.mappings")

--- Keeps mirrored mappings out of native and Lua mapping listings.
---
--- Mirrors are real keymaps, so `:map`/`:nmap` read them directly from the C
--- keymap tables.  For those commands the module temporarily removes the
--- mirrors right before the listing executes and restores them afterwards.
---
--- Lua consumers (Snacks, Telescope, which-key, ...) use
--- `nvim_get_keymap()`/`nvim_buf_get_keymap()`; the module wraps those getters
--- and filters mirrored entries from the returned copy.  The keymap tables are
--- never changed by the getter filter.
local M = {}

local MAP_COMMANDS = {
	map = true,
	noremap = true,
	nmap = true,
	nnoremap = true,
	vmap = true,
	vnoremap = true,
	xmap = true,
	xnoremap = true,
	smap = true,
	snoremap = true,
	omap = true,
	onoremap = true,
	imap = true,
	inoremap = true,
	lmap = true,
	lnoremap = true,
	cmap = true,
	cnoremap = true,
	tmap = true,
	tnoremap = true,
}

local MODIFIERS = {
	["<buffer>"] = true,
	["<nowait>"] = true,
	["<silent>"] = true,
	["<special>"] = true,
	["<script>"] = true,
	["<expr>"] = true,
	["<unique>"] = true,
}

local state = {
	enabled = false,
	commandline = true,
	api = true,
	hooked = false,
	api_patched = false,
	api_enabled = false,
	pending_resume = false,
	raw = {
		get = nil,
		buf_get = nil,
	},
	wrappers = {
		get = nil,
		buf_get = nil,
	},
	timer = nil,
}

local function filter_mirrors(list)
	local result = {}
	for _, mapping in ipairs(list or {}) do
		if not mappings.is_mirror(mapping) then
			result[#result + 1] = mapping
		end
	end
	return result
end

local function install_getters()
	if not state.api or state.api_patched then
		state.api_enabled = state.api_patched and state.api or false
		return
	end

	state.raw.get = vim.api.nvim_get_keymap
	state.raw.buf_get = vim.api.nvim_buf_get_keymap

	state.wrappers.get = function(mode)
		local list = state.raw.get(mode)
		if not state.api_enabled then
			return list
		end
		return filter_mirrors(list)
	end

	state.wrappers.buf_get = function(bufnr, mode)
		local list = state.raw.buf_get(bufnr, mode)
		if not state.api_enabled then
			return list
		end
		return filter_mirrors(list)
	end

	vim.api.nvim_get_keymap = state.wrappers.get
	vim.api.nvim_buf_get_keymap = state.wrappers.buf_get
	state.api_patched = true
	state.api_enabled = true
end

local function restore_getters()
	state.api_enabled = false
	if not state.api_patched then
		return
	end
	if vim.api.nvim_get_keymap == state.wrappers.get then
		vim.api.nvim_get_keymap = state.raw.get
	end
	if vim.api.nvim_buf_get_keymap == state.wrappers.buf_get then
		vim.api.nvim_buf_get_keymap = state.raw.buf_get
	end
	state.api_patched = false
end

local function stop_timer()
	if not state.timer then
		return
	end
	pcall(function()
		state.timer:stop()
		state.timer:close()
	end)
	state.timer = nil
end

local function start_timer()
	if state.timer or not state.pending_resume then
		return
	end
	local uv = vim.uv or vim.loop
	state.timer = uv.new_timer()
	state.timer:start(150, 150, function()
		vim.schedule(function()
			M._tick()
		end)
	end)
end

local function try_resume(force)
	if not mappings.is_suspended() then
		state.pending_resume = false
		stop_timer()
		return false
	end
	if not state.pending_resume and not force then
		stop_timer()
		return false
	end
	if not force then
		if vim.fn.mode() == "c" then
			return false
		end
		if vim.fn.state("mso") ~= "" then
			return false
		end
	end

	mappings.resume_mirrors()
	state.pending_resume = false
	stop_timer()
	return true
end

---@param value string|nil
---@return table|nil
function M.analyze(value)
	if type(value) ~= "string" or value == "" then
		return nil
	end

	local ok, parsed = pcall(vim.api.nvim_parse_cmd, value, {})
	if not ok or type(parsed) ~= "table" then
		return nil
	end
	if parsed.nextcmd and parsed.nextcmd ~= "" then
		return nil
	end
	if not MAP_COMMANDS[parsed.cmd] then
		return nil
	end

	local args = {}
	for _, arg in ipairs(parsed.args or {}) do
		args[#args + 1] = arg
	end
	local index = 1
	while args[index] and MODIFIERS[args[index]:lower()] do
		index = index + 1
	end

	local rest = {}
	for i = index, #args do
		rest[#rest + 1] = args[i]
	end

	local listing
	if #rest == 0 then
		listing = true
	elseif #rest == 1 then
		local text = rest[1]:gsub("%s+$", "")
		listing = text:find("%s") == nil
	else
		listing = false
	end

	return {
		command = parsed.cmd,
		bang = parsed.bang == true,
		listing = listing,
		args = rest,
	}
end

local function cmdline_is_listing()
	local info = M.analyze(vim.fn.getcmdline())
	return info ~= nil and info.listing == true
end

local function cmdline_aborted()
	local ok, abort = pcall(function()
		return vim.v.event and vim.v.event.abort
	end)
	return ok and abort == true
end

local function schedule_resume()
	if not mappings.is_suspended() then
		state.pending_resume = false
		stop_timer()
		return
	end
	state.pending_resume = true
	start_timer()
end

local function on_cmdline_enter()
	if mappings.is_suspended() then
		try_resume(true)
	else
		state.pending_resume = false
		stop_timer()
	end
end

local function on_cmdline_leave()
	if cmdline_is_listing() and not cmdline_aborted() then
		if mappings.is_suspended() or mappings.suspend_mirrors() > 0 then
			schedule_resume()
		else
			state.pending_resume = false
			stop_timer()
		end
	else
		state.pending_resume = false
		stop_timer()
		mappings.resume_mirrors()
	end
end

local function on_safe_state()
	if state.pending_resume then
		try_resume(false)
	end
end

local function on_window_event()
	if mappings.is_suspended() then
		try_resume(true)
	end
end

local function install_hooks()
	if state.hooked then
		return
	end
	state.hooked = true

	local group = vim.api.nvim_create_augroup("PhysicalKeyboardNative", { clear = true })

	if state.commandline then
		vim.api.nvim_create_autocmd("CmdlineEnter", {
			group = group,
			pattern = ":",
			callback = on_cmdline_enter,
		})
		vim.api.nvim_create_autocmd("CmdlineLeave", {
			group = group,
			pattern = ":",
			callback = on_cmdline_leave,
		})
		vim.api.nvim_create_autocmd("SafeState", {
			group = group,
			callback = on_safe_state,
		})
		vim.api.nvim_create_autocmd({
			"WinLeave",
			"WinEnter",
			"BufEnter",
			"TabLeave",
			"TabEnter",
			"FocusGained",
			"VimResume",
		}, {
			group = group,
			callback = on_window_event,
		})
	end
end

function M._tick()
	if not state.enabled then
		return
	end
	try_resume(false)
end

---@param opts table|nil
function M.setup(opts)
	opts = opts or {}
	state.enabled = opts.enabled ~= false
	state.commandline = opts.commandline ~= false
	state.api = opts.api ~= false

	if not state.enabled then
		M.disable()
		return
	end

	if state.hooked then
		M.disable()
		state.enabled = true
	end
	M.enable()
end

function M.enable()
	state.enabled = true
	install_hooks()
	install_getters()
end

function M.disable()
	state.enabled = false
	state.pending_resume = false
	stop_timer()
	mappings.resume_mirrors()
	restore_getters()
	state.hooked = false
	pcall(vim.api.nvim_del_augroup_by_name, "PhysicalKeyboardNative")
end

---@return table
function M.status()
	return {
		enabled = state.enabled,
		commandline = state.commandline,
		api = state.api,
		api_patched = state.api_patched,
		api_enabled = state.api_enabled,
		pending_resume = state.pending_resume,
		suspended = mappings.is_suspended(),
		suspended_count = mappings.suspended_count(),
	}
end

M.filter_mappings = filter_mirrors

return M
