-- Simple example with dependency
local math_helpers = require("math_helpers")

print("Testing bundle with dependency...")
local result = math_helpers.add(2, 2)
print("2 + 2 = " .. result)

local M = {}

function M.run()
    print("Main.run() executed")
end

return M
