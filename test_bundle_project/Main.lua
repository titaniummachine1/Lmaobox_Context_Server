local utils = require("utils")

local function init()
	print("Main initialized")
	utils.doSomething()
end

return { init = init }
