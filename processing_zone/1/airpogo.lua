
---@alias AimTarget { entity : Entity, pos : Vector3, angles : EulerAngles, factor : number }

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.967, "LNXlib version is too old, please update it!")

local menuLoaded, MenuLib = pcall(require, "Menu")                                -- Load MenuLib
assert(menuLoaded, "MenuLib not found, please install it!")                       -- If not found, throw error
assert(MenuLib.Version >= 1.44, "MenuLib version is too old, please update it!")  -- If version is too old, throw error

--[[ Menu ]]--
local menu = MenuLib.Create("Air Pogo", MenuFlags.AutoSize)
menu.Style.TitleBg = { 205, 95, 50, 255 } -- Title Background Color (Flame Pea)
menu.Style.Outline = true                 -- Outline around the menu


local debug         = menu:AddComponent(MenuLib.Checkbox("indicator", false))
local Swingpred     = menu:AddComponent(MenuLib.Checkbox("Enable", true))
local mtime         = menu:AddComponent(MenuLib.Slider("movement ahead", 100 ,10000 , 225 ))
local msamples      = menu:AddComponent(MenuLib.Slider("Velocity Samples", 1 ,66 , 66 ))
--samples    = menu:AddComponent(MenuLib.Slider("movement ahead", 1 ,25 , 200 ))

local pLocal = entities.GetLocalPlayer()
local pLocalClass = pLocal:GetPropInt("m_iClass")
local tickRate = 66


local LocalViewPos = pLocal:GetPropVector( "localdata", "m_vecViewOffset[0]")
local LocalViewHeight
local pLocalFuture

local options = {
    AimKey      = KEY_LSHIFT,
    AutoShoot   = true,
    Silent      = true,
    AimPos      = pLocalFuture,
    AimFov      = 360
}




--[[ Code needed to run 66 times a second ]]--

---@param userCmd UserCmd
local function OnCreateMove(pCmd)
    local options = {
        AimKey      = KEY_LSHIFT,
        AutoShoot   = true,
        Silent      = true,
        AimPos      = pLocalFuture,
        AimFov      = 360
    }

    pLocal = entities.GetLocalPlayer()
    pLocalClass = pLocal:GetPropInt("m_iClass")

    local time = mtime:GetValue() * 0.001
    -- Use pLocal, pWeapon, pWeaponDefIndex, etc. as needed
    if not pLocal then return end  -- Immediately check if the local player exists. If it doesn't, return.
    if pLocalClass == nil then goto continue end
    if pLocalClass == 8 then return end

    -- Initialize closest distance and closest player
    local players = entities.FindByClass("CTFPlayer")  -- Create a table of all players in the game




    

        
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
local currentPosition = LocalViewPos
local currentVelocity = pLocal:GetAbsOrigin()
local timeDelta = globals.globals.AbsoluteFrameTime() -- assume time interval is 2 seconds

-- Scale the curve by the tick rate and time to predict.
curve = curve * tickRate * time

-- Calculate the acceleration of the target.
local acceleration = (LocalViewPos - targetOriginLast) / (timeDelta * timeDelta)

        -- Scale the curve by the tick rate and time to predict.
        curve = curve * tickRate * time
        acceleration = (LocalViewPos - pLocalOriginLast) / globals.AbsoluteFrameTime() --timeDelta

        -- Add the curve to the predicted future position of the target.
        local targetFuture = LocalViewPos + (averageVelocity * time) + curve --(-0.5 * acceleration * time * time) +
    
        pLocalFuture = targetFuture
        pLocalFuture = LocalViewPos + pLocal:EstimateAbsVelocity() * 0.5
      print(pLocalFuture)

      


    local me = pLocal
    if not me then return end

    -- Get the best target
    local currentTarget = pLocal
    if not currentTarget then return end
    --predict position
    --currentTarget = TargetPositionPrediction(currentTarget.pos, lasttarget.pos, mtime, currentTarget)
    if not input.IsButtonDown(options.AimKey) then return end
    -- Aim at the target
    userCmd:SetViewAngles(currentTarget.angles:Unpack())
    print(currentTarget.angles:Unpack())
    if not options.Silent then
        engine.SetViewAngles(currentTarget.angles)
    end
    local pWeapon = me:GetPropEntity("m_hActiveWeapon")
    -- Auto Shoot
    
    if options.AutoShoot then
        userCmd.buttons = userCmd.buttons | IN_ATTACK
    end

-- Update last variables
            pLocalOriginLast = LocalViewPos
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







myfont = draw.CreateFont( "Verdana", 16, 800 ) -- Create a font for doDraw



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

callbacks.Register("CreateMove", "MCT_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback(on tick)
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("Draw", "MCT_Draw", doDraw)
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded