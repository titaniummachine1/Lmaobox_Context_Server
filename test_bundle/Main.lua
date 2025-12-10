-- Main entry point
local TestModule = require("TestModule")

local Main = {}

function Main.Initialize()
    print("Main initialized")
    TestModule.doSomething()
end

return Main
