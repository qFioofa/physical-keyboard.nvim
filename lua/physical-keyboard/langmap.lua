local layouts = require("physical-keyboard.layouts")

--- Builds and applies the Neovim 'langmap' option.
---
--- 'langmap' translates characters typed in Normal/Visual/Select/Operator
--- pending modes (and insert-mode mappings) to the key they occupy on a
--- standard English layout.  Unlike per-key mappings, this is handled inside
--- Neovim's input loop and covers every built-in motion and operator.
local M = {}

local ESCAPE_CHARS = [[;,."|\]]

local saved_langmap = nil
local saved_langremap = nil

local function escape(str)
	return vim.fn.escape(str, ESCAPE_CHARS)
end

M.escape = escape

---@param ids string[]
---@param unique boolean|nil Only keep pairs which cannot be confused with
---another layout (useful when the active layout is unknown).
---@return string
function M.build(ids, unique)
	local all = {}

	for _, id in ipairs(ids or {}) do
		local layout = layouts.get(id)
		if layout then
			for _, pair in ipairs(layout.pairs) do
				all[#all + 1] = pair
			end
		end
	end

	local selected

	if unique then
		local counter = {}
		for _, pair in ipairs(all) do
			counter[pair.from] = (counter[pair.from] or 0) + 1
			counter[pair.to] = (counter[pair.to] or 0) + 1
		end

		selected = {}
		for _, pair in ipairs(all) do
			if counter[pair.from] == 1 then
				selected[#selected + 1] = pair
			end
		end
	else
		local seen = {}
		selected = {}
		for _, pair in ipairs(all) do
			if not seen[pair.from] then
				seen[pair.from] = true
				selected[#selected + 1] = pair
			end
		end
	end

	local parts = {}
	for _, pair in ipairs(selected) do
		parts[#parts + 1] = escape(pair.from) .. ";" .. escape(pair.to)
	end

	return table.concat(parts, ",")
end

---@return number
function M.count(value)
	if type(value) ~= "string" or value == "" then
		return 0
	end
	local total = 0
	local escaped = false
	for index = 1, #value do
		local byte = value:sub(index, index)
		if escaped then
			escaped = false
		elseif byte == "\\" then
			escaped = true
		elseif byte == "," then
			total = total + 1
		end
	end
	return total + 1
end

--- Remembers the user's own 'langmap'/'langremap' so it can be restored.
function M.capture()
	if saved_langmap == nil then
		saved_langmap = vim.o.langmap
		saved_langremap = vim.o.langremap
	end
end

---@param value string
---@return boolean success
---@return string|nil error
function M.set(value)
	M.capture()
	local ok, err = pcall(function()
		vim.o.langmap = value or ""
		vim.o.langremap = false
	end)
	if not ok then
		return false, err
	end
	return true, nil
end

---@return string
function M.current()
	return vim.o.langmap or ""
end

--- Restores the options captured by `capture()`.
function M.restore()
	if saved_langmap ~= nil then
		vim.o.langmap = saved_langmap
		vim.o.langremap = saved_langremap
		saved_langmap = nil
		saved_langremap = nil
	else
		vim.o.langmap = ""
	end
end

return M
