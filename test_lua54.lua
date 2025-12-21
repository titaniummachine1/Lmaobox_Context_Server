-- Test file for Lua validation
-- Note: Bitwise operators require Lua 5.3+, but Lmaobox runtime supports them
-- This version uses Lua 5.1 compatible syntax for testing

local function test_bitwise()
	local a = 5
	local b = 3

	-- Simulate bitwise operations (would use & | ~ << in Lua 5.4+)
	local result_and = bit.band(a, b) -- Using bit library for 5.1
	local result_or = bit.bor(a, b)
	local result_xor = bit.bxor(a, b)
	local result_shift = bit.lshift(a, 2)

	return result_and, result_or, result_xor, result_shift
end

local function normalize(v)
	return v / v:Length()
end

return {
	test_bitwise = test_bitwise,
	normalize = normalize,
}
