

local menuLoaded, MenuLib = pcall(require, "Menu")                                -- Load MenuLib
assert(menuLoaded, "MenuLib not found, please install it!")                       -- If not found, throw error
assert(MenuLib.Version >= 1.44, "MenuLib version is too old, please update it!")  -- If version is too old, throw error

--[[ Menu ]]--
local menu = MenuLib.Create("Swing Prediction", MenuFlags.AutoSize)
menu.Style.TitleBg = { 205, 95, 50, 255 } -- Title Background Color (Flame Pea)
menu.Style.Outline = true                 -- Outline around the menu


local debug         = menu:AddComponent(MenuLib.Checkbox("indicator", false))
local Swingpred     = menu:AddComponent(MenuLib.Checkbox("Enable", true))
local mtime         = menu:AddComponent(MenuLib.Slider("movement ahead", 100 ,10000 , 225 ))
local msamples      = menu:AddComponent(MenuLib.Slider("Velocity Samples", 1 ,66 , 66 ))
--amples    = menu:AddComponent(MenuLib.Slider("movement ahead", 1 ,25 , 200 ))




function GameData()
    local data = {}

    -- Get local player data
    data.pLocal = entities.GetLocalPlayer()     -- Immediately set "pLocal" to the local player (entities.GetLocalPlayer)
    data.pWeapon = data.pLocal:GetPropEntity("m_hActiveWeapon")
    data.swingrange = data.pWeapon:GetSwingRange() -- + 11.17
    data.tickRate = 66 -- game tick rate
    --get pLocal eye level and set vector at our eye level to ensure we cehck distance from eyes
    local viewOffset = data.pLocal:GetPropVector("localdata", "m_vecViewOffset[0]")
    local adjustedHeight = data.pLocal:GetAbsOrigin() + viewOffset
    data.viewheight = (adjustedHeight - data.pLocal:GetAbsOrigin()):Length()
        -- eye level 
        local Vheight = Vector3(0, 0, data.viewheight)
        data.pLocalOrigin = (data.pLocal:GetAbsOrigin() + Vheight)
    --get local class
    data.pLocalClass = data.pLocal:GetPropInt("m_iClass")


    return data
end
        
    





--[[ Code needed to run 66 times a second ]]--
local function OnCreateMove(pCmd, gameData)
    if not Swingpred:GetValue() then goto continue end -- enable or distable script

    local time = mtime:GetValue() * 0.001
    gameData = GameData()  -- Update gameData with latest information
    local pLocal, pWeapon, swingrange, viewheight, pLocalOrigin, pLocalClass, tickRate
    = gameData.pLocal, gameData.pWeapon, gameData.swingrange, gameData.viewheight, gameData.pLocalOrigin, gameData.pLocalClass, gameData.tickRate
    -- Use pLocal, pWeapon, pWeaponDefIndex, etc. as needed
    if not pLocal then return end  -- Immediately check if the local player exists. If it doesn't, return.
    if pLocalClass == nil then goto continue end
    if pLocalClass == 8 then return end

    -- Initialize closest distance and closest player
    local players = entities.FindByClass("CTFPlayer")  -- Create a table of all players in the game




    

        
        --[[position prediction]]--
        
     --[[position prediction]]--
if targetOriginLast == nil then
    targetOriginLast = Vector3(0, 0, 0)
end

-- If either the target's last known position or previous origin is nil, return nil.
if targetOriginLast == nil or targetLastPos == nil then
    return nil
end

-- Initialize targetVelocitySamples as a table if it doesn't exist.
if not targetVelocitySamples then
    targetVelocitySamples = {}
end

-- Initialize the table for this target if it doesn't exist.
local targetKey = tostring(targetLastPos)
if not targetVelocitySamples[targetKey] then
    targetVelocitySamples[targetKey] = {}
end

-- Insert the latest velocity sample into the table.
local targetVelocity = LocalViewPos - targetOriginLast
table.insert(targetVelocitySamples[targetKey], 1, targetVelocity)

local samples = msamples:GetValue()
-- Remove the oldest sample if there are more than maxSamples.
if #targetVelocitySamples[targetKey] > samples then
    table.remove(targetVelocitySamples[targetKey], samples + 1)
end

-- Calculate the average velocity from the samples.
local totalVelocity = Vector3(0, 0, 0)
for i = 1, #targetVelocitySamples[targetKey] do
    totalVelocity = totalVelocity + targetVelocitySamples[targetKey][i]
end
local averageVelocity = totalVelocity / #targetVelocitySamples[targetKey]

-- Initialize the curve to a zero vector.
local curve = Vector3(0, 0, 0)

