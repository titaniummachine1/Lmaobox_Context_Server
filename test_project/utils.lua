-- Utils module for testing
local utils = {}

function utils.greet(name)
	print("Hello, " .. name .. "!")
end

function utils.log(message)
	print("[LOG] " .. message)
end

return utils
