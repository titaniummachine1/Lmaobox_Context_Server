-- Main entry point
local TestModule = require("TestModule")
local Utils = require("utils.helpers")

local Main = {}

function Main.Initialize()
    print("Main initialized")
    TestModule.doSomething()
    Utils.greet("World")
end

return Main
