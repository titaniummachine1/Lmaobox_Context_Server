--[[ Swing prediction for  Lmaobox  ]]--
--[[           REmastered           ]]--
--[[          --Authors--           ]]--
--[[        Titaniummachine1        ]]--

--#inicialization--------------------------------------------------------------------------------------------------

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")

local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer, WWeapon = lnxLib.TF2.WPlayer, lnxLib.TF2.WWeapon
local Helpers = lnxLib.TF2.Helpers
local Prediction = lnxLib.TF2.Prediction
local Fonts = lnxLib.UI.Fonts

local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")


local Menu = { -- this is the config that will be loaded every time u load the script

    Version = 0.1, -- dont touch this, this is just for managing the config version

    tabs = { -- dont touch this, this is just for managing the tabs in the menu
        Main = true,
        Advanced = false,
        Visuals = false,
    },

    Main = {
        Active = true,  --disable lua
        AimbotFOV = 360,
        Aimbot = true,
        Silent = true,
        ChargeControl = true,
        ChargeSensitivity = 50,
        CritRefill = true,
        InstantAttack = true,
        Keybind = key,
    },

    Advanced = {
        ChargeReach = false,
        TroldierAssist = false,
    },

    Visuals = {
        EnableVisuals = false,
    },
}

local function CreateCFG(folder_name, table)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.cfg")
    local file = io.open(filepath, "w")
    
    if file then
        local function serializeTable(tbl, level)
            level = level or 0
            local result = string.rep("    ", level) .. "{\n"
            for key, value in pairs(tbl) do
                result = result .. string.rep("    ", level + 1)
                if type(key) == "string" then
                    result = result .. '["' .. key .. '"] = '
                else
                    result = result .. "[" .. key .. "] = "
                end
                if type(value) == "table" then
                    result = result .. serializeTable(value, level + 1) .. ",\n"
                elseif type(value) == "string" then
                    result = result .. '"' .. value .. '",\n'
                else
                    result = result .. tostring(value) .. ",\n"
                end
            end
            result = result .. string.rep("    ", level) .. "}"
            return result
        end
        
        local serializedConfig = serializeTable(table)
        file:write(serializedConfig)
        file:close()
        printc( 255, 183, 0, 255, "["..os.date("%H:%M:%S").."] Saved Config to ".. tostring(fullPath))
    end
end

local function LoadCFG(folder_name)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.cfg")
    local file = io.open(filepath, "r")

    if file then
        local content = file:read("*a")
        file:close()
        local chunk, err = load("return " .. content)
        if chunk then
            printc( 0, 255, 140, 255, "["..os.date("%H:%M:%S").."] Loaded Config from ".. tostring(fullPath))
            return chunk()
        else
            CreateCFG([[LBOX Swing Prediction]], Menu)
            print("Error loading configuration:", err)
        end
    end
end

local status, loadedMenu = pcall(function() return assert(LoadCFG([[LBOX Swing Prediction]])) end) --auto laod config

if status then --ensure config is not causing errors
    if loadedMenu.Version == Menu.Version then
        Menu = loadedMenu
    else
        CreateCFG([[LBOX Swing Prediction]], Menu) --saving the config
    end
end

--inicialization- of variables------------------------------------------------------------------------------------
local pLocal = entities.GetLocalPlayer()


--helper-Functions------------------------------------------------------------------------------------------------


--Main-Functions--------------------------------------------------------------------------------------------------

local function OnCreateMove()
    --todo
end










--Visuals----------------------------------------------------------------------------------------------------------
local lastToggleTime = 0
local Lbox_Menu_Open = true
local toggleCooldown = 0.2  -- 200 milliseconds

local function toggleMenu()
    local currentTime = globals.RealTime()
    if currentTime - lastToggleTime >= toggleCooldown then
        Lbox_Menu_Open = not Lbox_Menu_Open  -- Toggle the state
        lastToggleTime = currentTime  -- Reset the last toggle time
    end
end

local function doDraw()
    --here
end

--Hooks ----------------------------------------------------------------------------------------------------------
--[[ Remove the menu when unloaded ]]--
local function OnUnloadASwingPrediction()                                -- Called when the script is unloaded
    UnloadLib() --unloading lualib
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
    CreateCFG([[LBOX Swing Prediction]], Menu) --saving the config
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("CreateMove", "ASwingPrediction_CreateMove")            -- Unregister the "CreateMove" callback
callbacks.Unregister("Unload", "ASwingPrediction_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "ASwingPrediction_Draw")                        -- Unregister the "Draw" callback
--[[ Register callbacks ]]--
callbacks.Register("CreateMove", "ASwingPrediction_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
callbacks.Register("Unload", "ASwingPrediction_Unload", OnUnloadASwingPrediction)                         -- Register the "Unload" callback
callbacks.Register("Draw", "ASwingPrediction_Draw", doDraw)                               -- Register the "Draw" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded