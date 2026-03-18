---@alias AimTarget { entity : Entity, angles : EulerAngles, factor : number }

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.995, "lnxLib version is too old, please update it!")
UnloadLib() --unloads all packages

local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer, WWeapon = lnxLib.TF2.WPlayer, lnxLib.TF2.WWeapon
local Helpers = lnxLib.TF2.Helpers
local Prediction = lnxLib.TF2.Prediction

local distance
local pLocal
local players = {}
local center
local closestPoint1
local targetAngle
local Jitter_Real1
local currentTarget

-- Returns the best target (lowest fov)
---@param me WPlayer
---@return AimTarget? target
local function GetBestTarget(me, pLocalOrigin)
    -- Find all players in the game
    players = entities.FindByClass("CTFPlayer")

    -- Initialize variables
    local target = nil
    local lastFov = math.huge
    local closestPlayer = nil
    local closestDistance = math.huge
    local options = {
        AimPos = 1,
        AimFov = 360
    }

    -- Loop through all players
    for _, entity in pairs(players) do
        -- Skip the local player
        if entity == pLocal then goto continue end

        -- Check if the player is a valid target
        local ValidTarget = entity and entity:IsAlive() and entity:GetTeamNumber() ~= me:GetTeamNumber()

        -- If the player is a valid target and is a scout or sniper class, continue
        if ValidTarget and (entity:GetPropInt("m_iClass") == 2 or entity:GetPropInt("m_iClass") == 8) then
            -- Calculate the distance between the player and the local player
            distance = (entity:GetAbsOrigin() - me:GetAbsOrigin()):Length()

            -- If the player is closer than the closest distance so far, set them as the closest player
            if distance < closestDistance and distance < 2000 then
                closestPlayer = entity
                closestDistance = distance
            end

            -- Get the position of the target and the local player, as well as the forward vector of the local player's view
            local targetPos = entity:GetAbsOrigin()
            local playerPos = me:GetAbsOrigin()
            local forwardVec = engine.GetViewAngles():Forward()

            -- Calculate the angle between the target and the local player, as well as the angle between the local player's view and the horizontal plane
            local targetAngle1 = math.deg(math.atan(targetPos.y - playerPos.y, targetPos.x - playerPos.x))
            local viewAngle = math.deg(math.atan(forwardVec.y, forwardVec.x))
            local finalAngle = targetAngle1 - viewAngle

            -- Get the position of the target's hitbox that we want to aim for, as well as the angle we need to aim at to hit it
            local player = WPlayer.FromEntity(entity)
            local aimPos = player:GetHitboxPos(options.AimPos)
            local angles = Math.PositionAngles(engine.GetViewAngles():Forward(), aimPos)
            local fov = Math.AngleFov(angles, engine.GetViewAngles())
            local entityOrigin = entity:GetAbsOrigin()


            -- Define a function that checks if this target has a better FOV than the current target, and if so, sets it as the new target
            local function bestFov()
                if fov < lastFov then
                    lastFov = fov
                    target = { entity = entity, pos = aimPos, angles = angles, factor = fov }
                end
            end

            -- If the target is not visible, prioritize based on FOV
            if closestDistance <= 250 then
                target = closestPlayer
                -- Otherwise, prioritize based on FOV
            else
                bestFov()
            end
        end
        -- Continue to the next player
        ::continue::
    end

    if target == nil then return nil end
    return target
end

local function updateYaw(Jitter_Real, Jitter_Fake)
    if currentTarget and not entities.GetLocalPlayer():cond(17) then
        local targetPos = currentTarget
        if targetPos == nil then goto continue end

        local playerPos = entities.GetLocalPlayer():GetAbsOrigin()
        local forwardVec = engine.GetViewAngles():Forward()

        targetAngle = math.deg(math.atan(targetPos.y - playerPos.y, targetPos.x - playerPos.x))
        local viewAngle = math.deg(math.atan(forwardVec.y, forwardVec.x))
        TargetAngle = math.floor(targetAngle - viewAngle)

        local yaw

        --Fake angle
            yaw = TargetAngle + Jitter_Fake

        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end

        Jitter_Fake1 = yaw - TargetAngle
        yaw = math.floor(yaw)
        gui.SetValue("Anti Aim - Custom Yaw (Fake)", yaw)

        --Real angle
            yaw = TargetAngle - jitter_Real
        
        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end

        Jitter_Real1 = yaw - TargetAngle
        yaw = math.floor(yaw)

        gui.SetValue("Anti Aim - Custom Yaw (Real)", yaw)


        -- Clamp the yaw angle if it's greater than 180 or less than -180
        if yaw > 180 then
            yaw = yaw - 360
        elseif yaw < -180 then
            yaw = yaw + 360
        end
        Jitter_Real1 = yaw - TargetAngle
        yaw = math.floor(yaw)
        gui.SetValue("Anti Aim - Custom Yaw (Real)", yaw)
    end
    ::continue::
end

