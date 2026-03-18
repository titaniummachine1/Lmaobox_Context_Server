--[[
    Priority Adder for Lmaobox
    Author: LNX (github.com/lnx00)
]]

local Options = {
    Priority = 10,              -- The priority for the new entries
    Override = false,           -- Override existing priorities
    File = "playerlist.txt"     -- The file with the priorities
}

Options.Priority = 10 -- set the priority of all players to 10

local function ReadFile(path)
    local file = io.open(path, "rb") -- r read mode and b binary mode
    if not file then return nil end
    local content = file:read "*a" -- *a or *all reads the whole file
    file:close()
    return content
end

local playerList = ReadFile(Options.File)
for line in playerList:gmatch("[^\r\n]+") do
    playerlist.SetPriority(line, Options.Priority) -- set the player's priority to 10
end






--[[
local function changePriority() -- define a function to change the priority of all players to 10
    local players = getPlayers() -- get a table of all player objects on the server
  
    for _, player in pairs(players) do -- iterate through the table of player objects
      player:setPriority(10) -- set the player's priority to 10
    end
  end
  
  callbacks.Unregister("Draw", changePriority) -- unregister the callback-- unregister the callback
  
  callbacks.Register("Draw", changePriority, active == true) -- register the callback and only execute it when `active` is `true`
--]]




