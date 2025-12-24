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
