local function NormalizeVector(vec)
    local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
    if length == 0 then
        return Vector3(0, 0, 0)
    end
    return Vector3(vec.x / length, vec.y / length, vec.z / length)
end

local function OnCreateMove(cmd)
    local pLocal = entities.GetLocalPlayer()
    if not pLocal then return end

    local pFlags = pLocal:GetPropInt("m_fFlags")
    local OnGround = (pFlags & FL_ONGROUND) == 1

    if not OnGround then return end
    if cmd.buttons & IN_ATTACK ~= 0 then return end -- Don't do anything if the player is shooting

    -- Combine forward and sideward movements into a single vector
    local moveDir = Vector3(cmd.forwardmove, cmd.sidemove, 0)

    -- Normalize the movement direction
    local normalizedMoveDir = NormalizeVector(moveDir)

    -- Create a separate vector for the look direction with the sidemove inverted
    local lookDir = Vector3(cmd.forwardmove, -cmd.sidemove, 0)

    -- Normalize the look direction
    local normalizedLookDir = NormalizeVector(lookDir)

    -- Calculate the desired aim direction based on normalized side and forward movement
    local lookAngle = math.atan(normalizedLookDir.y, normalizedLookDir.x)
    local aimAngle = math.deg(lookAngle)

    -- Get the current view angles
    local viewAngles = engine.GetViewAngles()

    -- If player is moving (normalizedMoveDir has length), adjust view angles to align with look direction
    if normalizedLookDir.x ~= 0 or normalizedLookDir.y ~= 0 then
        local correctedAngle = viewAngles.y + aimAngle

        -- Adjust the player's view angles to face the direction of look
        cmd:SetViewAngles(viewAngles.x, correctedAngle, viewAngles.z)
        -- Adjust forward and sidemove based on normalized direction
        cmd.forwardmove = normalizedMoveDir.x * 450
        cmd.sidemove = normalizedMoveDir.y * 450
    end

    --[[ Debug portion to calculate and display the highest acceleration
    local velocity = pLocal:EstimateAbsVelocity()
    local currentSpeed = velocity:Length2D()
    
    local acceleration = currentSpeed - previousSpeed
    if acceleration > highestAcceleration then
        highestAcceleration = acceleration
    end
    print(string.format("Highest Acceleration: %.2f units/tick", highestAcceleration))
    
    previousSpeed = currentSpeed
    ]]
end

callbacks.Unregister("CreateMove", "faststop_CreateMove")
callbacks.Register("CreateMove", "faststop_CreateMove", OnCreateMove)