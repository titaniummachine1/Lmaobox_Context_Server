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
--local Input = lnxLib.Utils.Input
local Notify = lnxLib.UI.Notify

local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")

--inicialization- of variables------------------------------------------------------------------------------------
local pLocal = entities.GetLocalPlayer()
local vHitbox = { Vector3(-24, -24, 0), Vector3(24, 24, 82) }

    -- Contains pairs of keys and their names
    ---@type table<integer, string>
    local KeyNames = {
        [KEY_SEMICOLON] = "SEMICOLON",
        [KEY_APOSTROPHE] = "APOSTROPHE",
        [KEY_BACKQUOTE] = "BACKQUOTE",
        [KEY_COMMA] = "COMMA",
        [KEY_PERIOD] = "PERIOD",
        [KEY_SLASH] = "SLASH",
        [KEY_BACKSLASH] = "BACKSLASH",
        [KEY_MINUS] = "MINUS",
        [KEY_EQUAL] = "EQUAL",
        [KEY_ENTER] = "ENTER",
        [KEY_SPACE] = "SPACE",
        [KEY_BACKSPACE] = "BACKSPACE",
        [KEY_TAB] = "TAB",
        [KEY_CAPSLOCK] = "CAPSLOCK",
        [KEY_NUMLOCK] = "NUMLOCK",
        [KEY_ESCAPE] = "ESCAPE",
        [KEY_SCROLLLOCK] = "SCROLLLOCK",
        [KEY_INSERT] = "INSERT",
        [KEY_DELETE] = "DELETE",
        [KEY_HOME] = "HOME",
        [KEY_END] = "END",
        [KEY_PAGEUP] = "PAGEUP",
        [KEY_PAGEDOWN] = "PAGEDOWN",
        [KEY_BREAK] = "BREAK",
        [KEY_LSHIFT] = "LSHIFT",
        [KEY_RSHIFT] = "RSHIFT",
        [KEY_LALT] = "LALT",
        [KEY_RALT] = "RALT",
        [KEY_LCONTROL] = "LCONTROL",
        [KEY_RCONTROL] = "RCONTROL",
        [KEY_UP] = "UP",
        [KEY_LEFT] = "LEFT",
        [KEY_DOWN] = "DOWN",
        [KEY_RIGHT] = "RIGHT",
    }

    -- Contains pairs of keys and their values
    ---@type table<integer, string>
    local KeyValues = {
        [KEY_LBRACKET] = "[",
        [KEY_RBRACKET] = "]",
        [KEY_SEMICOLON] = ";",
        [KEY_APOSTROPHE] = "'",
        [KEY_BACKQUOTE] = "`",
        [KEY_COMMA] = ",",
        [KEY_PERIOD] = ".",
        [KEY_SLASH] = "/",
        [KEY_BACKSLASH] = "\\",
        [KEY_MINUS] = "-",
        [KEY_EQUAL] = "=",
        [KEY_SPACE] = " ",
    }

local Menu = { -- this is the config that will be loaded every time u load the script
    Main = {
        Active = true,  --disable lua
        Insta_Hit = true,
        Keybind = "Always_On",
        keybind_Idx = 0,
        Is_Listening_For_Key = false,
    },
}

local Lua__fullPath = GetScriptName()
local Lua__fileName = Lua__fullPath:match("\\([^\\]-)$"):gsub("%.lua$", "")

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
            CreateCFG(string.format([[Lua %s]], Lua__fileName), Menu) --saving the config
            print("Error loading configuration:", err)
        end
    end
end

local status, loadedMenu = pcall(function() return assert(LoadCFG(string.format([[Lua %s]], Lua__fileName))) end) --auto load config

if status then --ensure config is not causing errors
    local allFunctionsExist = true
    for k, v in pairs(Menu) do
        if type(v) == 'function' then
            if not loadedMenu[k] or type(loadedMenu[k]) ~= 'function' then
                allFunctionsExist = false
                break
            end
        end
    end

    if allFunctionsExist then
        Menu = loadedMenu
    else
        CreateCFG(string.format([[Lua %s]], Lua__fileName), Menu) --saving the config
    end
end

--helper-Functions------------------------------------------------------------------------------------------------

    --[[
        Input Utils
    ]]

    ---@class Input
    local Input = {}

    -- Fill the tables
    local function D(x) return x, x end
    for i = 1, 10 do KeyNames[i], KeyValues[i] = D(tostring(i - 1)) end -- 0 - 9
    for i = 11, 36 do KeyNames[i], KeyValues[i] = D(string.char(i + 54)) end -- A - Z
    for i = 37, 46 do KeyNames[i], KeyValues[i] = "KP_" .. (i - 37), tostring(i - 37) end -- KP_0 - KP_9
    for i = 92, 103 do KeyNames[i] = "F" .. (i - 91) end
    for i = 1, 10 do local mouseButtonName = "MOUSE_" .. i KeyNames[MOUSE_FIRST + i - 1] = mouseButtonName KeyValues[MOUSE_FIRST + i - 1] = "Mouse Button " .. i end

    -- Returns the name of a keycode
    ---@param key integer
    ---@return string|nil
    local function GetKeyName(key)
        return KeyNames[key]
    end

    -- Returns the string value of a keycode
    ---@param key integer
    ---@return string|nil
    local function KeyToChar(key)
        return KeyValues[key]
    end

    -- Returns the keycode of a string value
    ---@param char string
    ---@return integer|nil
    local function CharToKey(char)
        return table.find(KeyValues, string.upper(char))
    end

    -- Update the GetPressedKey function to check for these additional mouse buttons
    local function GetPressedKey()
        for i = KEY_FIRST, KEY_LAST do
            if input.IsButtonDown(i) then return i end
        end

        -- Check for standard mouse buttons
        if input.IsButtonDown(MOUSE_LEFT) then return MOUSE_LEFT end
        if input.IsButtonDown(MOUSE_RIGHT) then return MOUSE_RIGHT end
        if input.IsButtonDown(MOUSE_MIDDLE) then return MOUSE_MIDDLE end

        -- Check for additional mouse buttons
        for i = 1, 10 do
            if input.IsButtonDown(MOUSE_FIRST + i - 1) then return MOUSE_FIRST + i - 1 end
        end

        return nil
    end

    -- Define a table for centralized storage
    local dataStorage = {}

    -- Function to set or get values from the storage
    function DataStorage(key, value)
        -- If a value is provided, set it
        if value ~= nil then
            dataStorage[key] = value
        else
            -- If no value is provided, return the stored value
            return dataStorage[key]
        end
    end

    -- [WIP] Predict the position of a player
    ---@param player WPlayer
    ---@param t integer
    ---@param d number?
    ---@param shouldHitEntity fun(entity: WEntity, contentsMask: integer): boolean?
    ---@return { pos : Vector3[], vel: Vector3[], onGround: boolean[] }?
    local function PredictPlayer(player, t, d, pHitbox, shouldHitEntity)
        local gravity = client.GetConVar("sv_gravity")
        local stepSize = player:GetPropFloat("localdata", "m_flStepSize")
        if not gravity or not stepSize then return nil end

        local vUp = Vector3(0, 0, 1)
        local vStep = Vector3(0, 0, stepSize)
        shouldHitEntity = shouldHitEntity or fFalse
        local pFlags = player:GetPropInt("m_fFlags")
        -- Add the current record
        local _out = {
            pos = { [0] = player:GetAbsOrigin() },
            vel = { [0] = player:EstimateAbsVelocity() },
            onGround = { [0] = player:IsOnGround() }
        }

        -- Perform the prediction
        for i = 1, t do
            local lastP, lastV, lastG = _out.pos[i - 1], _out.vel[i - 1], _out.onGround[i - 1]

            local pos = lastP + lastV * globals.TickInterval()
            local vel = lastV
            local onGround = lastG

            -- Apply deviation
            if d then
                local ang = vel:Angles()
                ang.y = ang.y + d
                vel = ang:Forward() * vel:Length()
            end

            --[[ Forward collision ]]

            local wallTrace = engine.TraceHull(lastP + vStep, pos + vStep, pHitbox[1], pHitbox[2], MASK_PLAYERSOLID, shouldHitEntity)
            --DrawLine(last.p + vStep, pos + vStep)
            if wallTrace.fraction < 1 then
                -- We'll collide
                local normal = wallTrace.plane
                local angle = math.deg(math.acos(normal:Dot(vUp)))

                -- Check the wall angle
                if angle > 55 then
                    -- The wall is too steep, we'll collide
                    local dot = vel:Dot(normal)
                    vel = vel - normal * dot
                end

                pos.x, pos.y = wallTrace.endpos.x, wallTrace.endpos.y
            end

            --[[ Ground collision ]]

            -- Don't step down if we're in-air
            local downStep = vStep
            if not onGround then downStep = Vector3() end

            local groundTrace = engine.TraceHull(pos + vStep, pos - downStep, pHitbox[1], pHitbox[2], MASK_PLAYERSOLID, shouldHitEntity)
            --DrawLine(pos + vStep, pos - downStep)
            if groundTrace.fraction < 1 then
                -- We'll hit the ground
                local normal = groundTrace.plane
                local angle = math.deg(math.acos(normal:Dot(vUp)))

                -- Check the ground angle
                if angle < 45 then
                    pos = groundTrace.endpos
                    onGround = true
                elseif angle < 55 then
                    -- The ground is too steep, we'll slide [TODO]
                    vel.x, vel.y, vel.z = 0, 0, 0
                    onGround = false
                else
                    -- The ground is too steep, we'll collide
                    local dot = vel:Dot(normal)
                    vel = vel - normal * dot
                    onGround = true
                end

                -- Don't apply gravity if we're on the ground
                if onGround then vel.z = 0 end
            else
                -- We're in the air
                onGround = false
            end

            -- Gravity
            if not onGround then
                vel.z = vel.z - gravity * globals.TickInterval()
            end

            -- Add the prediction record
            _out.pos[i], _out.vel[i], _out.onGround[i] = pos, vel, onGround
        end

        return _out
    end

