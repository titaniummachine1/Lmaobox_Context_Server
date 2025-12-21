-- Main.lua for bundle testing
local module1 = require("module1")
local module2 = require("module2")

local function main()
	print("Testing bundle functionality")

	-- Test module1
	local greeting = module1.hello("World")
	print(greeting)

	local result = module1.calculate(5, 3)
	print("Calculation result:", result)

	-- Test module2
	local farewell = module2.goodbye("World")
	print(farewell)

	local division = module2.divide(20, 4)
	print("Division result:", division)

	-- Test error handling
	local success, err = pcall(function()
		module2.divide(10, 0)
	end)

	if not success then
		print("Caught error:", err)
	end
end

main()
