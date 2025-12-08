## Function/Symbol: Entity.GetPropVector

> Get a Vector3 property from an entity

### Required Context

- Returns: Vector3
- Types: Entity, Vector3
- Common props: view offset, velocity, origin, angles as vector

### Curated Usage Examples

#### Get view offset (eye position)

```lua
-- Most common usage - get where player is looking from
local player = entities.GetLocalPlayer()
if not player then return end

local origin = player:GetAbsOrigin()
local viewOffset = player:GetPropVector("localdata", "m_vecViewOffset[0]")
local eyePos = origin + viewOffset

print("Eye position: " .. tostring(eyePos))
```

#### Get player velocity

```lua
local player = entities.GetLocalPlayer()
if not player then return end

local velocity = player:GetPropVector("localdata", "m_vecVelocity[0]")
local speed = velocity:Length()

print("Current speed: " .. math.floor(speed) .. " units/sec")

-- Check if player is moving
if speed > 10 then
    print("Moving")
else
    print("Standing still")
end
```

#### Get punch angle (view punch from damage)

```lua
-- Punch angles affect aim when taking damage
local me = entities.GetLocalPlayer()
if not me then return end

local punchAngle = me:GetPropVector("localdata", "m_vecPunchAngle")
local punchAngleVel = me:GetPropVector("localdata", "m_vecPunchAngleVel")

-- Compensate for punch in aimbot
local viewAngles = engine.GetViewAngles()
local compensated = EulerAngles(
    viewAngles.pitch - punchAngle.x,
    viewAngles.yaw - punchAngle.y,
    0
)
```

#### Get entity velocity for prediction

```lua
-- Predict where target will be
local function PredictPosition(entity, time)
    local pos = entity:GetAbsOrigin()
    local vel = entity:GetPropVector("localdata", "m_vecVelocity[0]")

    -- Simple linear prediction
    return pos + vel * time
end

-- Usage for projectile aimbot
local target = entities.GetByIndex(targetIdx)
local predictedPos = PredictPosition(target, 0.1) -- 100ms ahead

-- Aim at predicted position instead of current
local aimAngles = AngleToPosition(eyePos, predictedPos)
```

#### Check if player is on ground

```lua
-- Ground entity check using origin
local me = entities.GetLocalPlayer()
if not me then return end

local flags = me:GetPropInt("m_fFlags")
local onGround = (flags & FL_ONGROUND) ~= 0

-- Alternative: check velocity.z
local velocity = me:GetPropVector("localdata", "m_vecVelocity[0]")
local fallingFast = velocity.z < -500

if fallingFast then
    print("Falling!")
end
```

### Common Vector Props

**localdata table:**

- `m_vecViewOffset[0]` - View offset from origin (eye height)
- `m_vecVelocity[0]` - Current velocity
- `m_vecPunchAngle` - View punch from recoil/damage
- `m_vecPunchAngleVel` - Punch angle velocity

**DT_BaseEntity:**

- `m_vecOrigin` - Entity origin (use GetAbsOrigin() instead)
- `m_angRotation` - Entity angles (use GetAbsAngles() instead)

### Notes

- **Array props** need `[0]` suffix (e.g., `m_vecViewOffset[0]`)
- Returns **Vector3(0, 0, 0)** if prop not found
- **localdata** table is most common for player props
- Use `Entity:GetAbsOrigin()` instead of prop for position (faster)