-- Calculate the curve of the path if there are enough samples.
if #targetVelocitySamples[targetKey] >= 2 then
    local previousVelocity = targetVelocitySamples[targetKey][1]
    for i = 2, #targetVelocitySamples[targetKey] do
        local currentVelocity = targetVelocitySamples[targetKey][i]
        curve = curve + (previousVelocity - currentVelocity)
        previousVelocity = currentVelocity
    end
    curve = curve / (#targetVelocitySamples[targetKey] - 1)
end

-- example usage
local currentPosition = pLocalOrigin
local currentVelocity = pLocal:GetAbsOrigin()
local timeDelta = globals.globals.AbsoluteFrameTime() -- assume time interval is 2 seconds

-- Scale the curve by the tick rate and time to predict.
curve = curve * tickRate * time

-- Calculate the acceleration of the target.
local acceleration = (pLocalOrigin - targetOriginLast) / (timeDelta * timeDelta)

        -- Scale the curve by the tick rate and time to predict.
        curve = curve * tickRate * time
        acceleration = (LocalViewPos - pLocalOriginLast) / globals.AbsoluteFrameTime() --timeDelta

        -- Add the curve to the predicted future position of the target.
        local targetFuture = LocalViewPos + (averageVelocity * time) + curve
    
        pLocalFuture = targetFuture
        pLocalFuture = pLocalOrigin + pLocal:EstimateAbsVelocity() * 2.5
      print(pLocalFuture)
      
--[[-----------------------------Swing Prediction------------------------------------------------------------------------]]


-- Update last variables
            vPlayerOriginLast = vPlayerOrigin
            pLocalOriginLast = pLocalOrigin
    ::continue::
end
    

-- debug command: ent_fire !picker Addoutput "health 99"
local myfont = draw.CreateFont( "Verdana", 16, 800 ) -- Create a font for doDraw
--[[ Code called every frame ]]--
local function doDraw()
    if engine.Con_IsVisible() or engine.IsGameUIVisible() then
        return
    end
    
    if pLocalFuture == nil then return end

    local pLocal = entities.GetLocalPlayer()

    --local pAbsOrigin = tonumber(pLocal:GetAbsOrigin()["z"])
    if debug and debug:GetValue() == true  then
        if pLocalFuture == nil then return end
        draw.SetFont( myfont )
        draw.Color( 255, 255, 255, 255 )
        local w, h = draw.GetScreenSize()
        local screenPos = { w / 2 - 15, h / 2 + 35}



        
        screenPos = client.WorldToScreen(pLocalFuture)
            if screenPos ~= nil then
                draw.Line( screenPos[1] + 10, screenPos[2], screenPos[1] - 10, screenPos[2])
                draw.Line( screenPos[1], screenPos[2] - 10, screenPos[1], screenPos[2] + 10)
            end
    end
end




local wait = 0
local wait2 = 0

function aimbob(kaka)

    if engine.IsGameUIVisible() == false then

        local flags = entities.GetLocalPlayer():GetPropInt( "m_fFlags" );

        if flags & FL_ONGROUND == 0  and input.IsButtonDown( KEY_LSHIFT ) then

            local x, y, z = kaka:GetViewAngles()

                pitch = pLocalFuture.z - entities.GetLocalPlayer():GetAbsOrigin().z

                pitch = -pitch / 4

                pitch = pitch + 37

                if pitch < -89 then
                pitch = -89
                end

                if pitch > 89 then
                pitch = 89
                end

                kaka:SetViewAngles(pitch, y, 0)

                if input.IsButtonDown( KEY_LSHIFT ) and (globals.RealTime() > (wait + 0.1)) then -- rly bad way of autoshoot
                    kaka:SetButtons(kaka.buttons | IN_ATTACK)
                    wait = globals.RealTime()
                end

                if input.IsButtonDown( KEY_LSHIFT) and (globals.RealTime() > (wait2 + 0.2)) then
                    kaka:SetButtons(kaka.buttons & (~IN_ATTACK))
                    wait2 = globals.RealTime()
                end

                if input.IsButtonDown( KEY_LSHIFT ) then

                    kaka:SetButtons(kaka.buttons | IN_ATTACK2  )
                else
                    kaka:SetButtons(kaka.buttons & (~IN_ATTACK2  ))
                end

            end

        else
            kaka:SetButtons(kaka.buttons & (~IN_ATTACK2))
            kaka:SetButtons(kaka.buttons & (~IN_ATTACK))
        end
    end


function drav()

    draw.Text( 500, 500, "pLocalFuture pitch ".. tostring(math.floor(pLocalFuture["z"])) )

    draw.Text( 500, 520, "GetViewAngles ".. tostring(viewAngles) )

    draw.Text( 500, 540, "pitch ".. tostring(pitch) )

    draw.Text( 500, 560, "pos| ".. "x ".. math.floor(entities.GetLocalPlayer():GetAbsOrigin().x) .. " |y ".. math.floor(entities.GetLocalPlayer():GetAbsOrigin().y) .. " |z ".. math.floor(entities.GetLocalPlayer():GetAbsOrigin().z) )
    
    draw.Text(500, 580, "predicted pos| ".. "x ".. tostring(math.floor(pLocalFuture["x"])).. " |y ".. math.floor(pLocalFuture["y"]).. " |z ".. math.floor(pLocalFuture["z"]))


    --draw.Text(500, 580, "totalVelocity ".. totalVelocity.x)

end
callbacks.Register( "Draw", "drav", drav )


--[[ Remove the menu when unloaded ]]--
local function OnUnload()                                -- Called when the script is unloaded
    MenuLib.RemoveMenu(menu)                             -- Remove the menu
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end


--[[ Unregister previous callbacks ]]--
callbacks.Unregister("CreateMove", "MCT_CreateMove")            -- Unregister the "CreateMove" callback
callbacks.Unregister("Unload", "MCT_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "MCT_Draw")                        -- Unregister the "Draw" callback
--[[ Register callbacks ]]--

callbacks.Register("CreateMove", "MCT_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("Draw", "MCT_Draw", doDraw)         
callbacks.Register("CreateMove", "aimbob", aimbob)                        -- Register the "Draw" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded