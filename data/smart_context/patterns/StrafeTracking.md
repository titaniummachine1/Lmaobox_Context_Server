## Pattern: Strafe Angle Tracking

> Track how fast entities are turning for curved movement prediction

### Purpose

Players don't always move in straight lines. Strafe tracking predicts angular velocity (turn rate) to forecast curved paths.

### Implementation

```lua
-- Per-entity state
local lastVelocityAngles = {}  -- Previous frame's velocity direction
local strafeRates = {}         -- Predicted angular velocity (degrees/tick)

---@param entity Entity
local function UpdateStrafeTracking(entity)
    local vel = entity:EstimateAbsVelocity()
    if not vel then return end

    local currentAngle = vel:Angles()
    local idx = entity:GetIndex()

    if lastVelocityAngles[idx] then
        -- How much did they turn this frame?
        local angleDelta = currentAngle.y - lastVelocityAngles[idx].y

        -- Exponential moving average: smooth out noise
        -- 80% previous + 20% new
        strafeRates[idx] = (strafeRates[idx] or 0) * 0.8 + angleDelta * 0.2
    end

    lastVelocityAngles[idx] = currentAngle
end
```

### Usage in Prediction

```lua
---@param entity Entity
---@param ticks integer
---@return Vector3
local function PredictWithStrafe(entity, ticks)
    local pos = entity:GetAbsOrigin()
    local vel = entity:EstimateAbsVelocity()

    -- Apply cumulative turn
    local strafeRate = strafeRates[entity:GetIndex()]
    if strafeRate then
        local velAngle = vel:Angles()
        velAngle.y = velAngle.y + strafeRate * ticks
        vel = velAngle:Forward() * vel:Length()
    end

    return pos + vel * globals.TickInterval() * ticks
end
```

### Per-Tick Application

For simulation, apply strafe each tick:

```lua
for tick = 1, ticks do
    local strafeRate = strafeRates[entity:GetIndex()]
    if strafeRate then
        local velAngle = velocity:Angles()
        velAngle.y = velAngle.y + strafeRate  -- Apply per tick
        velocity = velAngle:Forward() * velocity:Length()
    end

    -- Continue simulation...
end
```

### Smoothing Factor

```lua
strafeRates[idx] = oldValue * 0.8 + newDelta * 0.2
```

| Weight                | Effect                    |
| --------------------- | ------------------------- |
| Higher old (0.9, 0.1) | Smoother, slower to adapt |
| Balanced (0.8, 0.2)   | Good default              |
| Higher new (0.6, 0.4) | More responsive, noisier  |

### When to Update

```lua
-- Update every frame for tracked entities
local function OnCreateMove(cmd)
    for _, entity in pairs(trackedEntities) do
        UpdateStrafeTracking(entity)
    end

    -- Now predictions use latest strafe data
end
```

### Visualization

```lua
local function DrawStrafeInfo(entity)
    local rate = strafeRates[entity:GetIndex()]
    if not rate then return end

    local screen = client.WorldToScreen(entity:GetAbsOrigin())
    if screen then
        draw.Color(255, 255, 255, 255)
        draw.Text(screen[1], screen[2], string.format("Strafe: %.1f°/tick", rate))
    end
end
```

### Limitations

- Assumes constant turn rate
- Can't predict intentional direction changes
- Network interpolation adds noise
- Works best for smooth strafing patterns

### Related

- See `patterns/MovementPrediction.md` for full movement simulation
- See `Vector3/Angles.md` for velocity to angle conversion
