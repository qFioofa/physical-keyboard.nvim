local F = require("physical-keyboard.ui.format")
local data = require("physical-keyboard.ui.data")
local highlights = require("physical-keyboard.ui.highlights")
local pages = require("physical-keyboard.ui.pages")
local picker = require("physical-keyboard.ui.picker")
local options = require("physical-keyboard.options")
local core = require("physical-keyboard")

local M = {}

local state = {
	buf = nil,
	win = nil,
	help_buf = nil,
	help_win = nil,
	group = nil,
	selected = "status.overview",
	expanded = {},
	expanded_modes = {},
	pane = "tree",
	search = "",
	search_mode = false,
	search_prompt = "",
	content_selected = nil,
	doc_selectables = nil,
	tree_scroll = 0,
	content_scroll = 0,
	events = {},
	show_help = false,
	closing = false,
	scheduled = false,
	geometry = nil,
}

local function C(text, hl)
	return { text = tostring(text == nil and "" or text), hl = hl }
end

local function is_open()
	return state.buf ~= nil
		and vim.api.nvim_buf_is_valid(state.buf)
		and state.win ~= nil
		and vim.api.nvim_win_is_valid(state.win)
end

local function root_of(id)
	for _, root in ipairs(pages.tree()) do
		if root.id == id then
			return root
		end
		for _, child in ipairs(root.children or {}) do
			if child.id == id then
				return root
			end
		end
	end
	return nil
end

