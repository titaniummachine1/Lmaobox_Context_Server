local myfont = draw.CreateFont( "Verdana", 16, 800 )

local function doDraw()
    if engine.Con_IsVisible() or engine.IsGameUIVisible() then
        return
    end

    local players = entities.FindByClass("CTFPlayer")

    local localP = entities.GetLocalPlayer()
    local localPlayerPos = localP:GetAbsOrigin()
    local localPOrigin = localP:GetAbsOrigin()
    draw.Color( 255, 255, 0, 255 )
    for _, enemyPlayer in ipairs(players) do
        if enemyPlayer:IsAlive() and not enemyPlayer:IsDormant() and enemyPlayer ~= localP then
            local enemyPos = enemyPlayer:GetAbsOrigin()
            local distance = (enemyPos - localPlayerPos):Length()
            local direction = (enemyPos - localPlayerPos)
            local enemyScreenPos = client.WorldToScreen(enemyPos)
            local localPlayerScreenPos = client.WorldToScreen(localPlayerPos)
    
            local me = entities.GetLocalPlayer();
local source = me:GetAbsOrigin() + me:GetPropVector( "localdata", "m_vecViewOffset[0]" );
local destination = source + engine.GetViewAngles():Forward() * 1000;

local trace = engine.TraceLine( source, destination, MASK_SHOT_HULL );

if (trace.entity ~= nil) then
    --print( "I am looking at " .. trace.entity:GetClass() );
end

            local sectionLength = distance
            local start = localPOrigin + direction
            local endPos = enemyPos - direction
            local startScreenPos = client.WorldToScreen(start)
            local endScreenPos = client.WorldToScreen(endPos)
    
            if startScreenPos ~= nil and endScreenPos ~= nil then
                draw.Line(startScreenPos[1], startScreenPos[2], endScreenPos[1], endScreenPos[2])
            end
                local rockets = entities.FindByClass("CTFProjectile_Rocket") -- Find all rockets
                for i, rocket in pairs(rockets) do                          -- Loop through all rockets
        
                    local rocketPos = rocket:GetAbsOrigin()               -- Set "rocketPos" to the rocket's position
                    local rocketScreenPos = client.WorldToScreen(rocketPos) -- Set "rocketScreenPos" to the x/z coordinates of the rocket's position based on the player's screen
                    local rocketDest = vector.Add(rocketPos, vector.Normalize(rocket:EstimateAbsVelocity())) -- Set "rocketDest" to the rocket's estimated direction based on the rocket's estimated velocity (this should probably be replaced with the rocket's direction)
                    local rocketTrace = engine.TraceLine(rocketPos, rocketDest, MASK_SHOT_HULL) -- Trace a line from the rocket's position to the rocket's estimated direction until it hits something
                    local hitPosScreen = client.WorldToScreen(rocketTrace.endpos) -- Set "hitPosScreen" to the x/z coordinates of the trace's hit position based on the player's screen
        
                    draw.Color(255, 0, 0, 255) -- Set the color to red
                    -- if type(exp) == "table" then printLuaTable(exp) else print( table.concat( {exp}, '\n' ) )
                    draw.Line(rocketScreenPos[1], rocketScreenPos[2], hitPosScreen[1], hitPosScreen[2]) --Draw a line from the rocket to the trace's hit position
                    draw.Line(rocketScreenPos[1] + 1, rocketScreenPos[2] + 1 , hitPosScreen[1] + 1, hitPosScreen[2]) --Used to make lines thicker (could probably be removed)
                    draw.Line(rocketScreenPos[1] - 1, rocketScreenPos[2] - 1 , hitPosScreen[1] - 1, hitPosScreen[2])
            end
        end
    end
end


callbacks.Register("Draw", "mydraw", doDraw)