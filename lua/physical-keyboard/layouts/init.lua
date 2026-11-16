local data = require("physical-keyboard.layouts.data")

--- Layout registry.
---
--- A layout definition is a table:
---   { title: string, names: string[], map: table<string, string> }
--- where `map` is keyed by the English (QWERTY) character and the value is the
--- character produced by the same physical key on the target layout.
local M = {
	data = data,
}

local cache = {}

local function upper(str)
	return vim.fn.toupper(str)
end

local function tolower(str)
	return vim.fn.tolower(str)
end

local function is_letter(str)
	if type(str) ~= "string" or str == "" or vim.fn.strchars(str) ~= 1 then
		return false
	end
	return upper(str) ~= str or tolower(str) ~= str
end

local function sorted_keys(tbl)
	local keys = {}
	for key in pairs(tbl or {}) do
		keys[#keys + 1] = key
	end
	table.sort(keys)
	return keys
end

---@param id string
---@param def table
function M.register(id, def)
	if type(id) ~= "string" or id == "" then
		return false, "layout id must be a non-empty string"
	end
	if type(def) ~= "table" or type(def.map) ~= "table" then
		return false, "layout definition must contain a 'map' table"
	end
	data[id] = {
		title = def.title or id,
		names = def.names or { id },
		map = def.map,
	}
	cache[id] = nil
	return true
end

---@param id string
---@return table|nil
function M.get(id)
	if cache[id] then
		return cache[id]
	end

	local raw = data[id]
	if not raw then
		return nil
	end

	local forward = {}
	local reverse = {}
	local pairs_list = {}
	local seen_from = {}

	local function add(en, native)
		if type(en) ~= "string" or type(native) ~= "string" then
			return
		end
		if en == "" or native == "" or en == native then
			return
		end

		if vim.fn.strchars(en) ~= vim.fn.strchars(native) then
			return
		end

		forward[en] = native

		if reverse[native] == nil then
			reverse[native] = en
		end

		if not seen_from[native] then
			seen_from[native] = true
			pairs_list[#pairs_list + 1] = { from = native, to = en }
		end
	end

	for _, en in ipairs(sorted_keys(raw.map)) do
		add(en, raw.map[en])
	end

	for _, en in ipairs(sorted_keys(raw.map)) do
		local native = raw.map[en]
		if is_letter(en) and is_letter(native) then
			local upper_en = upper(en)
			local upper_native = upper(native)
			if upper_en ~= en or upper_native ~= native then
				add(upper_en, upper_native)
			end
		end
	end

	local layout = {
		id = id,
		title = raw.title or id,
		names = raw.names or { id },
		forward = forward,
		reverse = reverse,
		pairs = pairs_list,
	}

	cache[id] = layout
	return layout
end

--- Returns all registered layout ids (sorted).
---@return string[]
function M.ids()
	local ids = sorted_keys(data)
	return ids
end

--- Builds a merged English -> native map for the given layouts.
--- Conflicting English keys keep the first layout's value (ids are processed
--- in the order given).
---@param ids string[]
---@return table<string, string>
function M.forward_for(ids)
	local merged = {}
	for _, id in ipairs(ids or {}) do
		local layout = M.get(id)
		if layout then
			for en, native in pairs(layout.forward) do
				if merged[en] == nil then
					merged[en] = native
				end
			end
		end
	end
	return merged
end

--- Builds a merged native -> English map for the given layouts.
---@param ids string[]
---@return table<string, string>
function M.reverse_for(ids)
	local merged = {}
	for _, id in ipairs(ids or {}) do
		local layout = M.get(id)
		if layout then
			for native, en in pairs(layout.reverse) do
				if merged[native] == nil then
					merged[native] = en
				end
			end
		end
	end
	return merged
end

local ENGLISH_HINTS = {
	"^us$",
	"^eng$",
	"^en$",
	"^en%-",
	"english",
	"keylayout%.us",
	"keylayout%.abc",
	"xkb:us::",
	"keyboard%-us",
}

--- Windows LCID -> layout id. `1033` means the plain US layout.
local LCID = {
	["1033"] = "us",
	["00000409"] = "us",
	["1049"] = "ru",
	["00000419"] = "ru",
	["1059"] = "by",
	["00000423"] = "by",
	["1031"] = "de",
	["00000407"] = "de",
	["1036"] = "fr",
	["0000040c"] = "fr",
	["1034"] = "es",
	["0000040a"] = "es",
	["1040"] = "it",
	["00000410"] = "it",
	["1058"] = "uk",
	["00000422"] = "uk",
	["1029"] = "cs",
	["00000405"] = "cs",
	["1053"] = "sv",
	["0000041d"] = "sv",
	["1055"] = "tr",
	["0000041f"] = "tr",
	["1032"] = "gr",
	["00000408"] = "gr",
	["1037"] = "he",
	["0000040d"] = "he",
	["1025"] = "ar",
	["00000401"] = "ar",
	["1065"] = "fa",
	["00000429"] = "fa",
	["1087"] = "kk",
	["0000043f"] = "kk",
	["1042"] = "kr",
	["00000412"] = "kr",
}

local function normalize_lcid(value)
	if type(value) ~= "string" then
		return nil
	end
	local decimal = value:match("^0*(%d+)$")
	if decimal and LCID[decimal] then
		return LCID[decimal]
	end
	local hex = value:match("^0*([0-9a-f]+)$")
	if hex then
		return LCID[string.format("00000%s", hex)] or LCID[hex]
	end
	return nil
end

--- Returns true when the detected layout name means a plain English layout.
---@param detected string|nil
---@return boolean
function M.is_english(detected)
	if type(detected) ~= "string" or detected == "" then
		return false
	end
	local value = tolower(detected)
	if normalize_lcid(value) == "us" then
		return true
	end
	for _, pattern in ipairs(ENGLISH_HINTS) do
		if value:find(pattern) then
			return true
		end
	end
	return false
end

--- Tries to map a raw layout name reported by the OS to a registered layout.
---@param detected string|nil
---@param ids string[]|nil
---@return string|nil id
---@return string|nil matched_name
function M.match(detected, ids)
	if type(detected) ~= "string" or detected == "" then
		return nil, nil
	end

	local value = tolower(detected)
	local candidates = ids or M.ids()

	local lcid_id = normalize_lcid(value)
	if lcid_id then
		if lcid_id == "us" then
			return nil, nil
		end
		for _, id in ipairs(candidates) do
			if id == lcid_id then
				return id, "lcid"
			end
		end
	end

	for _, id in ipairs(candidates) do
		local layout = M.get(id)
		for _, name in ipairs(layout and layout.names or {}) do
			if tolower(name) == value then
				return id, name
			end
		end
	end

	for _, id in ipairs(candidates) do
		local layout = M.get(id)
		for _, name in ipairs(layout and layout.names or {}) do
			local needle = tolower(name)
			if #needle >= 2 and value:find(needle, 1, true) then
				return id, name
			end
		end
	end

	return nil, nil
end

return M
