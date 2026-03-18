local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Test Main.lua for bundle validation
local utils = require("utils")
local math_helpers = require("math.helpers")

function main()
	print("Testing bundle functionality")
	utils.greet("Lmaobox")

	local result = math_helpers.add(5, 3)
	print("5 + 3 = " .. result)

	-- Test some TF2 constants
	if TF2_Scout then
		print("TF2_Scout constant available: " .. TF2_Scout)
	end
end

-- Call main function
main()

end)
__bundle_register("math.helpers", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Math helpers module for testing
local helpers = {}

function helpers.add(a, b)
	return a + b
end

function helpers.multiply(a, b)
	return a * b
end

function helpers.clamp(value, min_val, max_val)
	if value < min_val then
		return min_val
	elseif value > max_val then
		return max_val
	else
		return value
	end
end

return helpers

end)
__bundle_register("utils", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Utils module for testing
local utils = {}

function utils.greet(name)
	print("Hello, " .. name .. "!")
end

function utils.log(message)
	print("[LOG] " .. message)
end

return utils

end)
return __bundle_require("__root")