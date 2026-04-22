## Function/Symbol: custom.ClampAngles

> Normalize/clamp Euler angles for safe aiming

### Curated Usage Examples

```lua
local function ClampAngles(ang)
    ang.pitch = math.max(-89, math.min(89, ang.pitch))
    while ang.yaw > 180 do ang.yaw = ang.yaw - 360 end
    while ang.yaw < -180 do ang.yaw = ang.yaw + 360 end
    ang.roll = 0
    return ang
end

-- Usage before setting view angles
local aim = AngleToPosition(eyePos, targetPos)
aim = ClampAngles(aim)
engine.SetViewAngles(aim)
```

### Notes

- Prevents illegal pitch/roll values
- Useful before SetViewAngles or cmd:SetViewAngles
