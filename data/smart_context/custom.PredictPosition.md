## Pattern: Basic Linear Prediction

> Simple position prediction without collision detection

### Core Formula

```lua
futurePosition = currentPosition + velocity * time
```

**Note**: For accurate prediction with collision detection, see `patterns/PlayerSimulation.md`

### Basic Implementation

```lua
local function PredictPosition(entity, seconds)
    local pos = entity:GetAbsOrigin()
    local vel = entity:EstimateAbsVelocity()
    return pos + vel * seconds
end
```

### Practical Examples

#### Melee swing prediction (tick-based)

```lua
-- Predict where player will be in N ticks
local function PredictSwingTarget(target, swingTicks)
    local pos = target:GetAbsOrigin()
    local vel = target:EstimateAbsVelocity()

    -- Convert ticks to seconds (66.67 ticks per second in TF2)
    local time = swingTicks / 66.67

    return pos + vel * time
end

-- Usage in melee aimbot
local swingTime = 13  -- ticks until hit
local futurePos = PredictSwingTarget(target, swingTime)
local aimAngles = CalculateAngles(eyePos, futurePos)
```

#### Projectile lead with travel time

```lua
-- Iterative prediction for accurate lead
local function PredictWithTravelTime(target, shootPos, projectileSpeed)
    local targetPos = target:GetAbsOrigin()
    local targetVel = target:EstimateAbsVelocity()

    if not targetVel then
        return targetPos
    end

    -- Iterate to converge on accurate prediction
    for i = 1, 3 do
        local distance = (targetPos - shootPos):Length()
        local travelTime = distance / projectileSpeed
        targetPos = target:GetAbsOrigin() + targetVel * travelTime
    end

    return targetPos
end
```

#### Ground-only prediction (no vertical)

```lua
-- Predict ground movement, ignore jumping
local function PredictGroundPosition(entity, time)
    local pos = entity:GetAbsOrigin()
    local vel = entity:EstimateAbsVelocity()

    vel.z = 0  -- Ignore vertical velocity

    return pos + vel * time
end
```

#### Network latency compensation

```lua
-- Account for ping when predicting
local function PredictWithLatency(entity, baseTicks)
    local netchannel = clientstate.GetNetChannel()
    if not netchannel then return entity:GetAbsOrigin() end

    local latency = netchannel:GetLatency(E_Flows.FLOW_INCOMING)
    local totalTime = (baseTicks / 66.67) + latency

    local pos = entity:GetAbsOrigin()
    local vel = entity:EstimateAbsVelocity()

    return pos + vel * totalTime
end
```

### When to Use

**Good for:**

- Melee weapons (short time, <200ms)
- Projectiles with fast travel (<500ms)
- Quick estimates
- Performance-critical code

**Not good for:**

- Long predictions (>1 second)
- Players changing direction
- Players in air (gravity)
- Players on slopes/stairs

### Accuracy Tips

1. **Keep time short**: Prediction degrades over time
2. **Iterate for projectiles**: Refine distance estimate 2-3 times
3. **Check velocity validity**: `EstimateAbsVelocity()` can return nil
4. **Add latency**: Account for network delay

### Complete Melee Example

```lua
local function GetMeleeTarget(maxDistance, swingTicks)
    local me = entities.GetLocalPlayer()
    if not me then return nil end

    local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local myTeam = me:GetTeamNumber()

    local bestTarget = nil
    local bestFov = 9999

    for _, player in pairs(entities.FindByClass("CTFPlayer")) do
        if player:IsAlive() and not player:IsDormant() and player:GetTeamNumber() ~= myTeam then
            -- Predict where they'll be
            local currentPos = player:GetAbsOrigin()
            local vel = player:EstimateAbsVelocity()

            local futurePos = currentPos
            if vel then
                local time = swingTicks / 66.67
                futurePos = currentPos + vel * time
            end

            -- Check distance
            local dist = (futurePos - eyePos):Length()
            if dist <= maxDistance then
                -- Check FOV
                local angles = CalculateAngles(eyePos, futurePos)
                local fov = GetAngleFOV(engine.GetViewAngles(), angles)

                if fov < bestFov then
                    bestFov = fov
                    bestTarget = player
                end
            end
        end
    end

    return bestTarget
end
```

### Performance

- **Very fast**: 3 function calls + vector math
- **~0.001ms** per prediction
- Safe to use in CreateMove (runs 66+ times per second)

### Limitations

- **Linear only**: Doesn't account for acceleration
- **No collision**: Doesn't check walls/obstacles
- **No gravity**: Assumes constant velocity
- **No strafing**: Doesn't predict direction changes

For complex prediction (air movement, strafing, etc.), use full player simulation instead.
