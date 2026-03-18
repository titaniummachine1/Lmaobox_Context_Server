-- Constants for minimum and maximum speed
local MIN_SPEED = 10  -- Minimum speed to avoid jittery movements
local MAX_SPEED = 650 -- Maximum speed the player can move

local MoveDir = Vector3(0,0,0) -- Variable to store the movement direction
local pLocal = entities.GetLocalPlayer()  -- Variable to store the local player

local function NormalizeVector(vector)
    local length = math.sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    if length == 0 then
        return Vector3(0, 0, 0)
    else
        return Vector3(vector.x / length, vector.y / length, vector.z / length)
    end
end

-- Function to compute the move direction
local function ComputeMove(pCmd, a, b)
    local diff = (b - a)
    if diff:Length() == 0 then return Vector3(0, 0, 0) end

    local x = diff.x
    local y = diff.y
    local vSilent = Vector3(x, y, 0)

    local ang = vSilent:Angles()
    local cPitch, cYaw, cRoll = pCmd:GetViewAngles()
    local yaw = math.rad(ang.y - cYaw)
    local pitch = math.rad(ang.x - cPitch)
    local move = Vector3(math.cos(yaw) * MAX_SPEED, -math.sin(yaw) * MAX_SPEED, 0)

    return move
end

-- Function to make the player walk to a destination smoothly
local function WalkTo(pCmd, pLocal, pDestination)
    local localPos = pLocal:GetAbsOrigin()
    local distVector = pDestination - localPos
    local dist = distVector:Length()

    -- Determine the speed based on the distance
    local speed = math.max(MIN_SPEED, math.min(MAX_SPEED, dist))

    -- If distance is greater than 1, proceed with walking
    if dist > 1 then
        local result = ComputeMove(pCmd, localPos, pDestination)

        -- Scale down the movements based on the calculated speed
        local scaleFactor = speed / MAX_SPEED
        pCmd:SetForwardMove(result.x * scaleFactor)
        pCmd:SetSideMove(result.y * scaleFactor)
    else
        pCmd:SetForwardMove(0)
        pCmd:SetSideMove(0)
    end
end

local function GetMoveDir()
    local moveSpeed = 450 -- Change this to your preferred speed
    -- Handle side movement keys
    if input.IsButtonDown(KEY_A) then
        MoveDir.x = -moveSpeed
    end

    if input.IsButtonDown(KEY_D) then
        MoveDir.x = moveSpeed
    end

    -- Handle forward movement keys
    if input.IsButtonDown(KEY_W) then
        MoveDir.y = moveSpeed
    end

    if input.IsButtonDown(KEY_S) then
        MoveDir.y = -moveSpeed
    end
end

local function FastStop(cmd, OnGround, velocity)
    if not OnGround then return end -- If the player is not on ground, do nothing

    -- If no keys are held, stop movement immediately by moving in the opposite direction of current velocity
    if MoveDir:Length() < 10 and velocity:Length() > 10 then
        local oppositePoint = pLocal:GetAbsOrigin() - velocity
        WalkTo(cmd, pLocal, oppositePoint)
        return
    end
end

local function FastAccel(cmd, OnGround, velocity)
    if not OnGround then return end -- If the player is not on ground, do nothing

    -- If no keys are held, stop movement immediately by moving in the opposite direction of current velocity
    if MoveDir:Length() > 0 then
        local normalizedMoveDir = NormalizeVector(MoveDir) * 450
        cmd.forwardmove = normalizedMoveDir.y
        cmd.sidemove = normalizedMoveDir.x
        return
    end
end

local function handleMovement(cmd)
    pLocal = entities.GetLocalPlayer()
    if not pLocal then return end

    local pFlags = pLocal:GetPropInt("m_fFlags")
    local OnGround = (pFlags & FL_ONGROUND) == 1
    local velocity = pLocal:EstimateAbsVelocity()
    MoveDir = Vector3(0,0,0)
    GetMoveDir()

    FastStop(cmd, OnGround, velocity)
    if pLocal:EstimateAbsVelocity():Length() > 10 then print(pLocal:EstimateAbsVelocity():Length()) end 
    FastAccel(cmd, OnGround, velocity)
end



local function dirArrow(pLocal_pos, direction, length)
    if not direction then return end

    -- Normalize the direction vector
    direction = NormalizeVector(direction)

    -- Get the yaw angle from the view angles
    local viewAngles = engine.GetViewAngles()
    local yaw = viewAngles.yaw

    -- Rotate the direction vector by the yaw angle
    local cosYaw = math.cos(math.rad(yaw - 90))
    local sinYaw = math.sin(math.rad(yaw - 90))
    direction = Vector3(
        direction.x * cosYaw - direction.y * sinYaw,
        direction.x * sinYaw + direction.y * cosYaw,
        0
    )

    local screenPos = client.WorldToScreen(pLocal_pos)
    if screenPos ~= nil then
        local endPoint = pLocal_pos + direction * length
        local endPoint2 = pLocal_pos + direction * (length * 0.85)
        local screenPos1 = client.WorldToScreen(endPoint)
        if screenPos1 ~= nil then
            draw.Line(screenPos[1], screenPos[2], screenPos1[1], screenPos1[2])
            local perpendicularDirection = Vector3(-direction.y, direction.x, 0)
            local perpendicularEndPoint1 = endPoint2 + perpendicularDirection * (length * 0.1) 
            local perpendicularEndPoint2 = endPoint2 - perpendicularDirection * (length * 0.1) 
            local screenPos2 = client.WorldToScreen(perpendicularEndPoint1)
            local screenPos3 = client.WorldToScreen(perpendicularEndPoint2)
            if screenPos2 ~= nil and screenPos3 ~= nil then
                draw.Line(screenPos2[1], screenPos2[2], screenPos3[1], screenPos3[2])
                draw.Line(screenPos1[1], screenPos1[2], screenPos3[1], screenPos3[2])
                draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
            end
        end
    end
end

local function OnDraw()
    -- Inside your OnDraw function
    if not pLocal then return end
    local pLocalPos = pLocal:GetAbsOrigin()
    draw.Color(255, 0, 0, 255)
    if MoveDir then
        dirArrow(pLocalPos, MoveDir, 50)
    end
end

callbacks.Unregister("CreateMove", "handleMovement1")
callbacks.Register("CreateMove", "handleMovement1", handleMovement)

callbacks.Unregister("Draw", "accuratemoveD.Draw")
callbacks.Register("Draw", "accuratemoveD", OnDraw)



