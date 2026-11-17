--- Small modal list used by the settings UI.
---
--- It is deliberately independent from the main dashboard so that it can be
--- used for enums, multi-selects and destructive confirmation prompts.
local F = require("physical-keyboard.ui.format")
local highlights = require("physical-keyboard.ui.highlights")

local M = {}

local state = {
	open = false,
	buf = nil,
	win = nil,
	prev_win = nil,
	opts = nil,
	items = {},
	values = {},
	value = nil,
	cursor = 1,
	error = nil,
}

local function is_valid_buf(buf)
	return buf and vim.api.nvim_buf_is_valid(buf)
end

local function is_valid_win(win)
	return win and vim.api.nvim_win_is_valid(win)
end

local function value_key(value)
	if value == nil then
		return "nil"
	end
	return type(value) .. ":" .. tostring(value)
end

local function is_selected(value)
	local key = value_key(value)
	for _, item in ipairs(state.values) do
		if value_key(item) == key then
			return true
		end
	end
	return false
end

local function add_line(lines, text, hl)
	lines[#lines + 1] = { text = text, hl = hl }
end

local function add_wrapped(lines, text, width, hl, prefix)
	prefix = prefix or ""
	for _, line in ipairs(F.wrap(text or "", width)) do
		add_line(lines, prefix .. line, hl)
	end
end

local function item_label(item)
	if item.kind == "multi" then
		return (is_selected(item.value) and "[x] " or "[ ] ") .. item.label
	end
	return (item.current and "● " or "○ ") .. item.label
end

local function build()
	local width = math.max(30, math.min(68, vim.o.columns - 6))
	local text_width = math.max(12, width - 4)
	local lines = {}

	add_wrapped(lines, state.opts.description or "", text_width, "PhyKeyboardUIMuted", "  ")
	if state.opts.example and state.opts.example ~= "" then
		add_wrapped(lines, state.opts.example, text_width, "PhyKeyboardUIInfo", "  Example  ")
	end
	if state.opts.notes and state.opts.notes ~= "" then
		add_wrapped(lines, state.opts.notes, text_width, "PhyKeyboardUIHint", "  Notes    ")
	end
	if #lines > 0 then
		add_line(lines, "")
	end

	add_line(lines, " OPTIONS", "PhyKeyboardUISection")
	for _, item in ipairs(state.items) do
		if not item.cancel then
			local selected = state.cursor == item.index
			local hl = selected and "PhyKeyboardUITreeSelected" or nil
			if item.kind == "multi" and is_selected(item.value) then
				hl = selected and "PhyKeyboardUITreeSelected" or "PhyKeyboardUIOK"
			end
			item.line = #lines + 1
			add_line(lines, "  " .. item_label(item), hl)
		end
	end

	local current = state.items[state.cursor]
	if current and current.description and not current.cancel then
		add_line(lines, "")
		add_wrapped(lines, current.description, text_width, "PhyKeyboardUIMuted", "  ")
	end

	add_line(lines, string.rep("─", width), "PhyKeyboardUISeparator")
	local cancel = state.items[#state.items]
	if cancel and cancel.cancel then
		cancel.line = #lines + 1
		add_line(
			lines,
			"  " .. (state.cursor == cancel.index and "● " or "○ ") .. cancel.label,
			state.cursor == cancel.index and "PhyKeyboardUITreeSelected" or "PhyKeyboardUIMuted"
		)
	end
	add_line(lines, "")
	local footer = state.opts.kind == "multi"
			and "j/k move · Space toggle · Enter apply · Esc cancel"
		or "j/k move · Enter apply · Esc cancel"
	add_line(lines, "  " .. footer, "PhyKeyboardUIHelp")
	if state.error then
		add_line(lines, "  " .. state.error, "PhyKeyboardUIError")
	end
	return lines, width
end

local function render()
	if not state.open or not is_valid_buf(state.buf) or not is_valid_win(state.win) then
		return
	end
	local lines, width = build()
	local text = {}
	for index, line in ipairs(lines) do
		text[index] = line.text
		if state.opts.title then
			-- title is provided by the window, not the buffer
		end
	end
	vim.bo[state.buf].modifiable = true
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, text)
	vim.bo[state.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(state.buf, highlights.namespace, 0, -1)
	for index, line in ipairs(lines) do
		if line.hl then
			pcall(vim.api.nvim_buf_add_highlight, state.buf, highlights.namespace, line.hl, index - 1, 0, -1)
		end
	end

	local height = math.min(math.max(6, #text), math.max(6, vim.o.lines - 6))
	vim.api.nvim_win_set_config(state.win, {
		relative = "editor",
		width = width,
		height = height,
		row = math.max(0, math.floor((vim.o.lines - height) / 2) - 1),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		title = { { " " .. (state.opts.title or "Choose") .. " ", "PhyKeyboardUITitle" } },
		title_pos = "center",
		zindex = 80,
	})

	local cursor_row = 1
	for _, item in ipairs(state.items) do
		if item.index == state.cursor then
			cursor_row = item.line or 1
			break
		end
	end
	pcall(vim.api.nvim_win_set_cursor, state.win, { math.max(1, cursor_row), 0 })
end

local function move(delta)
	if #state.items == 0 then
		return
	end
	state.cursor = math.max(1, math.min(#state.items, state.cursor + delta))
	state.error = nil
	render()
end

local function toggle()
	if state.opts.kind ~= "multi" then
		return
	end
	local item = state.items[state.cursor]
	if not item or item.cancel then
		return
	end
	local key = value_key(item.value)
	local kept = {}
	local found = false
	for _, value in ipairs(state.values) do
		if value_key(value) == key then
			found = true
		else
			kept[#kept + 1] = value
		end
	end
	if not found then
		kept[#kept + 1] = item.value
	end
	state.values = kept
	state.error = nil
	render()
end

local function close()
	if not state.open then
		return
	end
	state.open = false
	local win = state.win
	local buf = state.buf
	local prev = state.prev_win
	state.win = nil
	state.buf = nil
	state.prev_win = nil
	if is_valid_win(win) then
		pcall(vim.api.nvim_win_close, win, true)
	end
	if is_valid_buf(buf) then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
	if is_valid_win(prev) then
		pcall(vim.api.nvim_set_current_win, prev)
	end
	state.opts = nil
	state.items = {}
	state.values = {}
end

local function confirm()
	if not state.open then
		return
	end
	local item = state.items[state.cursor]
	if not item or item.cancel then
		M.cancel()
		return
	end
	if state.opts.kind == "multi" then
		if #state.values == 0 and not state.opts.allow_empty then
			state.error = "select at least one value"
			render()
			return
		end
		local callback = state.opts.on_apply
		local values = vim.deepcopy(state.values)
		close()
		if callback then
			callback(values)
		end
		return
	end
	local callback = state.opts.on_apply
	local value = item.value
	close()
	if callback then
		callback(value)
	end
end

local function map(lhs, fn)
	vim.keymap.set("n", lhs, fn, {
		buffer = state.buf,
		nowait = true,
		silent = true,
		desc = "pkb: picker " .. lhs,
	})
end

local function add_keymaps()
	map("j", function()
		move(1)
	end)
	map("<Down>", function()
		move(1)
	end)
	map("k", function()
		move(-1)
	end)
	map("<Up>", function()
		move(-1)
	end)
	map("<Space>", toggle)
	map("x", toggle)
	map("<CR>", confirm)
	map("o", confirm)
	map("<Esc>", M.cancel)
	map("q", M.cancel)
end

---@param opts table
---@return integer|nil
function M.open(opts)
	if state.open then
		M.close()
	end
	highlights.setup()

	state.opts = opts
	state.prev_win = vim.api.nvim_get_current_win()
	state.cursor = 1
	state.values = {}
	state.value = opts.value
	state.error = nil
	state.items = {}

	local current_key = value_key(opts.value)
	for index, choice in ipairs(opts.choices or {}) do
		local is_current = value_key(choice.value) == current_key
		state.items[#state.items + 1] = {
			index = #state.items + 1,
			value = choice.value,
			label = choice.label or tostring(choice.value),
			description = choice.description,
			kind = opts.kind,
			current = is_current,
		}
		if opts.kind == "multi" and is_current then
			state.values[#state.values + 1] = choice.value
		end
	end
	if opts.kind == "multi" then
		state.values = vim.deepcopy(opts.value or {})
	end
	state.items[#state.items + 1] = {
		index = #state.items + 1,
		cancel = true,
		label = opts.cancel_label or "Cancel",
	}

	local width = math.max(30, math.min(68, vim.o.columns - 6))
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].undolevels = -1
	vim.bo[buf].modifiable = true
	vim.bo[buf].filetype = "physical-keyboard-ui-picker"
	pcall(vim.api.nvim_buf_set_name, buf, "physical-keyboard://picker")

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = width,
		height = math.min(12, math.max(6, vim.o.lines - 6)),
		row = math.max(0, math.floor(vim.o.lines / 3)),
		col = math.max(0, math.floor((vim.o.columns - width) / 2)),
		style = "minimal",
		border = "rounded",
		title = { { " " .. (opts.title or "Choose") .. " ", "PhyKeyboardUITitle" } },
		title_pos = "center",
		zindex = 80,
		noautocmd = true,
	})
	state.buf = buf
	state.win = win
	state.open = true
	vim.wo[win].wrap = false
	vim.wo[win].cursorline = false
	vim.wo[win].number = false
	vim.wo[win].relativenumber = false
	vim.wo[win].signcolumn = "no"
	vim.wo[win].foldcolumn = "0"
	vim.wo[win].spell = false
	vim.wo[win].winhl = table.concat({
		"Normal:PhyKeyboardUINormal",
		"FloatBorder:PhyKeyboardUIBorder",
		"FloatTitle:PhyKeyboardUITitle",
	}, ",")

	add_keymaps()
	render()
	return buf
end

function M.close()
	close()
end

function M.cancel()
	if not state.open then
		return
	end
	local callback = state.opts and state.opts.on_cancel
	close()
	if callback then
		callback()
	end
end

function M.confirm()
	confirm()
end

function M.move(delta)
	move(delta or 1)
end

function M.toggle()
	toggle()
end

function M.is_open()
	return state.open
end

function M.state()
	local items = {}
	for _, item in ipairs(state.items) do
		items[#items + 1] = {
			index = item.index,
			value = item.value,
			label = item.label,
			cancel = item.cancel,
			description = item.description,
		}
	end
	return {
		open = state.open,
		cursor = state.cursor,
		value = state.value,
		values = vim.deepcopy(state.values),
		items = items,
		error = state.error,
	}
end

function M.values()
	return vim.deepcopy(state.values)
end

return M
