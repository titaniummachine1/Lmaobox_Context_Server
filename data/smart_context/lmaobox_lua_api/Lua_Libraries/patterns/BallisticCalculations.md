## Pattern: Ballistic Calculations for Projectile Aimbots

> Physics-based projectile arc calculations for aiming at moving targets with gravity

### Context

TF2 projectile weapons (rockets, grenades, arrows, etc.) have travel time and gravity. Accurate aiming requires solving ballistic trajectory equations to calculate the required launch angle.

### Physics Background

The ballistic equation derives from kinematic motion:
- Horizontal: `x = v * cos(θ) * t`
- Vertical: `y = v * sin(θ) * t - 0.5 * g * t²`

Solving for launch angle θ gives two solutions (high arc and low arc):
- Low arc: `θ = atan((v² - √discriminant) / (g * dx))`
- High arc: `θ = atan((v² + √discriminant) / (g * dx))`

Where discriminant: `v⁴ - g(g*dx² + 2*dy*v²)`

### Complete Implementation

```lua
local Math = {}

local M_RADPI = 180 / math.pi -- rad to deg conversion

local function isNaN(x)
    return x ~= x
end

local function NormalizeVector(vec)
    return vec / vec:Length()
end

---@param p0 Vector3 -- start position
---@param p1 Vector3 -- target position
---@param speed number -- projectile speed
---@param gravity number -- gravity constant
---@return EulerAngles?, number? -- Euler angles or nil
function Math.SolveBallisticArc(p0, p1, speed, gravity)
    local diff = p1 - p0
    local dx = diff:Length2D()  -- horizontal distance
    local dy = diff.z           -- vertical distance
    local speed2 = speed * speed
    local g = gravity
    
    -- Check if solution exists
    local root = speed2 * speed2 - g * (g * dx * dx + 2 * dy * speed2)
    if root < 0 then
        return nil -- no solution (target too far or gravity too high)
    end
    
    local sqrt_root = math.sqrt(root)
    local angle = math.atan((speed2 - sqrt_root) / (g * dx)) -- low arc
    
    -- Calculate horizontal direction (yaw)
    local yaw = math.atan(diff.y, diff.x) * M_RADPI
    
    -- Convert pitch from radians to degrees
    -- Negative because upward is negative pitch in Source engine
    local pitch = -angle * M_RADPI
    
    return EulerAngles(pitch, yaw, 0)
end

-- Returns both low and high arc solutions
---@param p0 Vector3
---@param p1 Vector3
---@param speed number
---@param gravity number
---@return EulerAngles|nil lowArc, EulerAngles|nil highArc
function Math.SolveBallisticArcBoth(p0, p1, speed, gravity)
    local diff = p1 - p0
    local dx = math.sqrt(diff.x * diff.x + diff.y * diff.y)
    
    if dx == 0 then
        return nil, nil -- directly above/below
    end
    
    local dy = diff.z
    local speed2 = speed * speed
    local g = gravity
    local root = speed2 * speed2 - g * (g * dx * dx + 2 * dy * speed2)
    
    if root < 0 then
        return nil, nil
    end
    
    local sqrt_root = math.sqrt(root)
    local theta_low = math.atan((speed2 - sqrt_root) / (g * dx))
    local theta_high = math.atan((speed2 + sqrt_root) / (g * dx))
    
    local yaw = math.atan(diff.y, diff.x) * M_RADPI
    local pitch_low = -theta_low * M_RADPI
    local pitch_high = -theta_high * M_RADPI
    
    return EulerAngles(pitch_low, yaw, 0), EulerAngles(pitch_high, yaw, 0)
end

-- Calculate flight time for projectile
function Math.GetBallisticFlightTime(p0, p1, speed, gravity)
    local diff = p1 - p0
    local dx = math.sqrt(diff.x ^ 2 + diff.y ^ 2)
    local dy = diff.z
    local speed2 = speed * speed
    local g = gravity
    
    local discriminant = speed2 * speed2 - g * (g * dx * dx + 2 * dy * speed2)
    if discriminant < 0 then
        return nil
    end
    
    local sqrt_discriminant = math.sqrt(discriminant)
    local angle = math.atan((speed2 - sqrt_discriminant) / (g * dx))
    
    -- Flight time calculation
    local vz = speed * math.sin(angle)
    local flight_time = (vz + math.sqrt(vz * vz + 2 * g * dy)) / g
    
    return flight_time
end

-- Simple distance-based time estimate
function Math.EstimateTravelTime(shootPos, targetPos, speed)
    local distance = (targetPos - shootPos):Length2D()
    return distance / speed
end

Math.NormalizeVector = NormalizeVector

return Math
```

### Usage Example: Complete Projectile Aimbot

