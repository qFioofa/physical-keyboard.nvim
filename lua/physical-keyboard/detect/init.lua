local layouts = require("physical-keyboard.layouts")
local providers = require("physical-keyboard.detect.providers")

--- Detects the active OS keyboard layout and maps it to a bundled layout id.
local M = {}

local empty = { provider = nil, raw = nil, layout = nil, english = false }

local state = {
	enabled = true,
	min_interval = 300,
	timeout = 500,
	provider = nil,
	providers = nil,
	remote = "auto",
	async = true,
	active_ids = {},
	override = nil,
	last = vim.deepcopy(empty),
	last_at = 0,
	in_flight = false,
	request = nil,
	pending = {},
	generation = 0,
}

---@param opts table|nil
function M.setup(opts)
	opts = opts or {}
	state.override = nil
	state.in_flight = false
	state.request = nil
	state.pending = {}
	state.generation = state.generation + 1
	if opts.enabled ~= nil then
		state.enabled = opts.enabled
	end
	if opts.min_interval then
		state.min_interval = opts.min_interval
	end
	if opts.timeout then
		state.timeout = opts.timeout
	end
	state.provider = opts.provider
	state.providers = opts.providers
	if opts.remote ~= nil then
		state.remote = opts.remote
	end
	if opts.async ~= nil then
		state.async = opts.async
	end
	if opts.active_ids then
		state.active_ids = opts.active_ids
	end
	state.last_at = 0
end

---@param ids string[]
function M.set_active_ids(ids)
	state.active_ids = ids or {}
end

---@param id string|nil
function M.set_override(id)
	state.override = id
	state.generation = state.generation + 1
end

---@return string|nil
function M.get_override()
	return state.override
end

---@return table
function M.last()
	return state.last
end

--- True when detection is intentionally disabled for this session.
---@return boolean
function M.remote_disabled()
	if state.remote == false then
		return true
	end
	if state.remote == "auto" and providers.is_remote() then
		return true
	end
	return false
end

---@return boolean
function M.is_remote()
	return providers.is_remote()
end

---@return boolean
function M.is_async()
	return state.async
end

---@return table
function M.options()
	return {
		provider = state.provider,
		providers = state.providers,
		timeout = state.timeout,
	}
end

local function now_ms()
	if vim.uv and vim.uv.hrtime then
		return vim.uv.hrtime() / 1e6
	end
	return os.clock() * 1000
end

---@param raw string|nil
---@param provider string|nil
---@return table
local function compute(raw, provider)
	if not raw then
		return { provider = provider, raw = nil, layout = nil, english = false }
	end
	local english = layouts.is_english(raw)
	local id = nil
	if not english then
		-- Match against every bundled layout: the adapter reports the real OS
		-- layout, which is authoritative even if the user did not list it.
		id = layouts.match(raw, nil)
	end
	return { provider = provider, raw = raw, layout = id, english = english }
end

local function disabled_result(reason)
	return {
		provider = nil,
		raw = nil,
		layout = nil,
		english = false,
		disabled = reason,
	}
end

---@param force boolean|nil
---@return table
function M.detect(force)
	if state.override then
		state.last = {
			provider = "override",
			raw = state.override,
			layout = state.override,
			english = false,
		}
		return state.last
	end

	if not state.enabled then
		state.last = disabled_result("config")
		return state.last
	end

	if M.remote_disabled() then
		state.last = disabled_result("remote")
		return state.last
	end

	local current = now_ms()
	if not force and (current - state.last_at) < state.min_interval then
		return state.last
	end
	state.last_at = current

	local raw, provider = providers.detect(M.options())
	state.last = compute(raw, provider)
	return state.last
end

--- Non-blocking detection.  The callback always runs on the main loop.
---@param force boolean|nil
---@param callback fun(result: table)|nil
function M.detect_async(force, callback)
	local function finish(result)
		callback = callback or function() end
		vim.schedule(function()
			callback(result)
		end)
	end

	if state.override then
		state.last = {
			provider = "override",
			raw = state.override,
			layout = state.override,
			english = false,
		}
		finish(state.last)
		return
	end

	if not state.enabled then
		state.last = disabled_result("config")
		finish(state.last)
		return
	end

	if M.remote_disabled() then
		state.last = disabled_result("remote")
		finish(state.last)
		return
	end

	local current = now_ms()
	if not force and (current - state.last_at) < state.min_interval then
		finish(state.last)
		return
	end
	state.last_at = current

	if state.in_flight then
		if callback then
			state.pending[#state.pending + 1] = callback
		end
		return
	end

	state.in_flight = true
	local generation = state.generation + 1
	state.generation = generation
	state.request = generation

	providers.detect_async(M.options(), function(raw, provider, err)
		if generation ~= state.generation then
			if state.request == generation then
				state.in_flight = false
			end
			return
		end
		state.in_flight = false
		state.request = nil
		if err then
			state.last = compute(nil, nil)
		else
			state.last = compute(raw, provider)
		end

		local callbacks = state.pending
		state.pending = {}
		if callback then
			callbacks[#callbacks + 1] = callback
		end

		local result = state.last
		vim.schedule(function()
			for _, fn in ipairs(callbacks) do
				pcall(fn, result)
			end
		end)
	end)
end

--- Resets the throttle so the next call performs a real detection.
function M.invalidate()
	state.last_at = 0
	state.generation = state.generation + 1
end

return M
