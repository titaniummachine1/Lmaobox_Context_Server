--[[                                ]]--
--[[    Prefabscript   for Lmaobox  ]]--
--[[      (Modded misc-tools)       ]]--
--[[          --Authors--           ]]--
--[[           Terminator           ]]--
--[[  (github.com/titaniummachine1  ]]--
--[[                                ]]--
--[[    credit to thoose people     ]]--
--[[      LNX (github.com/lnx00)    ]]--
--[[             Muqa1              ]]--
--[[   https://github.com/Muqa1     ]]--
--[[         SylveonBottle          ]]--
--[[recomended config: 23d740e39153 ]]--
---@type boolean, LNXlib
local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 0.94, "LNXlib version is too old, please update it!")

local menu = MenuLib.Create("prefab menu", MenuFlags.AutoSize) -- load menu
menu.Style.TitleBg = { 205, 95, 50, 255 } -- Title Background Color (Flame Pea)
menu.Style.Outline = true                 -- Outline around the menu

assert(menuLoaded, "MenuLib not found, please install it!")                       -- If not found, throw error
assert(MenuLib.Version >= 1.44, "MenuLib version is too old, please update it!")  -- If version is too old, throw error

local autoswitch_options = {
    ["safe-mode"] = true,
    ["Self Defence"] = true,
    ["Auto_Combo"] = true,
    ["Auto-Crit-Refill"] = true,
    ["allow-manual"] = true,
    ["AutoDT"] = true,
}

--[[ Menu ]]--

-- theese are variable changing parts of basic lua menu you may get the input from theese buttons later in code
-- here is link for menu example https://github.com/lnx00/Lmaobox-LUA/blob/main/MenuLib/Menu-Example.lua

local mWswitchoptions   = menu:AddComponent(MenuLib.MultiCombo("^Settings",             autoswitch_options, ItemFlags.FullWidth))
menu:AddComponent(MenuLib.Button("Disable Weapon Sway", function() -- Disable Weapon Sway (Executes commands)
    client.SetConVar("cl_vWeapon_sway_interp",              0)             -- Set cl_vWeapon_sway_interp to 0
    client.SetConVar("cl_jiggle_bone_framerate_cutoff", 0)             -- Set cl_jiggle_bone_framerate_cutoff to 0
    client.SetConVar("cl_bobcycle",                     10000)         -- Set cl_bobcycle to 10000
    client.SetConVar("sv_cheats", 1)                                   -- change convar with menu buttons
    client.SetConVar("mp_disable_respawn_times", 1)
    client.SetConVar("mp_respawnwavetime", -1)
end, ItemFlags.FullWidth))


local mdistance   = menu:AddComponent(MenuLib.Slider("distance", -100, 1000, 500)) -- example slider for basic menu.
local mcheckbox     = menu:AddComponent(MenuLib.Checkbox("checkbox", true))        -- basic check box 
local mLegJitter        = menu:AddComponent(MenuLib.Checkbox("Leg Jitter", false)) -- Leg Jitter and movement forcement example
-- Check the menu version to prevent errors due to changes in the library

-- Add a checkbox
local checkbox = menu:AddComponent(MenuLib.Checkbox("Enable Feature", true))

-- Add a button with callback that fills the width of the window
function OnButtonPress() 
    print("Button pressed!")
end
menu:AddComponent(MenuLib.Button("Press Me!", OnButtonPress, ItemFlags.FullWidth))

-- Add a slider with minimum and maximum
menu:AddComponent(MenuLib.Slider("Text Size", 20, 100, 60))
menu:AddComponent(MenuLib.Seperator())

-- Add a textbox
local textBox = menu:AddComponent(MenuLib.Textbox("Write something..."))
menu:AddComponent(MenuLib.Seperator())

-- Add a combobox
local itemCombo = {
    "Label",
    "Checkbox"
}
local combo = menu:AddComponent(MenuLib.Combo("Combo", itemCombo))

-- Add a button to add the previously selected element
function AddElement()
    if combo.Selected == "Label" then
        menu:AddComponent(MenuLib.Label("You wrote: " .. textBox:GetValue()))
    elseif combo.Selected == "Checkbox" then
        menu:AddComponent(MenuLib.Checkbox("This is a checkbox.", checkbox:GetValue()))
    end
end
menu:AddComponent(MenuLib.Button("Add Element!", AddElement))

-- Add a multi combobox
local multiCombo = {
    ["Head"] = true,
    ["Body"] = false,
    ["Legs"] = false
}
menu:AddComponent(MenuLib.MultiCombo("Targets", multiCombo))

-- Main script body
-- pCmd allows to send commands to game or force character to walk in certan directions.(yes you can do it)
local function OnCreateMove(pCmd)                    -- Everything within this function will run 66 times a second
    ResetTempOptions()                               -- Immediately reset "TempOptions"
    local pLocal = entities.GetLocalPlayer()         -- Immediately set "pLocal" to the local player (entities.GetLocalPlayer)
    if not pLocal then return end                    -- Immediately check if the local player exists. If it doesn't, return.
    local vVelocity  = pLocal:EstimateAbsVelocity()  -- Immediately set "vVelocity" to the local player's absolute velocity (this is used for any code that needs to know the local player's velocity)
    local cmdButtons = pCmd:GetButtons()             -- Immediately set "cmdButtons" to the local player's buttons (this is used for any code that needs to know what buttons we are pressing)

    if mLegJitter:GetValue() == true then                                -- If Leg Jitter is enabled,
        if (pCmd.forwardmove == 0) and (pCmd.sidemove == 0)              -- Check if we are pressing WASD
                                   and (vVelocity:Length2D() < 10) then  -- Check if we not currently moving 
            if pCmd.command_number % 2 == 0 then                         -- Check if the command number is even. (Potentially inconsistent, but it works).
                pCmd:SetSideMove(9)                                   -- Cycle between moving left and right
                --engine.RandomSeed( 1 )
            else
                pCmd:SetSideMove(-9)        -- pCmd:setsideMove and pCmd:setforwardsMove can make your character move
                --engine.RandomSeed( -1 )
            end
        end
    end

    --[[ Retry when low hp ]]-- (Rconnects when your hp is below "mRetryHP" (set in the menu) in order to prevent being killed))
    if mRetryLowHPValue:GetValue() >= 1 then                                                    -- If Retry when low hp is enabled
        if (pLocal:IsAlive()) and (pLocal:GetHealth() > 0                                      -- Check if we are alive and have health
                              and (pLocal:GetHealth() / pLocal:GetMaxHealth() * 100) <= mRetryLowHPValue:GetValue()) then    -- Check if our health is less than "mRetryLowHPValue" (set in the menu)
            client.Command("retry", true)                                                      -- Reconnect to the server
        end
    end

    -- example how to get input from dropdown menu
    local automelee = mWswitchoptions:IsSelected("Self Defence")


end


local function OnUnload()                                -- Called when the script is unloaded
    MenuLib.RemoveMenu(menu)                             -- Remove the menu
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

callbacks.Unregister("CreateMove", "MCT_CreateMove")            -- Unregister the "CreateMove" callback
callbacks.Unregister("Unload", "MCT_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "MCT_Draw")                        -- Unregister the "Draw" callback
callbacks.Unregister("CreateMove", "LNX_IF_UserCmd")

callbacks.Register("CreateMove", "MCT_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("Draw", "MCT_Draw", doDraw)                               -- Register the "Draw" callback
callbacks.Register("CreateMove", "LNX_IF_UserCmd", OnUserCmd)
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded