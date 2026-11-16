local layouts = require("physical-keyboard.layouts")
local mappings = require("physical-keyboard.mappings")

--- Command-line helpers.
---
--- 'langmap' is explicitly disabled by Neovim while entering a command line, so
--- `:ц` never becomes `:w` on its own.  This module registers command-line
--- abbreviations for the most common Ex commands in every active layout.
local M = {}

local DEFAULT_ALIASES = {
	"w",
	"w!",
	"q",
	"q!",
	"wq",
	"wq!",
	"wa",
	"qa",
	"qa!",
	"e",
	"e!",
	"ene",
	"bn",
	"bp",
	"bd",
	"bd!",
	"bnext",
	"bprev",
	"bdelete",
	"noh",
	"nohl",
	"nohlsearch",
	"set",
	"setlocal",
	"sort",
	"update",
	"saveas",
	"vimgrep",
	"grep",
	"copen",
	"cclose",
	"lopen",
	"lclose",
	"make",
}

local function is_list(value)
	if next(value) == nil then
		return false
	end
	if vim.islist then
		return vim.islist(value)
	end
	local count = 0
	for _ in pairs(value) do
		count = count + 1
	end
	return count > 0 and value[1] ~= nil
end

local state = {
	enabled = false,
	aliases = DEFAULT_ALIASES,
	extra = {},
	ids = {},
	added = {},
}

local function register(native, english)
	if type(native) ~= "string" or native == "" or type(english) ~= "string" or english == "" then
		return false
	end
	if native == english or state.added[native] then
		return false
	end
	if native:find("[%s|]") then
		return false
	end
	local ok = pcall(vim.cmd, "cnoreabbrev " .. native .. " " .. english)
	if ok then
		state.added[native] = english
		return true
	end
	return false
end

---@param opts table|nil
function M.setup(opts)
	opts = opts or {}
	if opts.enabled ~= nil then
		state.enabled = opts.enabled
	end
	state.ids = opts.active_ids or {}
	state.aliases = vim.deepcopy(DEFAULT_ALIASES)
	for _, alias in ipairs(opts.aliases or {}) do
		table.insert(state.aliases, alias)
	end

	state.extra = {}
	if type(opts.extra) == "table" then
		if is_list(opts.extra) then
			for _, alias in ipairs(opts.extra) do
				table.insert(state.aliases, alias)
			end
		else
			for native, english in pairs(opts.extra) do
				state.extra[native] = english
			end
		end
	end
end

---@param enabled boolean
function M.set_enabled(enabled)
	state.enabled = not not enabled
end

---@param ids string[]
function M.set_active_ids(ids)
	state.ids = ids or {}
end

---@return number
function M.count()
	local total = 0
	for _ in pairs(state.added) do
		total = total + 1
	end
	return total
end

---@return table<string, string>
function M.added()
	return vim.deepcopy(state.added)
end

function M.enable()
	if not state.enabled then
		return 0
	end

	local created = 0
	for native, english in pairs(state.extra) do
		if register(native, english) then
			created = created + 1
		end
	end
	for _, id in ipairs(state.ids) do
		local layout = layouts.get(id)
		if layout then
			for _, english in ipairs(state.aliases) do
				local native = mappings.translate_with(layout.forward, english)
				if register(native, english) then
					created = created + 1
				end
			end
		end
	end
	return created
end

function M.disable()
	for native in pairs(state.added) do
		pcall(vim.cmd, "cunabbrev " .. native)
	end
	state.added = {}
end

--- Adds an explicit native -> English command-line abbreviation.
---@param native string
---@param english string
---@return boolean
function M.add(native, english)
	if type(native) ~= "string" or native == "" then
		return false
	end
	if type(english) ~= "string" or english == "" then
		return false
	end
	state.extra[native] = english
	if state.enabled then
		if state.added[native] then
			pcall(vim.cmd, "cunabbrev " .. native)
			state.added[native] = nil
		end
		return register(native, english)
	end
	return true
end

--- Removes an explicitly added abbreviation (or a generated one).
---@param native string
---@return boolean
function M.remove(native)
	if type(native) ~= "string" or native == "" then
		return false
	end
	local existed = state.extra[native] ~= nil or state.added[native] ~= nil
	state.extra[native] = nil
	if state.added[native] then
		pcall(vim.cmd, "cunabbrev " .. native)
		state.added[native] = nil
	end
	return existed
end

---@return table<string, string>
function M.extra()
	return vim.deepcopy(state.extra)
end

---@param english string
---@return string|nil
function M.resolve(english)
	local native = mappings.translate_with(layouts.forward_for(state.ids), english)
	if native ~= english and state.added[native] then
		return native
	end
	return nil
end

return M
