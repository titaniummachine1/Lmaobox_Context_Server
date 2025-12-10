-- Test module
local Utils = require("utils.helpers")

local TestModule = {}

function TestModule.doSomething()
    print("TestModule doing something")
    Utils.log("TestModule executed")
end

return TestModule
