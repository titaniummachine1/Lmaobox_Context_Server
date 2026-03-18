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
local swingrange = 48
local tickRate = 66
local SwingTime = 15
local vHitbox = { Vector3(-24, -24, 0), Vector3(24, 24, 82) }

local closestDistance = 2000
local fDistance = 1
local hitbox_Height = 82
local hitbox_Width = 24
local isMelee = false
local mresolution = 64
local ping = 0
local tick_count = 0
local time = 15
local Gcan_attack = false
local Safe_Strafe = false
local can_charge = false
local Charge_Range = 128
local swingRangeMultiplier = 1
local defFakeLatency = gui.GetValue("Fake Latency Value (MS)")
local Backtrackpositions = {}
local pLocalPath = {}
local vPlayerPath = {}
local PredPath = {}

local vdistance = nil
local pLocalClass = nil
local pLocalFuture = nil
local pLocalOrigin = nil
local pWeapon = nil
local Latency = nil
local viewheight = nil
local Vheight = nil
local vPlayerFuture = nil
local vPlayer = nil
local vPlayerOrigin = nil
local chargeLeft = nil
local target_strafeAngle = nil
local onGround = nil
local CurrentTarget = nil
local aimposVis = nil
local in_attack = nil

local latency = 0
local lerp = 0
local lastAngles = {} ---@type table<number, EulerAngles>
local strafeAngles = {} ---@type table<number, number>
local strafeAngleHistories = {} ---@type table<number, table<number, number>>
local MAX_ANGLE_HISTORY = 2  -- Number of past angles to consider for averaging

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

    tabs = { -- dont touch this, this is just for managing the tabs in the menu
        Main = true,
        Aimbot = false,
        Misc = false,
        Visuals = false,
    },

    Main = {
        Active = true,  --disable lua
        Insta_Hit = true,
        Keybind = "Always_On",
        keybind_Idx = 0,
        Is_Listening_For_Key = false,
    },

    Aimbot = {
        Aimbot = true,
        AimbotFOV = 360,
        MaxDistance = 1000,
        Silent = true,
        AutoAttack = true,
        Smooth = false, --unrecomended
        smoothness = 0.1, --how quickly it will move to the target
    },

    Misc = {
        Auto_CritRefill = true,
        ChargeReach = false,
        TroldierAssist = false,
        ChargeControl = false,
        ChargeSensitivity = 50,
    },

    Visuals = {
        EnableVisuals = false,
        VisualizeHitbox = false,
        Visualize_Attack_Range = false,
        Visualize_Attack_Point = false,
        Visualize_Pred_Local = false,
        Visualize_Pred_Enemy = false,
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

    -- Returns all currently pressed keys as a table
    ---@return integer[]
    local function GetPressedKeys()
        local keys = {}
        for i = KEY_FIRST, KEY_LAST do
            if input.IsButtonDown(i) then table.insert(keys, i) end
        end

        return keys
    end

    -- Returns if the cursor is in the given bounds
    ---@param x integer
    ---@param y integer
    ---@param x2 integer
    ---@param y2 integer
    ---@return boolean
    local function MouseInBounds(x, y, x2, y2)
        local mx, my = table.unpack(input.GetMousePos())
        return mx >= x and mx <= x2 and my >= y and my <= y2
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

    ---@param me WPlayer
    local function CalcStrafe(me)
        local players = entities.FindByClass("CTFPlayer")
        for idx, entity in ipairs(players) do
            local entityIndex = entity:GetIndex()  -- Get the entity's index

            if entity:IsDormant() or not entity:IsAlive() then
                lastAngles[entityIndex] = nil
                strafeAngles[entityIndex] = nil
                strafeAngleHistories[entityIndex] = nil
                goto continue
            end

            -- Ignore teammates (for now)
            if entity:GetTeamNumber() == me:GetTeamNumber() then
                goto continue
            end

            local v = entity:EstimateAbsVelocity()
            local angle = v:Angles()

            -- Initialize angle history for the player if needed
            strafeAngleHistories[entityIndex] = strafeAngleHistories[entityIndex] or {}

            -- Player doesn't have a last angle
            if lastAngles[entityIndex] == nil then
                lastAngles[entityIndex] = angle
                goto continue
            end

            -- Calculate the delta angle
            local delta = 0
            delta = angle.y - lastAngles[entityIndex].y

            -- Update the angle history
            table.insert(strafeAngleHistories[entityIndex], delta)
            if #strafeAngleHistories[entityIndex] > MAX_ANGLE_HISTORY then
                table.remove(strafeAngleHistories[entityIndex], 1)
            end

            -- Calculate the average delta from the history
            local sum = 0
            for i, delta in ipairs(strafeAngleHistories[entityIndex]) do
                sum = sum + delta
            end
            local avgDelta = sum / #strafeAngleHistories[entityIndex]

            -- Set the average delta as the strafe angle
            strafeAngles[entityIndex] = avgDelta
            lastAngles[entityIndex] = angle

            ::continue::
        end
    end

        ---@param me WPlayer
    ---@return AimTarget? target
    local function GetBestTarget(me)
        local players = entities.FindByClass("CTFPlayer")
        local localPlayer = entities.GetLocalPlayer()
        if not localPlayer then return end

        local targetList = {}
        local targetCount = 0

        -- Calculate target factors
        for i, player in ipairs(players) do
            if not Helpers.VisPos(player, pLocalOrigin, player:GetAbsOrigin()) then
                -- Skip players not visible
                goto continue
            end

            if player == localPlayer or player:GetTeamNumber() == localPlayer:GetTeamNumber() then
                -- Skip local player and teammates
                goto continue
            end

            if player == nil or not player:IsAlive() then
                -- Skip dead players or nil references
                goto continue
            end

            if gui.GetValue("ignore cloaked") == 1 and player:InCond(4) then
                -- Skip cloaked players if enabled
                goto continue
            end

            if player:IsDormant() then
                -- Skip dormant players
                goto continue
            end

            local distance = (player:GetAbsOrigin() - localPlayer:GetAbsOrigin()):Length()

            -- Visibility Check
            local angles = Math.PositionAngles(pLocalOrigin, player:GetAbsOrigin() + Vector3(0, 0, viewheight))
            local fov = Math.AngleFov(engine.GetViewAngles(), angles)

            if fov > Main.Aimbot.AimbotFOV then goto continue end

            local distanceFactor = Math.RemapValClamped(distance, 0, Main.Aimbot.MaxDistance, 1, 0.07)
            local fovFactor = Math.RemapValClamped(fov, 0, Main.Aimbot.AimbotFov, 1, 1)

            local factor = distanceFactor * fovFactor

            targetCount = targetCount + 1
            targetList[targetCount] = { player = player, factor = factor }

            ::continue::
        end

        -- Sort target list by factor in descending order manually
        for i = 1, targetCount - 1 do
            for j = 1, targetCount - i do
                if targetList[j].factor < targetList[j + 1].factor then
                    targetList[j], targetList[j + 1] = targetList[j + 1], targetList[j]
                end
            end
        end

        local bestTarget = nil

        if targetCount > 0 then
            local player = targetList[1].player
            local aimPos = player:GetAbsOrigin() + Vector3(0, 0, 75)
            local angles = Math.PositionAngles(localPlayer:GetAbsOrigin(), aimPos)
            local fov = Math.AngleFov(angles, engine.GetViewAngles())

            -- Set as best target
            bestTarget = { entity = player, angles = angles, factor = targetList[1].factor }
        end

        return bestTarget
    end

    local fFalse = function () return false end

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

local function OnCreateMove(pCmd)
    -- Retrieve the local player entity
    pLocal = entities.GetLocalPlayer()
    warp.TriggerDoubleTap(15) -- Trigger double tap
 
    -- Check if the local player is valid and alive
    if not pLocal or not pLocal:IsAlive() then
        goto continue -- Skip further processing if the local player is invalid or dead
    end

    -- Determine if the local player's class is Spy
    pLocalClass = pLocal:GetPropInt("m_iClass")
    if pLocalClass == nil or pLocalClass == 8 then
        goto continue -- Skip further processing if the player is a Spy or the class is undefined
    end

    -- Obtain the local player's currently active weapon
    pWeapon = pLocal:GetPropEntity("m_hActiveWeapon")
    if not pWeapon then
        goto continue -- Skip further processing if no active weapon is found
    end

    -- Calculate network latency and interpolation lag (lerp)
    local latOut = clientstate.GetLatencyOut() -- Outgoing network latency
    local latIn = clientstate.GetLatencyIn()  -- Incoming network latency
    lerp = client.GetConVar("cl_interp") or 0  -- Client interpolation value

    -- Combine latencies and convert the total to 'ticks' for game processing
    Latency = (latOut + lerp) -- Total latency in seconds
    Latency = math.floor(Latency * tickRate + 1) -- Convert latency to the number of ticks

    
    ::continue::
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

local bindTimer = 0
local bindDelay = 0.15  -- Delay of 0.2 seconds


local function doDraw()

    ---Menu----------------------------------------------------------------------------------------------

    -- Inside your OnCreateMove or similar function where you check for input
    if input.IsButtonDown(KEY_INSERT) then  -- Replace 72 with the actual key code for the button you want to use
        toggleMenu()
    end

    if Lbox_Menu_Open == true and ImMenu and ImMenu.Begin("Swing Prediction", true) then
            ImMenu.BeginFrame(1) -- tabs
                if ImMenu.Button("Main") then
                    Menu.tabs.Main = true
                    Menu.tabs.Aimbot = false
                    Menu.tabs.Misc = false
                    Menu.tabs.Visuals = false
                end
                if ImMenu.Button("Aimbot") then
                    Menu.tabs.Main = false
                    Menu.tabs.Aimbot = true
                    Menu.tabs.Misc = false
                    Menu.tabs.Visuals = false
                end
                if ImMenu.Button("Misc") then
                    Menu.tabs.Main = false
                    Menu.tabs.Aimbot = false
                    Menu.tabs.Misc = true
                    Menu.tabs.Visuals = false
                end
                if ImMenu.Button("Visuals") then
                    Menu.tabs.Main = false
                    Menu.tabs.Aimbot = false
                    Menu.tabs.Misc = false
                    Menu.tabs.Visuals = true
                end
            ImMenu.EndFrame()
        
            if Menu.tabs.Main then
                ImMenu.BeginFrame(1)
                    Menu.Main.Active = ImMenu.Checkbox("Enable", Menu.Main.Active)
                ImMenu.EndFrame()

                --[[ImMenu.BeginFrame(1)
                    Menu.Main.Insta_Hit = ImMenu.Checkbox("Instant Hit", Menu.Main.Insta_Hit)
                ImMenu.EndFrame()]]

                ImMenu.BeginFrame(1)
                    ImMenu.Text("Keybind: ")

                    if Menu.Main.Keybind ~= "Press The Key" and ImMenu.Button(Menu.Main.Keybind) then
                        Menu.Main.Is_Listening_For_Key = not Menu.Main.Is_Listening_For_Key
                        if Menu.Main.Is_Listening_For_Key then
                            bindTimer = os.clock() + bindDelay
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

                --[[ImMenu.BeginFrame(1)
                    ImMenu.Text("                  Trickstab Modes")
                ImMenu.EndFrame()
                
                ImMenu.BeginFrame(1)
                    Menu.Main.TrickstabModeSelected = ImMenu.Option(Menu.Main.TrickstabModeSelected, Menu.Main.TrickstabMode)
                ImMenu.EndFrame()
        
                ImMenu.BeginFrame(1)
                ImMenu.Text("Please Use Lbox Auto Backstab")
                ImMenu.EndFrame()
        
                ImMenu.BeginFrame(1)
                Menu.Main.AutoWalk = ImMenu.Checkbox("Auto Walk", Menu.Main.AutoWalk)
                Menu.Main.AutoAlign = ImMenu.Checkbox("Auto Align", Menu.Main.AutoAlign)
                ImMenu.EndFrame()]]
            end

            if Menu.tabs.Aimbot then
                --[[ImMenu.BeginFrame(1)
                    ImMenu.Text("                  Trickstab Modes")
                ImMenu.EndFrame()
                
                ImMenu.BeginFrame(1)
                    Menu.Main.TrickstabModeSelected = ImMenu.Option(Menu.Main.TrickstabModeSelected, Menu.Main.TrickstabMode)
                ImMenu.EndFrame()
        
                ImMenu.BeginFrame(1)
                ImMenu.Text("Please Use Lbox Auto Backstab")
                ImMenu.EndFrame()
        
                ImMenu.BeginFrame(1)
                Menu.Main.AutoWalk = ImMenu.Checkbox("Auto Walk", Menu.Main.AutoWalk)
                Menu.Main.AutoAlign = ImMenu.Checkbox("Auto Align", Menu.Main.AutoAlign)
                ImMenu.EndFrame()]]
            end

            if Menu.tabs.Misc then

                --[[ImMenu.BeginFrame(1)
                Menu.Advanced.Accuracy = ImMenu.Slider("Colision Accuracy", Menu.Advanced.Accuracy, 1, SIMULATION_TICKS)
                ImMenu.EndFrame()

                ImMenu.BeginFrame(1)
                Menu.Advanced.ManualDirection = ImMenu.Checkbox("Manual Direction", Menu.Advanced.ManualDirection)
                ImMenu.EndFrame()

                ImMenu.BeginFrame(1)
                Menu.Advanced.ColisionCheck = ImMenu.Checkbox("Colision Check", Menu.Advanced.ColisionCheck)
                Menu.Advanced.AdvancedPred = ImMenu.Checkbox("Advanced Pred", Menu.Advanced.AdvancedPred)
                ImMenu.EndFrame()

                ImMenu.BeginFrame(1)
                Menu.Advanced.AutoWarp = ImMenu.Checkbox("Auto Warp", Menu.Advanced.AutoWarp)
                Menu.Advanced.AutoRecharge = ImMenu.Checkbox("Auto Recharge", Menu.Advanced.AutoRecharge)
                ImMenu.EndFrame()]]
            end
            
            if Menu.tabs.Visuals then
            --[[ ImMenu.BeginFrame(1)
                Menu.Visuals.Active = ImMenu.Checkbox("Active", Menu.Visuals.Active)
                ImMenu.EndFrame()
        
                ImMenu.BeginFrame(1)
                Menu.Visuals.VisualizePoints = ImMenu.Checkbox("Simulations", Menu.Visuals.VisualizePoints)
                Menu.Visuals.VisualizeStabPoint = ImMenu.Checkbox("Stab Points", Menu.Visuals.VisualizeStabPoint)
                ImMenu.EndFrame()

                ImMenu.BeginFrame(1)
                Menu.Visuals.Attack_Circle = ImMenu.Checkbox("Attack Circle", Menu.Visuals.Attack_Circle)
                Menu.Visuals.ForwardLine = ImMenu.Checkbox("Forward Line", Menu.Visuals.ForwardLine)
                ImMenu.EndFrame()]]
            end
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
callbacks.Unregister("CreateMove", "ASwingPrediction_CreateMove")            -- Unregister the "CreateMove" callback
callbacks.Unregister("Unload", "ASwingPrediction_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "ASwingPrediction_Draw")                        -- Unregister the "Draw" callback
--[[ Register callbacks ]]--
callbacks.Register("CreateMove", "ASwingPrediction_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
callbacks.Register("Unload", "ASwingPrediction_Unload", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("Draw", "ASwingPrediction_Draw", doDraw)                               -- Register the "Draw" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded