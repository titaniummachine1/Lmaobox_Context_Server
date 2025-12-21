-- Test modern Lua 5.4+ syntax features

-- 1. Integer division operator
print("Integer division:", 10 // 3)

-- 2. Bitwise operators
local a = 10  -- Decimal instead of binary
local b = 15  -- Decimal instead of hex
print("Bitwise AND:", a & b)
print("Bitwise OR:", a | b)
print("Bitwise XOR:", a ~ b)
print("Left shift:", a << 2)
print("Right shift:", a >> 1)

-- 3. New string literals with \z
local longString = "This is a long string \z
that spans multiple \z
lines without newlines"
print(longString)

-- 4. Closures with proper syntax
local function createCounter()
    local count = 0
    return function()
        count = count + 1  -- Standard assignment
        return count
    end
end

local counter = createCounter()
print("Counter:", counter())
print("Counter:", counter())

-- 5. Table constructors with new syntax
local tbl = {
    [1] = "first",
    [2] = "second",
    ["key"] = "value"
}

-- 6. Local functions
local function fastFunc()
    -- This is a regular function
    local file = io.open("test.txt", "w")
    return file
end

-- 7. Pattern matching with new features
local str = "Hello123World"
local num = str:match("%d+")
print("Matched number:", num)

-- 8. Constants (as regular variables)
local PI = 3.14159
print("PI:", PI)

-- 9. Type annotations (conceptual)
---@type string
local name = "Test"

-- 10. Advanced table operations
local nested = {
    level1 = {
        level2 = {
            value = 42
        }
    }
}
print("Nested value:", nested.level1.level2.value)
