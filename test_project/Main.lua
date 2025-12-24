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
