
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() <= 0.995, "lnxLib version is too old, please update it!")


local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer, WWeapon = lnxLib.TF2.WPlayer, lnxLib.TF2.WWeapon
local Helpers = lnxLib.TF2.Helpers
local Prediction = lnxLib.TF2.Prediction
local Fonts = lnxLib.UI.Fonts

local function Draw()
    local pLocal = entities.GetLocalPlayer()
    local predData = Prediction.Player(pLocal, 10, 0) -- player, time (ticks), strafe angle (0 disabled)
    local pLocalPath = predData.pos

    -- Draw lines between the predicted positions
    for i = 1, #pLocalPath - 1 do
        local pos1 = pLocalPath[i]
        local pos2 = pLocalPath[i + 1]

        local screenPos1 = client.WorldToScreen(pos1)
        local screenPos2 = client.WorldToScreen(pos2)

        if screenPos1 ~= nil and screenPos2 ~= nil then
            draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
        end
    end
end

--[[ Remove the menu when unloaded ]]--
local function OnUnload()                                -- Called when the script is unloaded
    UnloadLib() --unloading lualib
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

callbacks.Unregister("Unload", "MCT_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "MCT_Draw")                        -- Unregister the "Draw" callback

callbacks.Register("Draw", Draw)
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded