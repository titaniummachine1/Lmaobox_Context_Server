-- Test file: Modern Lua 5.3+ syntax that Lmaobox runtime supports
-- This will fail validation with Lua 5.1 but works in Lmaobox

local function testBitwiseOperators()
	local a = 5
	local b = 3

	-- Bitwise AND (Lua 5.3+ required)
	local result_and = a & b

	-- Bitwise OR
	local result_or = a | b

	-- Bitwise XOR
	local result_xor = a ~ b

	-- Left shift
	local result_shift = a << 2

	return result_and, result_or, result_xor, result_shift
end

local function normalize(v)
	return v / v:Length()
end

return {
	testBitwiseOperators = testBitwiseOperators,
	normalize = normalize,
}
