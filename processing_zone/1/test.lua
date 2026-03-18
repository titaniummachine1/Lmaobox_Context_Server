--[[Initialize a counter and set a maximum count value
local countUp = 0
local countUpMax = 14 -- Time to zoom in

-- Function that gets called on each game tick
local function OnCreateMove(cmd)
    -- Get the local player entity
    local pLocal = entities.GetLocalPlayer()

    -- If the local player entity doesn't exist, exit the function
    if not pLocal then return end

    -- Check if the local player is zoomed in
    local scoped = pLocal:InCond(TFCond_Zoomed)

    -- If the player is not zoomed in, reset the counter
    if not scoped then
        countUp = 0
    end

    -- If the counter has reached the maximum count, print the scoped status
    if countUp >= countUpMax then
        print(scoped)
    else
        -- If the counter hasn't reached the maximum count, set scoped to false
        scoped = false
    end

    -- Increment the counter
    countUp = countUp + 1
end]]

-- Event hook function
local function event_hook(ev)
    print(ev:GetName())
end

callbacks.Unregister("FireGameEvent", "unique_event_hook")                 -- unregister the "FireGameEvent" callback
callbacks.Register("FireGameEvent", "unique_event_hook", event_hook)         -- register the "FireGameEvent" callback

--[[ Callbacks ]]
--Unregister previous callbacks--
--callbacks.Unregister("CreateMove", "HvhTools")                     -- unregister the "CreateMove" callback
--Register callbacks--
--callbacks.Register("CreateMove", "HvhTools", OnCreateMove)        -- register the "CreateMove" callback

--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded