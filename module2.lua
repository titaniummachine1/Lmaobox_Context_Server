-- Module 2 for bundle testing
local module2 = {}

function module2.goodbye(name)
	return "Goodbye from module2, " .. name
end

function module2.divide(x, y)
	if y == 0 then
		error("Cannot divide by zero")
	end
	return x / y
end

return module2
