
-- Unload the module if it's already loaded
if package.loaded["ImMenu"] then
    package.loaded["ImMenu"] = nil
end

-- Load the module
local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")

local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer, WWeapon = lnxLib.TF2.WPlayer, lnxLib.TF2.WWeapon
local Helpers = lnxLib.TF2.Helpers
local Prediction = lnxLib.TF2.Prediction
local Fonts = lnxLib.UI.Fonts
local Input = lnxLib.Utils.Input
local Notify = lnxLib.UI.Notify
local vHitbox = {Min = Vector3(-24, -24, 0), Max = Vector3(24, 24, 82) }
local fFalse = function () return false end

local function TraceSurface(pLocal)
    local pLocalPos = pLocal:GetAbsOrigin()
    local DownPos = pLocalPos - Vector3(0,0,72)
    local groundtrace = engine.TraceHull(pLocalPos, DownPos, vHitbox.Min, vHitbox.Max, MASK_PLAYERSOLID_BRUSHONLY, fFalse)
    print(groundtrace.contents)
end

local decelerationtime = 35 --ticks
local tick_interval = globals.TickInterval()

local counter = 0
--[[ Code needed to run 66 times a second ]]--
-- Predicts player position after set amount of ticks
---@param strafeAngle number
local function OnCreateMove(Cmd)
    local pLocal = entities.GetLocalPlayer()
    if not pLocal then return end
    tick_interval = globals.TickInterval()

    
    --[[if input.IsButtonDown(KEY_W) then
        counter = 0
    else
        if pLocal:EstimateAbsVelocity():Length() > 0 then
            counter = counter + 1
        end
        print(counter)
    end]]

    --TraceSurface(pLocal)
end


--[[ Unregister previous callbacks ]]--
callbacks.Unregister("CreateMove", "Research_CreateMove")            -- Unregister the "CreateMove" callback
--callbacks.Unregister("Draw", "MCT_Draw")                        -- Unregister the "Draw" callback
--[[ Register callbacks ]]--
callbacks.Register("CreateMove", "Research_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
--callbacks.Register("Draw", "MCT_Draw", doDraw)                               -- Register the "Draw" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded