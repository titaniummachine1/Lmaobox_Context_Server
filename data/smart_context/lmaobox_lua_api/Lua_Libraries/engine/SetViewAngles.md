## Function/Symbol: engine.SetViewAngles

> Set the view angles for the local player

### Required Context

- Parameters: EulerAngles
- Types: EulerAngles
- Use carefully; affects camera/aim

### Curated Usage Examples

#### Simple aim set

```lua
local targetAngles = AngleToPosition(eyePos, targetPos)
engine.SetViewAngles(targetAngles)
```

#### Clamp before setting

```lua
local function ClampAngles(ang)
    ang.pitch = math.max(-89, math.min(89, ang.pitch))
    while ang.yaw > 180 do ang.yaw = ang.yaw - 360 end
    while ang.yaw < -180 do ang.yaw = ang.yaw + 360 end
    ang.roll = 0
    return ang
end

local aim = ClampAngles(AngleToPosition(eyePos, targetPos))
engine.SetViewAngles(aim)
```

#### Smooth aiming

```lua
local function Smooth(from, to, factor)
    local diff = to - from
    while diff.yaw > 180 do diff.yaw = diff.yaw - 360 end
    while diff.yaw < -180 do diff.yaw = diff.yaw + 360 end
    return EulerAngles(
        from.pitch + diff.pitch * factor,
        from.yaw + diff.yaw * factor,
        0
    )
end

local current = engine.GetViewAngles()
local target = AngleToPosition(eyePos, targetPos)
local smooth = Smooth(current, target, 0.2)
engine.SetViewAngles(smooth)
```

#### Silent aim in CreateMove

```lua
callbacks.Register("CreateMove", function(cmd)
    local target = GetBestTarget()
    if not target then return end
    local eyePos = GetEyePos(entities.GetLocalPlayer())
    local aim = AngleToPosition(eyePos, target:GetHitboxPos(1))
    cmd:SetViewAngles(aim) -- silent aim
end)
```

### Notes

- Always normalize/clamp angles before setting
- For silent aim, set angles on the command (`cmd:SetViewAngles`)
- Avoid large jumps to reduce suspicion; smooth if needed
