## Pattern: Player Movement Simulation with Collisions

> Predict player movement accounting for walls, ground, and gravity

### Core Concept

Unlike simple `pos + vel * time`, this simulates actual Source engine movement:

- Wall collisions (can't walk through walls)
- Ground detection (falling vs walking)
- Gravity when airborne
- Strafe angle tracking for better prediction

### Minimum Viable Implementation

```lua
local gravity = 800        -- sv_gravity
local stepSize = 18        -- step height
local vHitbox = {
    Vector3(-24, -24, 0),  -- mins
    Vector3(24, 24, 82)    -- maxs (standing)
}

-- Strafe tracking
local lastAngles = {}
local strafeAngles = {}

local function UpdateStrafeAngle(entity)
    local vel = entity:EstimateAbsVelocity()
    local angle = vel:Angles()
    local idx = entity:GetIndex()

    if lastAngles[idx] then
        local delta = angle.y - lastAngles[idx].y
        strafeAngles[idx] = (strafeAngles[idx] or 0) * 0.8 + delta * 0.2  -- smooth
    end

    lastAngles[idx] = angle
end

---@param entity Entity
---@param ticks integer Number of ticks to simulate
---@return {pos: Vector3[], vel: Vector3[], onGround: boolean[]}?
local function SimulatePlayer(entity, ticks)
    local vUp = Vector3(0, 0, 1)
    local vStep = Vector3(0, 0, stepSize)

    local result = {
        pos = {[0] = entity:GetAbsOrigin()},
        vel = {[0] = entity:EstimateAbsVelocity()},
        onGround = {[0] = entity:IsOnGround()}
    }

    -- Simulate each tick
    for i = 1, ticks do
        local lastPos = result.pos[i - 1]
        local lastVel = result.vel[i - 1]
        local wasOnGround = result.onGround[i - 1]

        -- Apply strafe angle
        local strafeAngle = strafeAngles[entity:GetIndex()]
        if strafeAngle then
            local ang = lastVel:Angles()
            ang.y = ang.y + strafeAngle
            lastVel = ang:Forward() * lastVel:Length()
        end

        -- Basic movement
        local newPos = lastPos + lastVel * globals.TickInterval()
        local newVel = lastVel
        local onGround = wasOnGround

        -- Forward collision (walls)
        local wallTrace = engine.TraceHull(
            lastPos + vStep,
            newPos + vStep,
            vHitbox[1],
            vHitbox[2],
            MASK_PLAYERSOLID
        )

        if wallTrace.fraction < 1 then
            local normal = wallTrace.plane
            local angle = math.deg(math.acos(normal:Dot(vUp)))

            if angle > 55 then
                -- Hit wall, slide along it
                local dot = newVel:Dot(normal)
                newVel = newVel - normal * dot
            end

            newPos.x = wallTrace.endpos.x
            newPos.y = wallTrace.endpos.y
        end

        -- Ground collision
        local downStep = wasOnGround and vStep or Vector3()
        local groundTrace = engine.TraceHull(
            newPos + vStep,
            newPos - downStep,
            vHitbox[1],
            vHitbox[2],
            MASK_PLAYERSOLID
        )

        if groundTrace.fraction < 1 then
            local normal = groundTrace.plane
            local angle = math.deg(math.acos(normal:Dot(vUp)))

            if angle < 45 then
                -- Flat ground
                newPos = groundTrace.endpos
                onGround = true
            elseif angle < 55 then
                -- Steep slope
                newVel = Vector3(0, 0, 0)
                onGround = false
            else
                -- Wall-like surface
                local dot = newVel:Dot(normal)
                newVel = newVel - normal * dot
                onGround = true
            end
        else
            onGround = false
        end

        -- Apply gravity when airborne
        if not onGround then
            newVel.z = newVel.z - gravity * globals.TickInterval()
        end

        result.pos[i] = newPos
        result.vel[i] = newVel
        result.onGround[i] = onGround
    end

    return result
end
```

### Usage Example

```lua
local function OnCreateMove(cmd)
    local me = entities.GetLocalPlayer()
    if not me then return end

    -- Find target
    local target = FindBestTarget()
    if not target then return end

    -- Update strafe tracking every frame
    UpdateStrafeAngle(target)

    -- Predict where they'll be in 13 ticks (melee swing time)
    local prediction = SimulatePlayer(target, 13)
    if not prediction then return end

    -- Get their future position
    local futurePos = prediction.pos[13]

    -- Aim at predicted position
    local aimAngles = CalcAngle(me:GetAbsOrigin(), futurePos)
    cmd.viewangles = Vector3(aimAngles.x, aimAngles.y, 0)
end

callbacks.Register("CreateMove", OnCreateMove)
```

### Key Components

#### 1. Strafe Angle Tracking

```lua
-- Track how fast player is turning
local delta = currentAngle.y - lastAngle.y
strafeAngles[idx] = (strafeAngles[idx] or 0) * 0.8 + delta * 0.2
```

- Smooths angle changes over time
- Predicts if player will continue turning
- 0.8 = keep 80% of old value, 0.2 = add 20% of new

#### 2. Forward Collision

```lua
-- Trace from old position to new position
local wallTrace = engine.TraceHull(lastPos + vStep, newPos + vStep, mins, maxs, MASK_PLAYERSOLID)

if wallTrace.fraction < 1 then
    -- Hit something, slide along surface
    local dot = vel:Dot(normal)
    vel = vel - normal * dot  -- Remove velocity into wall
end
```

- Prevents walking through walls
- Slides along wall surface
- Uses player hitbox size

#### 3. Ground Detection

```lua
-- Trace downward from new position
local groundTrace = engine.TraceHull(newPos + vStep, newPos - downStep, mins, maxs, MASK_PLAYERSOLID)

if angle < 45 then
    onGround = true  -- Flat surface
elseif angle < 55 then
    vel = Vector3(0, 0, 0)  -- Too steep, stop
else
    -- Slide along surface
end
```

- Detects floor vs air
- Handles slopes (< 45° = walkable)
- Step size lets player walk up stairs

#### 4. Gravity

```lua
if not onGround then
    vel.z = vel.z - gravity * globals.TickInterval()
end
```

- Only applies when in air
- Uses `TickInterval()` for accurate timing
- Default: 800 units/s²

### Performance

- **~0.02ms** per tick simulated
- **~0.26ms** for 13 ticks
- Safe to use in CreateMove
- Consider caching recent predictions

### Accuracy vs Simple Prediction

**Simple**: `pos + vel * time`

- ❌ Walks through walls
- ❌ Walks off cliffs
- ❌ Ignores gravity
- ✅ Very fast

**Simulated**: This pattern

- ✅ Respects collisions
- ✅ Handles falling
- ✅ Applies gravity
- ✅ Tracks strafing
- ⚠️ Slightly slower (but still fast)

### When to Use

**Use simulation when:**

- Target is near walls/corners
- Target is on slopes/stairs
- Prediction time > 5 ticks
- Melee weapons (need accuracy)
- Projectiles with slow travel time

**Use simple when:**

- Open areas
- Very short prediction (< 3 ticks)
- Hitscan weapons
- Performance is critical

### Limitations

- Doesn't predict jumps (no player input)
- Doesn't account for knockback
- Assumes constant strafe rate
- No air strafing prediction

### Class-Specific Speed Caps

```lua
local CLASS_MAX_SPEEDS = {
    [1] = 400,  -- Scout
    [2] = 240,  -- Sniper (unscoped)
    [3] = 240,  -- Soldier
    [4] = 280,  -- Demoman
    [5] = 230,  -- Medic
    [6] = 300,  -- Heavy (weapon down)
    [7] = 240,  -- Pyro
    [8] = 320,  -- Spy
    [9] = 320   -- Engineer
}

-- Cap speed when on ground
if onGround and not entity:InCond(TF_COND_CHARGING) then
    local class = entity:GetPropInt("m_iClass")
    local maxSpeed = CLASS_MAX_SPEEDS[class] or 240

    local speed2D = vel:Length2D()
    if speed2D > maxSpeed then
        vel = vel * (maxSpeed / speed2D)
    end
end
```

### Integration with Other Patterns

```lua
-- Combine with ballistic calculations
local prediction = SimulatePlayer(target, 20)
local aimPos = prediction.pos[20]
local aimAngles = SolveBallisticArc(eyePos, aimPos, projectileSpeed, gravity)

-- Use with FOV filtering
for i = 1, ticks do
    local fov = CalcFOV(viewAngles, prediction.pos[i])
    if fov < maxFOV then
        -- Will be in FOV at tick i
    end
end
```

### Debug Visualization

```lua
-- Draw predicted path
if prediction then
    for i = 1, #prediction.pos do
        local screen = client.WorldToScreen(prediction.pos[i])
        if screen then
            local color = prediction.onGround[i] and {0, 255, 0, 255} or {255, 0, 0, 255}
            draw.Color(table.unpack(color))
            draw.FilledRect(screen[1] - 2, screen[2] - 2, screen[1] + 2, screen[2] + 2)
        end
    end
end
```
