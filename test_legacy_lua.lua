-- This file uses Lua 5.1 compatible syntax
-- Note: Lmaobox runtime supports modern syntax even if Lua 5.1 doesn't

local bit = require("bit")

local function legacySyntax()
	-- Use bit library instead of bitwise operators
	local flags = bit.bor(0x01, 0x02)
	local mask = bit.band(flags, 0x01)

	-- Regular division instead of integer division
	local result = math.floor(10 / 3)

	-- String length instead of utf8
	local len = string.len("hello")

	return flags, mask, result, len
end

-- Test the function
local a, b, c, d = legacySyntax()
print("Legacy Lua syntax test passed")
