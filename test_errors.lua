-- File with intentional syntax errors to test luacheck error detection

-- Error 1: Missing end for function
local function brokenFunction()
    if true then
        print("This function is missing an end")

-- Error 2: Invalid operator
local result = 5 ++ 3

-- Error 3: Mismatched parentheses
local value = (10 + 20

-- Error 4: Invalid variable name
local 123invalid = "test"

-- Error 5: Missing comma in table
local table = {
    key1 = "value1"
    key2 = "value2"
}

-- Error 6: Unexpected symbol
print("Hello" @ "World")

-- Error 7: Incomplete string
local incomplete = "This string never ends

-- Error 8: Invalid assignment
if true then
    local x = 1
end
x = 2  -- x is out of scope
