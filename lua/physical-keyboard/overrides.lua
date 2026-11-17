--- Persistent runtime overrides for options changed from the UI.
---
--- The file is JSON, not Lua, so user configuration files are never rewritten.
--- Only whitelisted option paths are stored; loading can be disabled with
--- `overrides = false` (or `overrides = { enabled = false }`) in setup().
local M = {}

local FORBIDDEN = {
	config_file = true,
	env = true,
	overrides = true,
	userLayouts = true,
	user_layouts = true,
}

---@return string
function M.path()
	local value = vim.env.PKB_OVERRIDES
	if value and value ~= "" then
		return vim.fn.expand(value)
	end
	local state = vim.fn.stdpath("state") or vim.fn.stdpath("data")
	return state .. "/physical-keyboard/overrides.json"
end

---@param path string|nil
---@return boolean
function M.exists(path)
	return vim.fn.filereadable(path or M.path()) == 1
end

---@param path string|nil
---@return table|nil
---@return string|nil
---@return string
function M.load(path)
	path = path or M.path()
	if vim.fn.filereadable(path) ~= 1 then
		return nil, nil, path
	end
	local ok, lines = pcall(vim.fn.readfile, path)
	if not ok then
		return nil, tostring(lines), path
	end
	local text = table.concat(lines, "\n")
	if vim.trim(text) == "" then
		return {}, nil, path
	end
	local decoded
	local decoded_ok, decoded_err = pcall(vim.json.decode, text)
	if decoded_ok then
		decoded = decoded_err
	else
		return nil, tostring(decoded_err), path
	end
	if type(decoded) ~= "table" then
		return nil, "override file must contain a JSON object", path
	end
	return decoded, nil, path
end

local function encode(value)
	local ok, result = pcall(vim.json.encode, value)
	if not ok then
		return nil, tostring(result)
	end
	return result, nil
end

--- Writes overrides atomically so a crash cannot leave a truncated file.
---@param values table
---@param path string|nil
---@return boolean
---@return string|nil
function M.save(values, path)
	path = path or M.path()
	local dir = vim.fn.fnamemodify(path, ":h")
	if dir ~= "" then
		local ok, err = pcall(vim.fn.mkdir, dir, "p")
		if not ok then
			return false, tostring(err)
		end
	end

	local encoded, err = encode(values or {})
	if not encoded then
		return false, err
	end

	local suffix = tostring(vim.uv and vim.uv.hrtime() or os.time())
	local tmp = path .. ".tmp." .. suffix
	local ok, write_err = pcall(vim.fn.writefile, { encoded }, tmp)
	if not ok then
		return false, tostring(write_err)
	end

	local renamed = false
	if vim.uv and vim.uv.fs_rename then
		local rename_ok, rename_err = pcall(vim.uv.fs_rename, tmp, path)
		if rename_ok then
			renamed = true
		else
			err = tostring(rename_err)
		end
	end
	if not renamed then
		local rename_ok, rename_err = pcall(vim.fn.rename, tmp, path)
		if rename_ok then
			renamed = true
		else
			err = tostring(rename_err)
		end
	end
	if not renamed then
		pcall(vim.fn.delete, tmp)
		return false, err or "could not replace override file"
	end
	return true, nil
end

---@param path string|nil
---@return boolean
---@return string|nil
function M.remove(path)
	path = path or M.path()
	if vim.fn.filereadable(path) ~= 1 then
		return true, nil
	end
	local ok, err = pcall(vim.fn.delete, path)
	if not ok then
		return false, tostring(err)
	end
	return true, nil
end

---@param path string
---@return string[]
local function parts(path)
	local result = {}
	for part in tostring(path):gmatch("[^.]+") do
		result[#result + 1] = part
	end
	return result
end

---@param tbl table
---@param path string
---@param value any
function M.set_value_in(tbl, path, value)
	local keys = parts(path)
	if #keys == 0 then
		return
	end
	local node = tbl
	for index = 1, #keys - 1 do
		local key = keys[index]
		if type(node[key]) ~= "table" then
			node[key] = {}
		end
		node = node[key]
	end
	node[keys[#keys]] = value
end

---@param tbl table
---@param path string
function M.unset_value_in(tbl, path)
	local keys = parts(path)
	if #keys == 0 then
		return
	end
	local stack = {}
	local node = tbl
	for index = 1, #keys - 1 do
		local key = keys[index]
		if type(node[key]) ~= "table" then
			return
		end
		stack[#stack + 1] = { parent = node, key = key }
		node = node[key]
	end
	node[keys[#keys]] = nil
	for index = #stack, 1, -1 do
		local entry = stack[index]
		if next(entry.parent[entry.key]) == nil then
			entry.parent[entry.key] = nil
		else
			break
		end
	end
end

--- Sets or removes one option in the override file.
---@param path string
---@param value any nil removes the key
---@param file string|nil
---@return boolean
---@return string|nil
function M.set_value(path, value, file)
	file = file or M.path()
	local values, err = M.load(file)
	if err then
		return false, err
	end
	values = values or {}
	if value == nil then
		M.unset_value_in(values, path)
	else
		M.set_value_in(values, path, value)
	end
	if next(values) == nil then
		return M.remove(file)
	end
	return M.save(values, file)
end

--- Removes dangerous keys from a decoded override table.
---@param values table
---@return table
function M.sanitize(values)
	local result = vim.deepcopy(values or {})
	for key in pairs(FORBIDDEN) do
		result[key] = nil
	end
	return result
end

return M