local function OnCreateMove(pCmd)
    pLocal = entities.GetLocalPlayer()
    players = entities.FindByClass("CTFPlayer")  -- Create a table of all players in the game
    --local rockets = entities.FindByClass("CTFProjectile_Rocket") -- Find all rockets
    local pLocalView = pLocal:GetAbsOrigin() + pLocal:GetPropVector("localdata", "m_vecViewOffset[0]")

    currentTarget = GetBestTarget(pLocal, pLocalView)

    for j, vPlayer in pairs(players) do
        if not vPlayer:IsAlive() or vPlayer:IsDormant() or pLocal:GetIndex() == vPlayer:GetIndex() then goto continue end

        distance = (pLocal:GetAbsOrigin() - vPlayer:GetAbsOrigin()):Length()

            local source1 = vPlayer:GetAbsOrigin() + vPlayer:GetPropVector("localdata", "m_vecViewOffset[0]")
            local viewAngles = vPlayer:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]"):Forward()
            local destination = source1 + viewAngles * distance

            local forwardAngle = Math.PositionAngles(source1, destination)

            local targetangle = Math.PositionAngles(source1, pLocal:GetAbsOrigin())
            local fov = Math.AngleFov(forwardAngle, targetangle)


            --local posAngle = Math.PositionAngles(vPlayer, vPlayer:GetAbsOrigin() + Vector3(0, 0, viewheight))

            local hitboxes = pLocal:GetHitboxes()
            local hitbox = hitboxes[1]
            center = (pLocalView.z - ((hitbox[1] + hitbox[2]) * 0.5)):lengh() --(hitbox[1] + hitbox[2]) * 0.5
            local radius = 20 --(pLocalView - ((hitbox[1] + hitbox[2]) * 0.5)):Length()
            local closestPoint = nil
            local closestAngleDiff = math.huge
        
            if fov >= 30 then
                closestPoint1 = center
                goto continue
            end

            for i = 0, 359 do
                local angle = i * math.pi / 180
                local point = Vector3(center.x + radius * math.cos(angle), center.y + radius * math.sin(angle), center.z)
                local pointAngle = Math.PositionAngles(source1, point)
                local angleDiff = Math.AngleFov(forwardAngle, pointAngle)
        
                if angleDiff < closestAngleDiff then
                    closestPoint = point
                    closestAngleDiff = angleDiff
                end
            end

            closestPoint1 = closestPoint
        ::continue::
    end
end


local myfont = draw.CreateFont("Verdana", 16, 800) -- Create a font for doDraw

local function doDraw()
    if not pLocal or engine.Con_IsVisible() or engine.IsGameUIVisible() or closestPoint1 == nil then
        return
    end

    draw.SetFont(myfont)
    draw.Color(255, 255, 255, 255)
    local w, h = draw.GetScreenSize()
    --local screenPos = { w / 2 - 15, h / 2 + 35}

        --draw predicted local position with strafe prediction
        local screenPos = client.WorldToScreen(closestPoint1)
            if screenPos ~= nil then
                draw.Line( screenPos[1] + 10, screenPos[2], screenPos[1] - 10, screenPos[2])
                draw.Line( screenPos[1], screenPos[2] - 10, screenPos[1], screenPos[2] + 10)
            end

            local hitboxes = pLocal:GetHitboxes()
            local hitbox = hitboxes[1]
         --draw predicted local position with strafe prediction
        screenPos = client.WorldToScreen((hitbox[1] + hitbox[2]) * 0.5)
        if screenPos ~= nil then
            draw.Line( screenPos[1] + 10, screenPos[2], screenPos[1] - 10, screenPos[2])
            draw.Line( screenPos[1], screenPos[2] - 10, screenPos[1], screenPos[2] + 10)
        end

    --local rockets = entities.FindByClass("CTFProjectile_Rocket") -- Find all rockets
    for i, vPlayer in pairs(players) do
        if not vPlayer:IsAlive() or vPlayer:IsDormant() or pLocal:GetIndex() == vPlayer:GetIndex() then goto continue end

            local source1 = vPlayer:GetAbsOrigin() + vPlayer:GetPropVector("localdata", "m_vecViewOffset[0]")
            local viewAngles = vPlayer:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]"):Forward()
            local destination = source1 + viewAngles * distance

                local startScreenPos = client.WorldToScreen(source1)
                local endScreenPos = client.WorldToScreen(destination)

                if startScreenPos ~= nil and endScreenPos ~= nil then
                    draw.Line(startScreenPos[1], startScreenPos[2], endScreenPos[1], endScreenPos[2])
                end
        
        ::continue::
    end
end


callbacks.Register("Draw", doDraw)


--[[ Remove the vPlayernu when unloaded ]]--
local function OnUnload()                                -- Called when the script is unloaded
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end


--[[ Unregister previous callbacks ]]--
callbacks.Unregister("CreateMove", "MCT_CreateMoveAA")            -- Unregister the "CreateMove" callback
callbacks.Unregister("Unload", "MCT_UnloadAA")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "MCT_DrawAA")                        -- Unregister the "Draw" callback

--[[ Register callbacks ]]--
callbacks.Register("CreateMove", "MCT_CreateMoveAA", OnCreateMove)             -- Register the "CreateMove" callback
callbacks.Register("Unload", "MCT_UnloadAA", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("Draw", "MCT_DrawAA", doDraw)                               -- Register the "Draw" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded