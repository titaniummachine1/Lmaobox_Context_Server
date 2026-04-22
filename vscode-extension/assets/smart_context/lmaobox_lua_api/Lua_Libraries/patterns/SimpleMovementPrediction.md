## Pattern: Simple Movement Prediction

> Basic tick-by-tick movement simulation with collision detection

### Use Case

Good enough for most situations - handles walls, ground, gravity. Simpler than full physics.

### Implementation

```lua
-- Get server cvars dynamically
local sv_gravity = client.GetConVar("sv_gravity")
local sv_stepsize = client.GetConVar("sv_stepsize")
local sv_friction = client.GetConVar("sv_friction")
local sv_stopspeed = client.GetConVar("sv_stopspeed")

local gravity = sv_gravity or 800
local stepSize = sv_stepsize or 18
local friction = sv_friction or 4
local stopSpeed = sv_stopspeed or 100

-- TF2 class max speeds (units/sec)
local MAX_SPEEDS = {
    [1] = 300,  -- Scout
    [2] = 240,  -- Sniper
    [3] = 240,  -- Soldier
    [4] = 280,  -- Demoman
    [5] = 230,  -- Medic
    [6] = 300,  -- Heavy (spinning reduces this)
    [7] = 240,  -- Pyro
    [8] = 300,  -- Spy
    [9] = 240   -- Engineer
}

-- Strafe tracking (optional but recommended)
local lastVelocityAngles = {}
local strafeRates = {}

local function UpdateStrafeTracking(entity)
    local vel = entity:EstimateAbsVelocity()
    if not vel then return end

    local currentAngle = vel:Angles()
    local idx = entity:GetIndex()

    if lastVelocityAngles[idx] then
        local angleDelta = currentAngle.y - lastVelocityAngles[idx].y
        strafeRates[idx] = (strafeRates[idx] or 0) * 0.8 + angleDelta * 0.2
    end

    lastVelocityAngles[idx] = currentAngle
end

-- Ground check (more reliable than entity:IsOnGround)
local function IsOnGround(pos, mins, maxs)
    local down = pos - Vector3(0, 0, 2)
    local trace = engine.TraceHull(pos, down, mins, maxs, MASK_PLAYERSOLID)
    return trace and trace.fraction < 1.0 and not trace.startsolid and trace.plane and trace.plane.z >= 0.7
end

-- Apply friction (massively improves accuracy)
local function ApplyFriction(velocity, isOnGround, dt)
    local speed = velocity:Length()
    if speed < 0.01 then return end

    if isOnGround then
        local control = speed < stopSpeed and stopSpeed or speed
        local drop = control * friction * dt

        local newspeed = math.max(0, speed - drop)
        if newspeed ~= speed then
            local scale = newspeed / speed
            velocity.x = velocity.x * scale
            velocity.y = velocity.y * scale
            velocity.z = velocity.z * scale
        end
    end
end

---@param entity Entity
---@param ticks integer
---@return {pos: Vector3[], vel: Vector3[], onGround: boolean[]}?
local function SimulateMovement(entity, ticks)
    local mins, maxs = entity:GetMins(), entity:GetMaxs()
    local vUp = Vector3(0, 0, 1)
    local vStep = Vector3(0, 0, stepSize)

    local result = {
        pos = {[0] = entity:GetAbsOrigin()},
        vel = {[0] = entity:EstimateAbsVelocity()},
        onGround = {[0] = entity:IsOnGround()}
    }

    if not result.vel[0] then
        return nil
    end

    -- Get max speed for this class
    local class = entity:GetPropInt("m_iClass")
    local maxSpeed = MAX_SPEEDS[class] or 300

    for tick = 1, ticks do
        local pos = result.pos[tick - 1]
        local vel = result.vel[tick - 1]
        local wasOnGround = result.onGround[tick - 1]

        -- Apply friction (huge accuracy improvement)
        ApplyFriction(vel, wasOnGround, globals.TickInterval())

        -- Apply strafe angle
        local strafeRate = strafeRates[entity:GetIndex()]
        if strafeRate then
            local ang = vel:Angles()
            ang.y = ang.y + strafeRate
            vel = ang:Forward() * vel:Length()
        end

        -- Calculate new position
        local newPos = pos + vel * globals.TickInterval()
        local newVel = vel
        local onGround = wasOnGround

        -- Forward collision (walls)
        local trace = engine.TraceHull(
            pos + vStep,
            newPos + vStep,
            mins,
            maxs,
            MASK_PLAYERSOLID
        )

        if trace.fraction < 1 then
            local normal = trace.plane
            local angle = math.deg(math.acos(normal:Dot(vUp)))

            if angle > 55 then
                -- Wall - slide along it
                local dot = newVel:Dot(normal)
                newVel = newVel - normal * dot

                -- Zero tiny components
                if math.abs(newVel.x) < 0.01 then newVel.x = 0 end
                if math.abs(newVel.y) < 0.01 then newVel.y = 0 end
                if math.abs(newVel.z) < 0.01 then newVel.z = 0 end
            end

            newPos.x = trace.endpos.x
            newPos.y = trace.endpos.y
        end

        -- Ground collision
        local downStep = wasOnGround and vStep or Vector3()
        local groundTrace = engine.TraceHull(
            newPos + vStep,
            newPos - downStep,
            mins,
            maxs,
            MASK_PLAYERSOLID
        )

        if groundTrace.fraction < 1 then
            local normal = groundTrace.plane
            local angle = math.deg(math.acos(normal:Dot(vUp)))

            if angle < 45 then
                newPos = groundTrace.endpos
                onGround = true
            elseif angle < 55 then
                newVel = Vector3(0, 0, 0)
                onGround = false
            else
                local dot = newVel:Dot(normal)
                newVel = newVel - normal * dot
                onGround = true
            end
        else
            onGround = false
        end

        -- Gravity
        if not onGround then
            newVel.z = newVel.z - gravity * globals.TickInterval()
        end

        -- Clamp to max speed (prevents unrealistic velocity buildup)
        local speed = newVel:Length()
        if speed > maxSpeed then
            local scale = maxSpeed / speed
            newVel.x = newVel.x * scale
            newVel.y = newVel.y * scale
        end

        -- Use better ground check
        onGround = IsOnGround(newPos, mins, maxs)

        result.pos[tick] = newPos
        result.vel[tick] = newVel
        result.onGround[tick] = onGround
    end

    return result
end
```

### Usage

```lua
local function OnCreateMove(cmd)
    local target = GetTarget()
    if not target then return end

    UpdateStrafeTracking(target)

    local prediction = SimulateMovement(target, 15)
    if not prediction then return end

    local futurePos = prediction.pos[15]

    -- Aim at predicted position
    cmd.viewangles = Vector3(CalcAngle(myPos, futurePos))
end
```

### Improvements Over Basic Prediction

✅ Friction modeling (huge accuracy boost)
✅ Max speed clamping (prevents unrealistic velocities)
✅ Better ground detection (more reliable)
✅ Strafe tracking
✅ Dynamic CVars

### Limitations

- Simple single-plane collision (doesn't handle corners perfectly)
- No acceleration modeling
- No crease sliding

For perfect corner/edge handling, use `AdvancedMovementPrediction.md`.
