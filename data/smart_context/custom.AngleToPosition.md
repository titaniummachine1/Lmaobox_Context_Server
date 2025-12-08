## Function/Symbol: custom.AngleToPosition

> Calculate angles needed to look at a target position from a source position

### Required Context

- Types: Vector3, EulerAngles
- Math: atan, asin, normalize
- Notes: Returns pitch/yaw angles for aiming

### Curated Usage Examples

#### Basic angle calculation

```lua
local function normalize(vec)
    return vec / vec:Length()
end

local function AngleToPosition(from, to)
    local dir = normalize(to - from)

    -- Calculate pitch (up/down)
    local pitch = math.asin(-dir.z) * (180 / math.pi)

    -- Calculate yaw (left/right)
    local yaw = math.atan(dir.y, dir.x) * (180 / math.pi)

    return EulerAngles(pitch, yaw, 0)
end
```

#### Usage in aimbot

```lua
local me = entities.GetLocalPlayer()
local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")

-- Aim at target's head
local target = entities.GetByIndex(targetIdx)
local targetHead = target:GetHitboxPos(1)

if targetHead then
    local aimAngles = AngleToPosition(eyePos, targetHead)
    engine.SetViewAngles(aimAngles)
end
```

#### Smooth aiming with interpolation

```lua
local function LerpAngles(from, to, t)
    local diff = to - from

    -- Normalize angle difference to [-180, 180]
    while diff.yaw > 180 do diff.yaw = diff.yaw - 360 end
    while diff.yaw < -180 do diff.yaw = diff.yaw + 360 end

    return EulerAngles(
        from.pitch + diff.pitch * t,
        from.yaw + diff.yaw * t,
        0
    )
end

-- Smooth aim over multiple frames
local currentAngles = engine.GetViewAngles()
local targetAngles = AngleToPosition(eyePos, targetHead)
local smoothAngles = LerpAngles(currentAngles, targetAngles, 0.2) -- 20% per frame

engine.SetViewAngles(smoothAngles)
```

#### Silent aim (for projectiles)

```lua
-- Calculate angle without setting view
local function GetAimAngle(target)
    local me = entities.GetLocalPlayer()
    local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local targetPos = target:GetHitboxPos(1)

    return AngleToPosition(eyePos, targetPos)
end

-- Use in CreateMove callback for silent aim
callbacks.Register("CreateMove", function(cmd)
    local target = GetBestTarget()
    if target then
        local aimAngles = GetAimAngle(target)
        cmd:SetViewAngles(aimAngles)
    end
end)
```
