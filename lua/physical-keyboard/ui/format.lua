local M = {}

local strwidth = vim.fn.strdisplaywidth
local strchars = vim.fn.strchars

---@param text string
---@return number
function M.width(text)
	return strwidth(text or "")
end

---@param char string
---@return number
function M.char_width(char)
	return strwidth(char)
end

---@param text string
---@param max number
---@return string
function M.truncate(text, max)
	text = tostring(text or "")
	max = math.floor(max or 0)
	if max <= 0 then
		return ""
	end
	if M.width(text) <= max then
		return text
	end
	if max == 1 then
		return "…"
	end
	local out = {}
	local used = 0
	local chars = vim.fn.split(text, "\\zs")
	for _, char in ipairs(chars) do
		local cw = M.char_width(char)
		if used + cw > max - 1 then
			break
		end
		out[#out + 1] = char
		used = used + cw
	end
	return table.concat(out) .. "…"
end

---@param text string
---@param target number
---@param align string|nil
---@return string
function M.pad(text, target, align)
	text = tostring(text or "")
	local gap = math.max(0, (target or 0) - M.width(text))
	if align == "right" then
		return string.rep(" ", gap) .. text
	end
	if align == "center" then
		local left = math.floor(gap / 2)
		return string.rep(" ", left) .. text .. string.rep(" ", gap - left)
	end
	return text .. string.rep(" ", gap)
end

---@param text string
---@param target number
---@return string
function M.ljust(text, target)
	return M.pad(text, target, "left")
end

---@param text string
---@param target number
---@return string
function M.rjust(text, target)
	return M.pad(text, target, "right")
end

---@param chunks table[]
---@return string
function M.plain(chunks)
	local out = {}
	for _, chunk in ipairs(chunks or {}) do
		out[#out + 1] = type(chunk) == "table" and chunk.text or tostring(chunk)
	end
	return table.concat(out)
end

---@param chunks table[]
---@return number
function M.chunks_width(chunks)
	return M.width(M.plain(chunks))
end

---@param chunks table[]
---@param max number
---@return table[]
function M.truncate_chunks(chunks, max)
	max = math.floor(max or 0)
	if max <= 0 then
		return {}
	end
	local result = {}
	local used = 0
	for _, chunk in ipairs(chunks or {}) do
		local text = type(chunk) == "table" and chunk.text or tostring(chunk)
		local hl = type(chunk) == "table" and chunk.hl or nil
		if text ~= "" then
			if used + M.width(text) <= max then
				result[#result + 1] = { text = text, hl = hl }
				used = used + M.width(text)
			else
				local remaining = max - used
				if remaining > 0 then
					local clipped = M.truncate(text, remaining)
					if clipped ~= "" then
						result[#result + 1] = { text = clipped, hl = hl }
						used = used + M.width(clipped)
					end
				end
				break
			end
		end
	end
	return result
end

---@param chunks table[]
---@param target number
---@param align string|nil
---@return table[]
function M.pad_chunks(chunks, target, align)
	local gap = math.max(0, (target or 0) - M.chunks_width(chunks))
	if gap == 0 then
		return chunks
	end
	local spaces = { text = string.rep(" ", gap) }
	if align == "right" then
		table.insert(chunks, 1, spaces)
	elseif align == "center" then
		local left = math.floor(gap / 2)
		local right = gap - left
		table.insert(chunks, 1, { text = string.rep(" ", left) })
		if right > 0 then
			chunks[#chunks + 1] = { text = string.rep(" ", right) }
		end
	else
		chunks[#chunks + 1] = spaces
	end
	return chunks
end

---@param width number
---@param title string|nil
---@param hl string|nil
---@return table[]
function M.rule(width, title, hl)
	local suffix = "─"
	if title and title ~= "" then
		local prefix = "─ " .. title .. " "
		local left = M.truncate(prefix, math.max(0, width - 1))
		local remaining = math.max(0, width - M.width(left))
		return {
			{ text = left, hl = hl or "PhyKeyboardUISection" },
			{ text = string.rep(suffix, remaining), hl = "PhyKeyboardUISeparator" },
		}
	end
	return { { text = string.rep(suffix, math.max(0, width)), hl = "PhyKeyboardUISeparator" } }
end

---@param text string
---@param width number
---@return string[]
function M.wrap(text, width)
	width = math.max(8, math.floor(width or 8))
	local result = {}
	for _, paragraph in ipairs(vim.split(tostring(text or ""), "\n", { plain = true })) do
		if paragraph == "" then
			result[#result + 1] = ""
		else
			local line = ""
			for word in paragraph:gmatch("%S+") do
				if line == "" then
					line = word
				elseif M.width(line .. " " .. word) <= width then
					line = line .. " " .. word
				else
					result[#result + 1] = line
					line = word
				end
			end
			if line ~= "" then
				result[#result + 1] = line
			end
		end
	end
	return result
end

---@param value any
---@return string
---@return string
function M.value(value)
	local kind = type(value)
	if value == nil then
		return "nil", "PhyKeyboardUIMuted"
	elseif kind == "boolean" then
		return value and "true" or "false", "PhyKeyboardUIBoolean"
	elseif kind == "number" then
		return tostring(value), "PhyKeyboardUINumber"
	elseif kind == "string" then
		if value == "" then
			return '""', "PhyKeyboardUIMuted"
		end
		return value, "PhyKeyboardUIValue"
	elseif kind == "function" then
		return "<function>", "PhyKeyboardUIMuted"
	elseif kind == "table" then
		if vim.islist and vim.islist(value) then
			if #value == 0 then
				return "[]", "PhyKeyboardUIMuted"
			end
			local items = {}
			for _, item in ipairs(value) do
				items[#items + 1] = tostring(item)
			end
			return "[" .. table.concat(items, ", ") .. "]", "PhyKeyboardUIValue"
		end
		local keys = vim.tbl_keys(value)
		table.sort(keys)
		if #keys == 0 then
			return "{}", "PhyKeyboardUIMuted"
		end
		local items = {}
		for _, key in ipairs(keys) do
			items[#items + 1] = tostring(key) .. "=" .. tostring(value[key])
		end
		return "{" .. table.concat(items, ", ") .. "}", "PhyKeyboardUIValue"
	end
	return tostring(value), "PhyKeyboardUIValue"
end

---@param text string
---@param target number
---@param limit number
---@return string
function M.ellipsis(text, target, limit)
	local value = M.truncate(text, math.max(target or 0, limit or target or 0))
	return M.pad(value, target)
end

---@param text string
---@return number
function M.chars(text)
	return strchars(text or "")
end

return M
