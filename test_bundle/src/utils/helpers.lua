-- Utility helpers
local helpers = {}

function helpers.greet(name)
    print("Hello, " .. name .. "!")
end

function helpers.log(message)
    print("[LOG] " .. message)
end

return helpers