```lua
local Math = require("utils.math")

local function OnCreateMove(cmd)
    local player = entities.GetLocalPlayer()
    if not player then return end
    
    local weapon = player:GetPropEntity("m_hActiveWeapon")
    if not weapon then return end
    
    -- Get projectile info for current weapon
    local speed = 1100  -- rocket speed (varies by weapon)
    local _, sv_gravity = client.GetConVar("sv_gravity")
    local gravity = sv_gravity * 0.5  -- TF2 projectile gravity scaling
    
    -- Get aim position
    local eyePos = player:GetAbsOrigin() + player:GetPropVector("localdata", "m_vecViewOffset[0]")
    
    -- Find target
    local target = GetBestTarget() -- your target selection logic
    if not target then return end
    
    -- Predict target position
    local targetPos = target:GetAbsOrigin()
    local targetVel = target:EstimateAbsVelocity()
    if targetVel then
        local estimatedTime = Math.EstimateTravelTime(eyePos, targetPos, speed)
        targetPos = targetPos + targetVel * estimatedTime
    end
    
    -- Calculate ballistic arc
    local angle = Math.SolveBallisticArc(eyePos, targetPos, speed, gravity)
    
    if angle then
        -- Apply aim
        cmd.viewangles = Vector3(angle:Unpack())
        cmd.buttons = cmd.buttons | IN_ATTACK
    end
end

callbacks.Register("CreateMove", OnCreateMove)
```

### Key Concepts

#### 1. Gravity Scaling

```lua
local _, sv_gravity = client.GetConVar("sv_gravity")
local projectile_gravity = sv_gravity * 0.5  -- TF2 uses 50% gravity for projectiles
```

- **Default sv_gravity**: 800
- **Projectile gravity**: 400 (sv_gravity * 0.5)
- Some weapons override this (e.g., Loch-n-Load)

#### 2. Low Arc vs High Arc

```lua
local low_arc, high_arc = Math.SolveBallisticArcBoth(eyePos, targetPos, speed, gravity)
```

- **Low arc**: Flatter trajectory, faster, preferred for combat
- **High arc**: Higher trajectory, longer flight time, for indirect fire
- Both mathematically valid, low arc is almost always better

#### 3. Solution Validity

```lua
if root < 0 then
    return nil  -- No solution exists
end
```

No solution when:
- Target too far for given speed/gravity
- Target directly above (dx = 0)
- Gravity too high relative to speed

#### 4. Coordinate System

- **Z-axis**: Positive = Up
- **Pitch**: Negative = Looking up (Source engine convention)
- **Yaw**: Standard horizontal rotation
- **2D distance**: Use `Length2D()` for horizontal component

### Weapon-Specific Parameters

Common TF2 projectile speeds:

```lua
local PROJECTILE_SPEEDS = {
    -- Soldier
    rocket = 1100,
    rocket_directhit = 1980,
    
    -- Demoman  
    grenade = 1217,
    stickybomb = 925,
    
    -- Pyro
    flare = 2000,
    
    -- Medic
    crossbow = 2400,
    
    -- Sniper
    huntsman_min = 1800,
    huntsman_max = 2600,  -- based on charge
}
```

### Advanced: Lead Target with Velocity Prediction

```lua
local function PredictTargetPosition(target, shootPos, speed, gravity)
    local targetPos = target:GetAbsOrigin()
    local targetVel = target:EstimateAbsVelocity()
    
    if not targetVel then
        return targetPos
    end
    
    -- Iterative prediction (converges quickly)
    for i = 1, 3 do
        local estimatedTime = Math.EstimateTravelTime(shootPos, targetPos, speed)
        targetPos = target:GetAbsOrigin() + targetVel * estimatedTime
    end
    
    return targetPos
end
```

### NaN Handling

Division by zero or invalid math can produce NaN:

```lua
local function isNaN(x)
    return x ~= x  -- IEEE 754: NaN != NaN
end

local pitch = calculatePitch()
if isNaN(pitch) then
    pitch = 0  -- Sanitize to prevent propagation
end
```

### Performance Considerations

- **Cache constants**: `M_RADPI`, `speed²`, etc.
- **Minimize sqrt calls**: Store discriminant
- **2D distance**: `Length2D()` is cheaper than `Length()`
- **Prediction iterations**: 2-3 iterations usually sufficient

### Common Issues

1. **Aiming too high/low**
   - Check gravity scaling (should be `sv_gravity * 0.5`)
   - Verify pitch negation (`-angle * M_RADPI`)

2. **Left/right offset**
   - Check projectile spawn offset
   - Account for weapon viewmodel flip
   - Use actual fire position, not eye position

3. **Leading too much/little**
   - Verify target velocity units
   - Check network latency compensation
   - Iterate prediction 2-3 times

### Related Patterns

- **Weapon State Checking**: Verify can shoot before aiming
- **Target Prediction**: Player movement simulation
- **Projectile Simulation**: Validate trajectory
- **FOV Checking**: Filter targets by field of view

### External References

- [Ballistic Trajectory (Wikipedia)](https://en.wikipedia.org/wiki/Trajectory_of_a_projectile)
- [LnxLib](https://github.com/lnx00/Lmaobox-Library) - Original implementation source
- [TF2 Projectile Speeds](https://wiki.teamfortress.com/wiki/Projectiles)

### Notes

- This is the mathematical foundation for projectile aimbots
- Combine with player simulation for moving targets
- Test with different weapons and ranges
- Account for ping and packet loss
- Consider air resistance for very long ranges (TF2 doesn't simulate this)
