## Function/Symbol: custom.LerpAngles

> Smoothly interpolate between two angles

### Curated Usage Examples

```lua
local function LerpAngles(from, to, t)
    local diff = to - from
    while diff.yaw > 180 do diff.yaw = diff.yaw - 360 end
    while diff.yaw < -180 do diff.yaw = diff.yaw + 360 end
    return EulerAngles(
        from.pitch + diff.pitch * t,
        from.yaw   + diff.yaw   * t,
        0
    )
end

-- Smooth aim 20% per tick
local current = engine.GetViewAngles()
local target  = AngleToPosition(eyePos, targetPos)
local smooth  = LerpAngles(current, target, 0.2)
engine.SetViewAngles(smooth)
```

### Notes

- t in [0,1]; smaller = smoother
- Normalize yaw wrap to avoid long rotations