local function visible_nodes()
	local result = {}
	for _, root in ipairs(pages.tree()) do
		result[#result + 1] = { node = root, depth = 0, root = root }
		if state.expanded[root.id] then
			for _, child in ipairs(root.children or {}) do
				result[#result + 1] = { node = child, depth = 1, root = root }
			end
		end
	end
	return result
end

local function geometry()
	local columns = vim.o.columns
	local lines = vim.o.lines
	local max_width = math.max(20, columns - 2)
	local max_height = math.max(8, lines - 2)
	local width = math.min(max_width, math.max(48, math.floor(columns * 0.9)))
	local help_height = 4
	local height = math.min(math.max(8, lines - help_height - 6), math.max(12, math.floor(lines * 0.78)))
	local tree_width = math.min(36, math.max(18, math.floor(width * 0.29)))
	tree_width = math.min(tree_width, math.max(12, width - 24))
	local content_width = math.max(8, width - tree_width - 1)
	local body_height = math.max(1, height - 2)
	local total = height + help_height + 4
	local row = math.max(1, math.floor((lines - total) / 2))
	return {
		width = width,
		height = height,
		help_height = help_height,
		tree_width = tree_width,
		content_width = content_width,
		body_height = body_height,
		row = row,
		col = math.max(0, math.floor((columns - width) / 2) - 1),
		help_row = row + height + 2,
	}
end

local function update_window()
	if not is_open() then
		return geometry()
	end
	local geo = geometry()
	state.geometry = geo
	vim.api.nvim_win_set_config(state.win, {
		relative = "editor",
		width = geo.width,
		height = geo.height,
		row = geo.row,
		col = geo.col,
		style = "minimal",
		border = "rounded",
		title = { { " physical-keyboard.nvim ", "PhyKeyboardUITitle" } },
		title_pos = "center",
		zindex = 60,
	})
	if state.help_win and vim.api.nvim_win_is_valid(state.help_win) then
		vim.api.nvim_win_set_config(state.help_win, {
			relative = "editor",
			width = geo.width,
			height = geo.help_height,
			row = geo.help_row,
			col = geo.col,
			style = "minimal",
			border = "rounded",
			title = { { " help ", "PhyKeyboardUITitle" } },
			title_pos = "left",
			zindex = 59,
		})
	end
	return geo
end

local function apply_window_highlights()
	if not is_open() then
		return
	end
	local border = state.pane == "content" and "PhyKeyboardUIBorderContent" or "PhyKeyboardUIBorderTree"
	vim.wo[state.win].winhl = table.concat({
		"Normal:PhyKeyboardUINormal",
		"FloatBorder:" .. border,
		"FloatTitle:PhyKeyboardUITitle",
	}, ",")
end

local function add_chunks(marks, line_index, chunks, width, force_hl, base_col)
	local pieces = {}
	local col = 0
	base_col = base_col or 0
	local clipped = F.truncate_chunks(chunks or {}, width)
	for _, chunk in ipairs(clipped) do
		local text = chunk.text or ""
		if text ~= "" then
			pieces[#pieces + 1] = text
			local hl = force_hl or chunk.hl
			if hl then
				marks[#marks + 1] = {
					line = line_index,
					start_col = base_col + col,
					end_col = base_col + col + #text,
					hl_group = hl,
				}
			end
			col = col + #text
		end
	end
	return table.concat(pieces), col
end

local function pad_chunks(chunks, width, hl)
	local used = F.chunks_width(chunks)
	if used < width then
		chunks[#chunks + 1] = C(string.rep(" ", width - used), hl)
	end
	return chunks
end

local function compose_split(marks, line_index, left, right, geo, left_hl, divider, right_hl)
	left = pad_chunks(left, geo.tree_width, left_hl)
	local left_text = add_chunks(marks, line_index, left, geo.tree_width)
	local bar = divider or "│"
	marks[#marks + 1] = {
		line = line_index,
		start_col = #left_text,
		end_col = #left_text + #bar,
		hl_group = "PhyKeyboardUIDivider",
	}
	local right_text = add_chunks(marks, line_index, right, geo.content_width, right_hl, #left_text + #bar)
	local gap = math.max(0, geo.content_width - F.width(right_text))
	return left_text .. bar .. right_text .. string.rep(" ", gap)
end

local function tree_chunks(entry, selected)
	local node = entry.node
	local chunks = {}
	local indent = string.rep("  ", entry.depth)
	local glyph
	if entry.depth == 0 then
		glyph = state.expanded[node.id] and "▾ " or "▸ "
		chunks[#chunks + 1] = C(indent .. glyph, selected and "PhyKeyboardUITreeSelected" or "PhyKeyboardUITreeBranch")
	else
		glyph = selected and "● " or "○ "
		chunks[#chunks + 1] = C(indent .. "  " .. glyph, selected and "PhyKeyboardUITreeSelected" or "PhyKeyboardUIMuted")
	end
	local label_hl = selected and "PhyKeyboardUITreeSelected"
		or (entry.depth == 0 and "PhyKeyboardUITreeActive" or "PhyKeyboardUITree")
	chunks[#chunks + 1] = C(node.title or node.id, label_hl)
	return chunks
end

local function header_chunks(snapshot, geo, node, root, width)
	local status = snapshot.status or {}
	local detect = status.detect or {}
	local left = { C("physical-keyboard", "PhyKeyboardUITitle"), C(" › ", "PhyKeyboardUISeparator") }
	if root and root.id ~= node.id then
		left[#left + 1] = C(root.title or root.id, "PhyKeyboardUIValue")
		left[#left + 1] = C(" › ", "PhyKeyboardUISeparator")
	end
	left[#left + 1] = C(node.title or node.id, "PhyKeyboardUIValue")
	local layout = status.english and "EN" or (status.current_layout or "auto"):upper()
	local provider = detect.provider or (detect.disabled and "detection off") or "no provider"
	local enabled = status.enabled and "enabled" or "disabled"
	local right = {
		C(layout, status.english and "PhyKeyboardUIMuted" or "PhyKeyboardUIOK"),
		C(" · ", "PhyKeyboardUISeparator"),
		C(provider, "PhyKeyboardUIMuted"),
		C(" · ", "PhyKeyboardUISeparator"),
		C(enabled, status.enabled and "PhyKeyboardUIOK" or "PhyKeyboardUIError"),
		C("  ", "PhyKeyboardUIMuted"),
		C(state.pane == "content" and " CONTENT " or " TREE ", state.pane == "content" and "PhyKeyboardUIFocus" or "PhyKeyboardUIMuted"),
	}
	local right_width = F.chunks_width(right)
	left = F.truncate_chunks(left, math.max(0, width - right_width - 2))
	local gap = math.max(1, width - F.chunks_width(left) - right_width)
	left[#left + 1] = C(string.rep(" ", gap), "PhyKeyboardUIHeader")
	for _, chunk in ipairs(right) do
		left[#left + 1] = chunk
	end
	return left
end

local function breadcrumb(snapshot)
	local node = pages.find(state.selected)
	if not node then
		return "physical-keyboard"
	end
	local root = root_of(node.id)
	if root and root.id ~= node.id then
		return "physical-keyboard › " .. (root.title or root.id) .. " › " .. (node.title or node.id)
	end
	return "physical-keyboard › " .. (node.title or node.id)
end

local function ensure_selection()
	local visible = visible_nodes()
	local found = false
	for _, entry in ipairs(visible) do
		if entry.node.id == state.selected then
			found = true
			break
		end
	end
	if not found then
		local root = root_of(state.selected) or pages.tree()[1]
		state.expanded[root.id] = true
		state.selected = pages.first_child(root).id
	end
end

local function adjust_tree_scroll(visible, body_height)
	local selected_index = 1
	for index, entry in ipairs(visible) do
		if entry.node.id == state.selected then
			selected_index = index
			break
		end
	end
	if selected_index <= state.tree_scroll then
		state.tree_scroll = selected_index - 1
	elseif selected_index > state.tree_scroll + body_height then
		state.tree_scroll = selected_index - body_height
	end
	state.tree_scroll = math.max(0, math.min(state.tree_scroll, math.max(0, #visible - body_height)))
	return selected_index
end

local function maybe_probe(node, force)
	if not node or not node.probe then
		return
	end
	local probe = data.probe_state()
	if force or probe.status == "idle" or probe.status == "unavailable" then
		data.start_probe()
	end
end

local function is_readonly_line(chunks)
	if not chunks or #chunks == 0 then
		return true
	end
	local only_separator = true
	local text = F.plain(chunks)
	if vim.trim(text) == "" then
		return true
	end
	for _, chunk in ipairs(chunks) do
		if chunk.hl == "PhyKeyboardUISection" then
			return true
		end
		if chunk.hl ~= "PhyKeyboardUISeparator" then
			only_separator = false
		end
	end
	return only_separator
end

local function line_selectables(lines)
	local result = {}
	for index, line in ipairs(lines or {}) do
		if not is_readonly_line(line) then
			result[#result + 1] = { id = "line:" .. index, line = index }
		end
	end
	return result
end

local function count_matches(snapshot, query)
	query = string.lower(query or "")
	if query == "" then
		return 0
	end
	local count = 0
	for _, item in ipairs(snapshot.mappings and snapshot.mappings.list or {}) do
		local scope = item.global and "global" or ("buffer " .. tostring(item.bufnr or 0))
		local haystack = table.concat({
			item.mode or "",
			item.source_lhs or "",
			item.lhs or "",
			scope,
		}, " "):lower()
		if haystack:find(query, 1, true) then
			count = count + 1
		end
	end
	return count
end

local function build_search_chunks(snapshot)
	if state.search_mode then
		return {
			C(" SEARCH ", "PhyKeyboardUIFocus"),
			C("  " .. state.search_prompt, "PhyKeyboardUIValue"),
			C("▏", "PhyKeyboardUIBadge"),
			C("  Enter apply · Esc cancel", "PhyKeyboardUIMuted"),
		}
	elseif state.search ~= "" then
		return {
			C(" SEARCH ", "PhyKeyboardUIFocus"),
			C("  “" .. state.search .. "”", "PhyKeyboardUIBadge"),
			C(("  %d match(es)  "):format(count_matches(snapshot, state.search)), "PhyKeyboardUINumber"),
			C("/ edit", "PhyKeyboardUIMuted"),
		}
	end
	return {
		C(" SEARCH ", "PhyKeyboardUITab"),
		C("  Press / to search mirrored bindings in this panel.", "PhyKeyboardUIMuted"),
	}
end

local function set_buffer_lines(buf, lines, marks, namespace)
	vim.bo[buf].modifiable = true
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.bo[buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(buf, namespace, 0, -1)
	for _, mark in ipairs(marks) do
		pcall(vim.api.nvim_buf_set_extmark, buf, namespace, mark.line, mark.start_col, {
			end_col = mark.end_col,
			hl_group = mark.hl_group,
			priority = 20,
		})
	end
end

local function render_help(snapshot, node, geo)
	if not state.help_buf or not vim.api.nvim_buf_is_valid(state.help_buf) then
		return
	end
	local marks = {}
	local lines = {}
	lines[1] = select(1, add_chunks(marks, 0, build_search_chunks(snapshot), geo.width))
	lines[2] = select(1, add_chunks(marks, 1, F.rule(geo.width), geo.width))
	local context
	if state.pane == "content" then
		local selected_line = nil
		for _, item in ipairs(state.doc_selectables or {}) do
			if item.id == state.content_selected then
				selected_line = item.line
				break
			end
		end
		local total = #(state.doc_lines or {})
		local position = selected_line or (state.content_scroll + 1)
		if node and node.id == "mappings.modes" then
			context = ("CONTENT  %d/%d · j/k bindings · ←/→ group · i/o expand · [ tree"):format(position, total)
		elseif node and node.id == "config.effective" then
			context = ("CONTENT  %d/%d · Enter/Space change · R reset overrides · [ tree"):format(position, total)
		else
			context = ("CONTENT  %d/%d · j/k lines · i/o open · [ tree · Esc back"):format(position, total)
		end
	else
		local visible = visible_nodes()
		local index = 1
		for i, entry in ipairs(visible) do
			if entry.node.id == state.selected then
				index = i
				break
			end
		end
		context = ("TREE  %d/%d · j/k move · i/o open · Tab section · Esc close"):format(index, #visible)
	end
	lines[3] = select(1, add_chunks(marks, 2, {
		C(state.pane == "content" and " CONTENT " or " TREE ", "PhyKeyboardUIFocus"),
		C("  " .. context:gsub("^%u+%s+", ""), "PhyKeyboardUIMuted"),
	}, geo.width))
	lines[4] = select(1, add_chunks(marks, 3, {
		C(" / search   r refresh   ? help   q close   [ / ] focus pane", "PhyKeyboardUIHelp"),
	}, geo.width))
	set_buffer_lines(state.help_buf, lines, marks, highlights.namespace)
end

local function render()
	if not is_open() then
		return
	end
	local geo = update_window()
	apply_window_highlights()
	local snapshot = data.snapshot()
	local node = pages.find(state.selected) or pages.tree()[1]
	local root = root_of(node.id)
	ensure_selection()
	node = pages.find(state.selected) or node
	root = root_of(node.id) or root

	local function build_doc()
		local ctx = {
			width = geo.content_width,
			events = state.events,
			probe = data.probe_state(),
			search = state.search,
			content_selected = state.content_selected,
			mode_expanded = state.expanded_modes,
		}
		return state.show_help and pages.help(ctx) or pages.render(node, snapshot, ctx)
	end

	local doc = build_doc()
	if not doc.selectables or #doc.selectables == 0 then
		doc.selectables = line_selectables(doc.lines)
	end
	state.doc_selectables = doc.selectables
	if state.pane == "content" and doc.selectables and #doc.selectables > 0 then
		local valid = false
		for _, item in ipairs(doc.selectables) do
			if item.id == state.content_selected then
				valid = true
				break
			end
		end
		if not valid then
			state.content_selected = doc.selectables[1].id
			doc = build_doc()
			if not doc.selectables or #doc.selectables == 0 then
				doc.selectables = line_selectables(doc.lines)
			end
			state.doc_selectables = doc.selectables
		end
	elseif not doc.selectables then
		state.doc_selectables = nil
		state.content_selected = nil
	end

	local visible = visible_nodes()
	local selected_index = adjust_tree_scroll(visible, geo.body_height)
	local content_lines = doc.lines or {}
	state.doc_lines = content_lines
	local selected_content_line = nil
	if state.pane == "content" then
		for _, item in ipairs(state.doc_selectables or {}) do
			if item.id == state.content_selected then
				selected_content_line = item.line
				break
			end
		end
	end
	if state.pane == "content" and state.doc_selectables then
		for _, item in ipairs(state.doc_selectables) do
			if item.id == state.content_selected then
				if item.line <= state.content_scroll then
					state.content_scroll = item.line - 1
				elseif item.line > state.content_scroll + geo.body_height then
					state.content_scroll = item.line - geo.body_height
				end
				break
			end
		end
	end
	state.content_scroll = math.max(
		0,
		math.min(state.content_scroll, math.max(0, #content_lines - geo.body_height))
	)

	local buffer_lines = {}
	local marks = {}
	local left_header = {
		C(state.pane == "tree" and " TREE " or " tree ", state.pane == "tree" and "PhyKeyboardUIFocus" or "PhyKeyboardUIMuted"),
		C(root and root.title or "", "PhyKeyboardUIMuted"),
	}
	buffer_lines[1] = compose_split(marks, 0, left_header, header_chunks(snapshot, geo, node, root, geo.content_width), geo)
	buffer_lines[2] = compose_split(marks, 1, F.rule(geo.tree_width), F.rule(geo.content_width), geo, nil, "┼")

	for row = 1, geo.body_height do
		local tree_index = state.tree_scroll + row
		local tree_entry = visible[tree_index]
		local tree = {}
		if tree_entry then
			tree = tree_chunks(tree_entry, tree_entry.node.id == state.selected)
		end
		local content = content_lines[state.content_scroll + row] or {}
		local content_row = state.content_scroll + row
		buffer_lines[#buffer_lines + 1] = compose_split(
			marks,
			row + 1,
			tree,
			content,
			geo,
			tree_entry and tree_entry.node.id == state.selected and "PhyKeyboardUITreeSelected" or nil,
			"│",
			selected_content_line == content_row and "PhyKeyboardUITreeSelected" or nil
		)
	end


	set_buffer_lines(state.buf, buffer_lines, marks, highlights.namespace)

	local cursor_row
	if state.pane == "content" then
		cursor_row = 3
		if state.doc_selectables then
			for _, item in ipairs(state.doc_selectables) do
				if item.id == state.content_selected then
					cursor_row = 2 + math.max(0, item.line - state.content_scroll)
					break
				end
			end
		end
	else
		cursor_row = 2 + math.max(0, selected_index - state.tree_scroll)
	end
	cursor_row = math.max(2, math.min(geo.height - 1, cursor_row))
	local cursor_col = state.pane == "content" and (geo.tree_width + 1) or 0
	pcall(vim.api.nvim_win_set_cursor, state.win, { cursor_row, cursor_col })
	vim.api.nvim_win_call(state.win, function()
		pcall(vim.fn.winrestview, { topline = 1, leftcol = 0 })
	end)
	render_help(snapshot, node, geo)
end

local function schedule_render()
	if state.scheduled or not is_open() then
		return
	end
	state.scheduled = true
	vim.schedule(function()
		state.scheduled = false
		if not state.closing then
			render()
		end
	end)
end

local function focusable_id(id)
	local node = pages.find(id)
	if not node then
		return id
	end
	local root = root_of(id)
	if root and root.id == node.id and root.children and #root.children > 0 then
		return pages.first_child(root).id
	end
	return id
end

local function select(id, force_probe)
	id = focusable_id(id)
	local node = pages.find(id)
	if not node then
		return false
	end
	local root = root_of(id)
	if root then
		for _, item in ipairs(pages.tree()) do
			state.expanded[item.id] = item.id == root.id
		end
		state.expanded[root.id] = true
	end
	state.selected = id
	state.show_help = false
	state.content_scroll = 0
	maybe_probe(node, force_probe)
	render()
	return true
end

local function move(delta)
	local visible = visible_nodes()
	local current = 1
	for index, entry in ipairs(visible) do
		if entry.node.id == state.selected then
			current = index
			break
		end
	end
	local target = math.max(1, math.min(#visible, current + delta))
	local entry = visible[target]
	if entry then
		local node = entry.node
		local root = root_of(node.id)
		if root and root.id == node.id then
			for _, item in ipairs(pages.tree()) do
				state.expanded[item.id] = item.id == root.id
			end
			state.expanded[root.id] = true
			state.selected = node.id
			state.content_scroll = 0
			maybe_probe(node)
			render()
		else
			select(node.id)
		end
	end
end

local function cycle_root(delta)
	local roots = pages.tree()
	local current = root_of(state.selected)
	local index = 1
	for i, root in ipairs(roots) do
		if current and root.id == current.id then
			index = i
			break
		end
	end
	index = ((index - 1 + delta) % #roots) + 1
	local root = roots[index]
	select(pages.first_child(root).id)
end

local function toggle_fold()
	local node = pages.find(state.selected)
	if not node then
		return
	end
	local root = root_of(state.selected)
	if root and root.id == node.id then
		state.expanded[node.id] = not state.expanded[node.id]
		render()
	elseif root then
		state.expanded[root.id] = false
		state.selected = root.id
		render()
	end
end

local function expand_or_enter()
	local node = pages.find(state.selected)
	if not node then
		return
	end
	local root = root_of(state.selected)
	if root and root.id == node.id then
		if not state.expanded[root.id] then
			state.expanded[root.id] = true
			render()
		else
			select(pages.first_child(root).id)
		end
	end
end

local function scroll(delta)
	state.content_scroll = math.max(0, state.content_scroll + delta)
	render()
end

local function open_selected()
	local node = pages.find(state.selected)
	if not node then
		return
	end
	local root = root_of(state.selected)
	if root and root.id == node.id then
		state.expanded[root.id] = true
		state.selected = pages.first_child(root).id
	end
	state.pane = "content"
	state.content_scroll = 0
	render()
end

local function selectable_index()
	for index, item in ipairs(state.doc_selectables or {}) do
		if item.id == state.content_selected then
			return index
		end
	end
	return nil
end

local function content_move(delta)
	if state.pane ~= "content" then
		move(delta)
		return
	end
	local selectables = state.doc_selectables or {}
	if #selectables == 0 then
		scroll(delta)
		return
	end
	local index = selectable_index() or 1
	index = math.max(1, math.min(#selectables, index + delta))
	state.content_selected = selectables[index].id
	render()
end

local function selected_mode_id()
	local id = state.content_selected
	if type(id) ~= "string" then
		return nil
	end
	return id:match("^group:(.+)$") or id:match("^item:([^:]+):%d+$")
end

local activate_setting
local delete_overrides

local function content_activate()
	local node = pages.find(state.selected)
	if state.pane == "content" and state.content_selected then
		local setting = state.content_selected:match("^setting:(.+)$")
		if setting then
			activate_setting(setting)
			return
		end
		if state.content_selected == "action:overrides.delete" then
			delete_overrides()
			return
		end
	end
	if state.pane == "content" and node and node.id == "mappings.modes" and state.content_selected then
		local mode = state.content_selected:match("^group:(.+)$")
		if mode then
			state.expanded_modes[mode] = not state.expanded_modes[mode]
			render()
		end
		return
	end
	open_selected()
end

local function report_setting(path, value, ok, err, persisted)
	if not ok then
		core.notify(("Could not change %s: %s"):format(path, tostring(err)), vim.log.levels.ERROR)
		return
	end
	local suffix = persisted and "" or " (session only)"
	core.notify(("%s → %s%s"):format(path, tostring(value), suffix), vim.log.levels.INFO)
end

activate_setting = function(path)
	local spec = options.spec(path)
	if not spec then
		return
	end
	if not core.config then
		core.config = require("physical-keyboard.config").resolve({})
	end
	local value = options.get(core.config, path)
	if spec.kind == "bool" then
		local next_value = not value
		local ok, err, persisted = core.set_option(path, next_value)
		report_setting(path, next_value and "on" or "off", ok, err, persisted)
		data.invalidate()
		render()
		return
	end

	local choices = options.choices(spec, core.config)
	picker.open({
		title = spec.path,
		kind = spec.kind,
		value = value,
		choices = choices,
		description = spec.description,
		example = spec.example,
		notes = spec.notes,
		allow_empty = spec.empty == "unset",
		on_apply = function(new_value)
			local ok, err, persisted = core.set_option(path, new_value)
			report_setting(path, options.format(spec, core.config), ok, err, persisted)
			data.invalidate()
			render()
		end,
		on_cancel = function()
			render()
		end,
	})
end

delete_overrides = function()
	local info = core.overrides_info()
	if not info.exists then
		core.notify("No override file to delete", vim.log.levels.WARN)
		render()
		return
	end
	picker.open({
		title = "Delete override file",
		kind = "confirm",
		value = "delete",
		choices = {
			{ value = "delete", label = "Delete " .. info.file },
			{ value = "keep", label = "Keep the override file" },
		},
		description = "Remove every setting saved from this panel and reload the base configuration.",
		example = info.file,
		notes = "This does not modify your setup() call or your Lua configuration file.",
		on_apply = function(value)
			if value ~= "delete" then
				render()
				return
			end
			local ok, err = core.reset_overrides()
			if ok then
				core.notify("Override file removed; configuration reloaded", vim.log.levels.INFO)
			else
				core.notify("Could not remove overrides: " .. tostring(err), vim.log.levels.ERROR)
			end
			data.invalidate()
			render()
		end,
		on_cancel = function()
			render()
		end,
	})
end

local function content_parent()
	local node = pages.find(state.selected)
	if state.pane ~= "content" or not node or node.id ~= "mappings.modes" then
		return
	end
	local mode = selected_mode_id()
	if mode and state.content_selected ~= "group:" .. mode then
		state.content_selected = "group:" .. mode
		render()
	end
end

local function content_enter()
	local node = pages.find(state.selected)
	if state.pane ~= "content" or not node or node.id ~= "mappings.modes" then
		return
	end
	local mode = state.content_selected and state.content_selected:match("^group:(.+)$")
	if not mode then
		return
	end
	if not state.expanded_modes[mode] then
		state.expanded_modes[mode] = true
		render()
		return
	end
	for _, item in ipairs(state.doc_selectables or {}) do
		if item.id:sub(1, #("item:" .. mode .. ":")) == ("item:%s:"):format(mode) then
			state.content_selected = item.id
			render()
			return
		end
	end
end

local function search_binds()
	local previous = state.search
	local confirmed = false
	state.search_mode = true
	state.search_prompt = previous
	while true do
		render()
		pcall(vim.cmd, "redraw")
		local ok, char = pcall(vim.fn.getcharstr)
		if not ok or char == "\27" then
			break
		end
		if char == "\r" or char == "\n" then
			confirmed = true
			break
		end
		if char == "\b" or char == "\127" or char == "\128kb" then
			local count = vim.fn.strchars(state.search_prompt)
			state.search_prompt = count > 0 and vim.fn.strcharpart(state.search_prompt, 0, count - 1) or ""
		elseif char == "\21" then
			state.search_prompt = ""
		elseif char:byte(1) >= 32 and char:byte(1) ~= 127 then
			state.search_prompt = state.search_prompt .. char
		end
	end
	state.search_mode = false
	if confirmed then
		state.search = vim.trim(state.search_prompt)
		state.pane = "content"
		select("mappings.list")
	else
		state.search = previous
		render()
	end
end

local function buffer_map(lhs, fn, desc)
	if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then
		return
	end
	local options = {
		buffer = state.buf,
		nowait = true,
		silent = true,
		desc = "pkb: UI " .. desc,
	}
	vim.keymap.set("n", lhs, fn, options)
	local ok, mappings = pcall(require, "physical-keyboard.mappings")
	if not ok or type(mappings.variants) ~= "function" then
		return
	end
	local seen = { [lhs] = true }
	local variants = mappings.variants(lhs)
	for _, variant in ipairs(variants) do
		if variant.lhs and not seen[variant.lhs] then
			seen[variant.lhs] = true
			vim.keymap.set("n", variant.lhs, fn, options)
		end
	end
end

local function create_keymaps()
	buffer_map("j", function()
		content_move(1)
	end, "move down")
	buffer_map("<Down>", function()
		content_move(1)
	end, "move down")
	buffer_map("k", function()
		content_move(-1)
	end, "move up")
	buffer_map("<Up>", function()
		content_move(-1)
	end, "move up")
	buffer_map("h", function()
		state.pane = "tree"
		render()
	end, "focus tree")
	buffer_map("<Left>", function()
		if state.pane == "tree" then
			toggle_fold()
		else
			content_parent()
		end
	end, "collapse")
	buffer_map("l", function()
		state.pane = "content"
		state.content_scroll = 0
		render()
	end, "focus content")
	buffer_map("<Right>", function()
		if state.pane == "tree" then
			expand_or_enter()
		else
			content_enter()
		end
	end, "expand")
	buffer_map("<CR>", function()
		if state.pane == "content" then
			content_activate()
		else
			expand_or_enter()
		end
	end, "activate")
	buffer_map("i", content_activate, "open item")
	buffer_map("o", content_activate, "open item")
	buffer_map("<Space>", function()
		if state.pane ~= "content" then
			return
		end
		local id = state.content_selected or ""
		local setting = id:match("^setting:(.+)$")
		if setting then
			activate_setting(setting)
		elseif id == "action:overrides.delete" then
			delete_overrides()
		end
	end, "change setting")
	buffer_map("R", function()
		if state.show_help then
			return
		end
		local node = pages.find(state.selected)
		if state.pane == "content" and node and node.id == "config.effective" then
			delete_overrides()
		end
	end, "reset overrides")
	buffer_map("[", function()
		state.pane = "tree"
		render()
	end, "focus tree")
	buffer_map("]", function()
		state.pane = "content"
		state.content_scroll = 0
		render()
	end, "focus content")
	buffer_map("/", search_binds, "search bindings")
	buffer_map("<Tab>", function()
		cycle_root(1)
	end, "next section")
	buffer_map("<S-Tab>", function()
		cycle_root(-1)
	end, "previous section")
	buffer_map("g", function()
		if state.pane == "content" then
			if state.doc_selectables and state.doc_selectables[1] then
				state.content_selected = state.doc_selectables[1].id
			else
				state.content_scroll = 0
			end
			render()
			return
		end
		local visible = visible_nodes()
		if visible[1] then
			select(visible[1].node.id)
		end
	end, "first")
	buffer_map("G", function()
		if state.pane == "content" then
			if state.doc_selectables and state.doc_selectables[#state.doc_selectables] then
				state.content_selected = state.doc_selectables[#state.doc_selectables].id
			elseif state.geometry then
				state.content_scroll = math.max(0, #(state.doc_lines or {}) - state.geometry.body_height)
			end
			render()
			return
		end
		local visible = visible_nodes()
		if visible[#visible] then
			select(visible[#visible].node.id)
		end
	end, "last")
	buffer_map("<C-d>", function()
		scroll(math.max(1, math.floor((state.geometry and state.geometry.body_height or 10) / 2)))
	end, "scroll down")
	buffer_map("<C-u>", function()
		scroll(-math.max(1, math.floor((state.geometry and state.geometry.body_height or 10) / 2)))
	end, "scroll up")
	buffer_map("r", function()
		data.invalidate()
		local node = pages.find(state.selected)
		if node then
			maybe_probe(node, true)
		end
		render()
	end, "refresh")
	buffer_map("?", function()
		state.show_help = not state.show_help
		render()
	end, "help")
	buffer_map("<ScrollWheelUp>", function()
		if state.pane == "tree" then
			move(-1)
		else
			content_move(-1)
		end
	end, "scroll up")
	buffer_map("<ScrollWheelDown>", function()
		if state.pane == "tree" then
			move(1)
		else
			content_move(1)
		end
	end, "scroll down")
	buffer_map("q", function()
		M.close()
	end, "close")
	buffer_map("<Esc>", function()
		if state.pane == "content" then
			state.pane = "tree"
			render()
		else
			M.close()
		end
	end, "back or close")
end

local function event_detail(args)
	local value = args.data or {}
	local parts = {}
	if value.id then
		parts[#parts + 1] = tostring(value.id)
	end
	if value.provider then
		parts[#parts + 1] = tostring(value.provider)
	end
	if value.raw then
		parts[#parts + 1] = tostring(value.raw)
	end
	return table.concat(parts, " · ")
end

local function create_autocmds()
	state.group = vim.api.nvim_create_augroup("PhysicalKeyboardUI", { clear = true })
	vim.api.nvim_create_autocmd("User", {
		group = state.group,
		pattern = {
			"PhysicalKeyboardEnabled",
			"PhysicalKeyboardDisabled",
			"PhysicalKeyboardLayoutChanged",
			"PhysicalKeyboardConfigChanged",
			"PhysicalKeyboardConfigReloaded",
		},
		callback = function(args)
			state.events[#state.events + 1] = {
				name = args.match,
				at = os.date("%H:%M:%S"),
				detail = event_detail(args),
			}
			while #state.events > 30 do
				table.remove(state.events, 1)
			end
			data.invalidate()
			create_keymaps()
			schedule_render()
		end,
	})
	vim.api.nvim_create_autocmd("VimResized", {
		group = state.group,
		callback = schedule_render,
	})
	vim.api.nvim_create_autocmd("ColorScheme", {
		group = state.group,
		callback = function()
			highlights.setup()
			schedule_render()
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		group = state.group,
		buffer = state.buf,
		callback = function()
			if not state.closing then
				M.close()
			end
		end,
	})
	if state.help_buf then
		vim.api.nvim_create_autocmd("BufWipeout", {
			group = state.group,
			buffer = state.help_buf,
			callback = function()
				if not state.closing then
					M.close()
				end
			end,
		})
	end
end

function M.is_open()
	return is_open()
end

local function open_help_window(geo)
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].undolevels = -1
	vim.bo[buf].modifiable = true
	vim.bo[buf].filetype = "physical-keyboard-ui-help"
	pcall(vim.api.nvim_buf_set_name, buf, "physical-keyboard://help")
	local win = vim.api.nvim_open_win(buf, false, {
		relative = "editor",
		width = geo.width,
		height = geo.help_height,
		row = geo.help_row,
		col = geo.col,
		style = "minimal",
		border = "rounded",
		title = { { " help ", "PhyKeyboardUITitle" } },
		title_pos = "left",
		zindex = 59,
		focusable = false,
		mouse = false,
		noautocmd = true,
	})
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
	state.help_buf = buf
	state.help_win = win
	return buf, win
end

function M.open()
	if is_open() then
		vim.api.nvim_set_current_win(state.win)
		data.invalidate()
		schedule_render()
		return state.buf
	end

	highlights.setup()
	data.invalidate()
	state.closing = false
	state.selected = "status.overview"
	state.expanded = { status = true }
	state.expanded_modes = {}
	state.pane = "tree"
	state.search = ""
	state.search_mode = false
	state.search_prompt = ""
	state.content_selected = nil
	state.doc_selectables = nil
	state.doc_lines = nil
	state.tree_scroll = 0
	state.content_scroll = 0
	state.show_help = false

	local geo = geometry()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].buftype = "nofile"
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].swapfile = false
	vim.bo[buf].undolevels = -1
	vim.bo[buf].modifiable = true
	vim.bo[buf].filetype = "physical-keyboard-ui"
	pcall(vim.api.nvim_buf_set_name, buf, "physical-keyboard://ui")
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		width = geo.width,
		height = geo.height,
		row = geo.row,
		col = geo.col,
		style = "minimal",
		border = "rounded",
		title = { { " physical-keyboard.nvim ", "PhyKeyboardUITitle" } },
		title_pos = "center",
		zindex = 60,
		noautocmd = true,
	})
	state.buf = buf
	state.win = win
	state.geometry = geo
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
	open_help_window(geo)
	create_keymaps()
	create_autocmds()
	data.set_on_change(schedule_render)
	render()
	return buf
end

function M.close()
	if state.closing then
		return
	end
	state.closing = true
	picker.close()
	data.set_on_change(nil)
	if state.group then
		pcall(vim.api.nvim_del_augroup_by_id, state.group)
		state.group = nil
	end
	local win = state.win
	local buf = state.buf
	local help_win = state.help_win
	local help_buf = state.help_buf
	state.win = nil
	state.buf = nil
	state.help_win = nil
	state.help_buf = nil
	if help_win and vim.api.nvim_win_is_valid(help_win) then
		pcall(vim.api.nvim_win_close, help_win, true)
	end
	if help_buf and vim.api.nvim_buf_is_valid(help_buf) then
		pcall(vim.api.nvim_buf_delete, help_buf, { force = true })
	end
	if win and vim.api.nvim_win_is_valid(win) then
		pcall(vim.api.nvim_win_close, win, true)
	end
	if buf and vim.api.nvim_buf_is_valid(buf) then
		pcall(vim.api.nvim_buf_delete, buf, { force = true })
	end
	state.events = {}
	state.tree_scroll = 0
	state.content_scroll = 0
	state.show_help = false
	state.search_mode = false
	state.search_prompt = ""
	state.doc_selectables = nil
	state.doc_lines = nil
	state.content_selected = nil
	state.closing = false
end

function M.toggle()
	if is_open() then
		M.close()
	else
		M.open()
	end
end

function M.refresh(force)
	data.invalidate()
	local node = pages.find(state.selected)
	if node then
		maybe_probe(node, force)
	end
	render()
end

function M.select(id)
	return select(id)
end

function M.set_pane(pane)
	if pane ~= "tree" and pane ~= "content" then
		return false
	end
	state.pane = pane
	render()
	return true
end

function M.pane()
	return state.pane
end

function M.open_selected()
	open_selected()
end

function M.content_move(delta)
	content_move(delta or 1)
end

function M.tree_move(delta)
	move(delta or 1)
end

function M.content_activate()
	content_activate()
end

function M.search(query)
	state.search = vim.trim(query or "")
	state.pane = "content"
	select("mappings.list")
end

function M.search_query()
	return state.search
end

function M.content_selected()
	return state.content_selected
end

function M.content_selectables()
	return vim.deepcopy(state.doc_selectables or {})
end

function M.help_buffer()
	return state.help_buf
end

function M.current()
	if not is_open() then
		return nil
	end
	return state.selected
end

function M.title()
	if not is_open() then
		return ""
	end
	return breadcrumb(data.snapshot())
end

function M.activate_setting(path)
	activate_setting(path)
end

function M.delete_overrides()
	delete_overrides()
end

function M.picker()
	return picker.state()
end

function M.picker_move(delta)
	picker.move(delta or 1)
end

function M.picker_toggle()
	picker.toggle()
end

function M.picker_confirm()
	picker.confirm()
end

function M.picker_cancel()
	picker.cancel()
end

return M