--Main-Functions--------------------------------------------------------------------------------------------------

-- Function to generate directions for trace hull
local function getTraceDirections()
    return {
        Vector3(-0.04, 0, 0),
        Vector3(0.04, 0, 0),
        Vector3(0, -0.04, 0),
        Vector3(0, 0.04, 0)
    }
end

-- Function to find the wall direction using trace hull
local function findWallDirection(startPos)
    local directions = getTraceDirections()
    local closestFraction = 1
    local wallNormal = nil

    for _, dir in ipairs(directions) do
        local endPos = Vector3(startPos.x + dir.x, startPos.y + dir.y, startPos.z + dir.z)
        local traceResult = engine.TraceHull(startPos, endPos, vHitbox[1], vHitbox[2], MASK_PLAYERSOLID_BRUSHONLY)
        if traceResult.fraction < closestFraction then
            closestFraction = traceResult.fraction
            wallNormal = traceResult.plane.normal
        end
    end

    if wallNormal then
        -- Calculate the most direct angle towards the wall based on wallNormal
        local directAngle = -- Complete this calculation based on your game's mechanics
        return directAngle
    else
        return nil -- No wall detected
    end
end

-- Example usage
local startPosition = Vector3(0, 0, 0) -- Replace with the actual start position
local directAngleTowardsWall = findWallDirection(startPosition)

local function OnCreateMove(pCmd)
    -- Retrieve the local player entity
    pLocal = entities.GetLocalPlayer()
    -- Check if the local player is valid and alive
    if not pLocal or not pLocal:IsAlive() then
        return -- Skip further processing if the local player is invalid or dead
    end


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

local bindTimer2 = 0
local bindDelay1 = 0.15  -- Delay of 0.2 seconds


local function doDraw()

    ---Menu----------------------------------------------------------------------------------------------

    -- Inside your OnCreateMove or similar function where you check for input
    if input.IsButtonDown(KEY_INSERT) then  -- Replace 72 with the actual key code for the button you want to use
        toggleMenu()
    end

    if Lbox_Menu_Open == true and ImMenu and ImMenu.Begin("Auto Wallstuck", true) then
                ImMenu.BeginFrame(1)
                    Menu.Main.Active = ImMenu.Checkbox("Enable", Menu.Main.Active)
                ImMenu.EndFrame()
    
                ImMenu.BeginFrame(1)
                    ImMenu.Text("Keybind: ")

                    if Menu.Main.Keybind ~= "Press The Key" and ImMenu.Button(Menu.Main.Keybind) then
                        Menu.Main.Is_Listening_For_Key = not Menu.Main.Is_Listening_For_Key
                        if Menu.Main.Is_Listening_For_Key then
                            bindTimer2 = os.clock() + bindDelay1
                            Menu.Main.Keybind = "Press The Key"
                        else
                            Menu.Main.Keybind = "Always On"
                        end
                    elseif Menu.Main.Keybind == "Press The Key" then
                        ImMenu.Text("Press the key")
                    end

                    if Menu.Main.Is_Listening_For_Key then
                        if os.clock() >= bindTimer then

                            local pressedKey = GetPressedKey()
                            if pressedKey then
                                if pressedKey == KEY_ESCAPE then
                                    -- Reset keybind if the Escape key is pressed
                                    Menu.Main.Keybind = "Always On"
                                    Menu.MainIs_Listening_For_Key = false
                                else
                                    -- Update keybind with the pressed key
                                    Menu.Main.Keybind = string.gsub(GetKeyName(pressedKey) or "", "Key_", "")
                                    Menu.Main.keybind_Idx = pressedKey
                                    Notify.Simple("Keybind Success", "Bound Key: " .. Menu.Main.Keybind, 2)
                                    Menu.Main.Is_Listening_For_Key = false
                                end
                            end
                        end
                    end

                    ::continue::
                ImMenu.EndFrame()
        ImMenu.End()
    end
end

--Hooks ----------------------------------------------------------------------------------------------------------
--[[ Remove the menu when unloaded ]]--
local function OnUnload()                                -- Called when the script is unloaded
    CreateCFG(string.format([[Lua %s]], Lua__fileName), Menu) --saving the config
    UnloadLib() --unloading lualib
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("CreateMove", "WallstuckLua_CreateMove")            -- Unregister the "CreateMove" callback
callbacks.Unregister("Unload", "WallstuckLua_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "WallstuckLua_Draw")                        -- Unregister the "Draw" callback
--[[ Register callbacks ]]--
callbacks.Register("CreateMove", "WallstuckLua_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
callbacks.Register("Unload", "WallstuckLua_Unload", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("Draw", "WallstuckLua_Draw", doDraw)                               -- Register the "Draw" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded