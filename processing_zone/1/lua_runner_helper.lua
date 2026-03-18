-- lua_runner_helper.lua
-- Run this inside Lmaobox to enable external Lua execution
-- Place in your Lmaobox Lua folder and load it

local CONFIG = {
	server_url = "http://127.0.0.1:27182",
	poll_interval = 0.1, -- seconds between polls
	max_output_lines = 100,
	enabled = true,
}

-- State
local state = {
	current_script_id = nil,
	callbacks_registered = {},
	output_buffer = {},
	error_count = 0,
	last_poll = 0,
}

-- Capture all print output
local original_print = print
local function captured_print(...)
	local args = { ... }
	local line = table.concat(args, "\t")
	table.insert(state.output_buffer, line)

	-- Send to external tool
	http.Post(
		CONFIG.server_url .. "/output",
		string.format('{"line": %q}', line),
		function() end, -- success
		function() end -- failure
	)

	-- Also call original
	original_print(...)
end

-- Override global print
print = captured_print

-- Error handler wrapper
local function wrap_with_error_handler(func, source_info)
	return function(...)
		local success, result = pcall(func, ...)
		if not success then
			local error_info = {
				message = tostring(result),
				traceback = source_info or "unknown",
				timestamp = globals.RealTime(),
			}

			-- Send error to external tool
			http.Post(
				CONFIG.server_url .. "/error",
				string.format('{"message": %q, "traceback": %q}', error_info.message, error_info.traceback),
				function() end,
				function() end
			)

			printc(255, 100, 100, 255, "[LuaRunner Error] " .. error_info.message)
			state.error_count = state.error_count + 1
		end
		return success, result
	end
end

-- Track callback registrations
local original_register = callbacks.Register
local function tracked_register(callback_type, name, func)
	-- Wrap with error handler
	local wrapped = wrap_with_error_handler(func, callback_type .. ":" .. name)

	-- Store registration info
	table.insert(state.callbacks_registered, {
		type = callback_type,
		name = name,
		registered_at = globals.RealTime(),
	})

	-- Report to external tool
	http.Post(
		CONFIG.server_url .. "/callbacks",
		string.format('{"callbacks": [{"type": %q, "name": %q}]}', callback_type, name),
		function() end,
		function() end
	)

	return original_register(callback_type, name, wrapped)
end

callbacks.Register = tracked_register

-- Execute script with full error capture
local function execute_script(script_code)
	state.error_count = 0
	state.output_buffer = {}
	state.callbacks_registered = {}

	printc(100, 255, 100, 255, "[LuaRunner] Executing external script...")

	local start_time = globals.RealTime()

	-- Compile
	local func, compile_err = load(script_code, "[external]")
	if not func then
		local error_msg = "Compile error: " .. tostring(compile_err)
		printc(255, 100, 100, 255, "[LuaRunner] " .. error_msg)

		http.Post(
			CONFIG.server_url .. "/error",
			string.format('{"message": %q, "traceback": "compile"}', error_msg),
			function() end,
			function() end
		)
		return false
	end

	-- Execute with error protection
	local exec_success, exec_result = pcall(func)

	local duration = (globals.RealTime() - start_time) * 1000

	if not exec_success then
		local error_msg = "Runtime error: " .. tostring(exec_result)
		printc(255, 100, 100, 255, "[LuaRunner] " .. error_msg)

		http.Post(
			CONFIG.server_url .. "/error",
			string.format('{"message": %q, "traceback": "runtime"}', error_msg),
			function() end,
			function() end
		)
		return false
	end

	-- Report success
	http.Post(CONFIG.server_url .. "/completed", "{}", function() end, function() end)

	printc(
		100,
		255,
		100,
		255,
		string.format("[LuaRunner] Completed in %.1fms (%d errors)", duration, state.error_count)
	)

	return true
end

-- Main poll loop
local function poll_for_scripts()
	if not CONFIG.enabled then
		return
	end

	local now = globals.RealTime()
	if now - state.last_poll < CONFIG.poll_interval then
		return
	end
	state.last_poll = now

	http.Get(CONFIG.server_url .. "/getscript", function(body)
		if body and body ~= "" then
			execute_script(body)
		end
	end, function(err)
		-- Silently fail - server might not be running
	end)
end

-- Register poll callback
callbacks.Unregister("Draw", "LuaRunnerPoll")
callbacks.Register("Draw", "LuaRunnerPoll", poll_for_scripts)

-- Signal startup
printc(100, 200, 255, 255, "[LuaRunner] Helper loaded. Polling " .. CONFIG.server_url)
printc(100, 200, 255, 255, "[LuaRunner] Ensure external tool is running before executing scripts.")

-- Export API for other scripts
_G.LuaRunner = {
	execute = execute_script,
	get_state = function()
		return state
	end,
	set_enabled = function(e)
		CONFIG.enabled = e
	end,
	is_enabled = function()
		return CONFIG.enabled
	end,
}
