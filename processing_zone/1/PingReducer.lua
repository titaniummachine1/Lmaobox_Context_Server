--[[
    Ping Reducer for Lmaobox
    Author: LNX (github.com/lnx00)
]]

local menuLoaded, MenuLib = pcall(require, "Menu")
assert(menuLoaded, "MenuLib not found, please install it!")
assert(MenuLib.Version >= 1.43, "MenuLib version is too old, please update it!")

--[[ Menu ]]
local Menu = MenuLib.Create("Swing prediction", MenuFlags.AutoSize)
Menu.Style.TitleBg = { 10, 200, 100, 255 }
Menu.Style.Outline = true

local Options = {
    Enabled = Menu:AddComponent(MenuLib.Checkbox("Enable", true)),
}

local function OnCreateMove(pCmd)
    local players     = entities.FindByClass("CTFPlayer")  -- Create a table of all players in the game
    local LocalPlayer = entities.GetLocalPlayer()
    local is_melee    = pWeapon:IsMeleeWeapon()
    if not Options.Enabled:GetValue() then return end
    for i, vPlayer in pairs(players) do
        local distVector = LocalPlayer:GetAbsOrigin() - vPlayer:GetAbsOrigin()
        local distance = distVector:Length()
        local speedPerTick = distance - previousDistance
            local tickRate = 66 -- This is the tick rate of the game
            
            closingSpeed = (speedPerTick * tickRate)
            relativespeed = closingSpeed * -1
            previousDistance = distance
            if relativespeed ~= 0 then
                relativeSpeed = math.floor(relativespeed)
            end
            estime = distance / relativespeed
            -- estimated hit time

            if estime <= 0.26 and relativespeed > 0 then
                pCmd:SetButtons(pCmd:GetButtons() | IN_ATTACK) -- attack
            end
    end
end

local function OnUnload()
    MenuLib.RemoveMenu(Menu)

    client.Command('play "ui/buttonclickrelease"', true)
end

callbacks.Unregister("CreateMove", "PR_CreateMove")
callbacks.Unregister("Unload", "PR_Unload")

callbacks.Register("CreateMove", "PR_CreateMove", OnCreateMove)
callbacks.Register("Unload", "PR_Unload", OnUnload)

client.Command('play "ui/buttonclick"', true)