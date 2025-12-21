-- Basic Lua syntax test
local function greet(name)
	return "Hello, " .. name .. "!"
end

local function calculateSum(a, b)
	return a + b
end

-- Test the functions
local message = greet("World")
local result = calculateSum(5, 10)

print(message)
print("Sum:", result)

-- Table operations
local person = {
	name = "John",
	age = 30,
	hobbies = { "reading", "gaming", "coding" },
}

for i, hobby in ipairs(person.hobbies) do
	print("Hobby " .. i .. ":", hobby)
end
