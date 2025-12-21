-- Module 1 for bundle testing
local module1 = {}

function module1.hello(name)
	return "Hello from module1, " .. name
end

function module1.calculate(x, y)
	return x * y + 10
end

return module1
