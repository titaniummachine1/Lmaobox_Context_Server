## Function/Symbol: vector.AngleNormalize

> Normalize Euler angle components (wrap yaw/pitch)

### Required Context

- Parameters: vec (Vector3 angles)
- Returns: EulerAngles

### Curated Usage Examples

#### Normalize user input angles

```lua
local ang = EulerAngles(200, 400, 0)
local norm = vector.AngleNormalize(ang)
```

#### Clamp after math

```lua
local target = AngleToPosition(eyePos, targetPos)
target = vector.AngleNormalize(target)
engine.SetViewAngles(target)
```

### Notes

- Ensures angles are within valid ranges (e.g., yaw -180..180)
