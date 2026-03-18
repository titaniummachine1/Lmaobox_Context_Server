## Function/Symbol: vector.AngleUp

> Get up vector from Euler angles

### Required Context

- Parameters: vec (Vector3 angles)

### Curated Usage Examples

```lua
local up = vector.AngleUp(engine.GetViewAngles())
local top = eyePos + up * 50
```

### Notes

- Prefer AngleVectors for fwd/right/up together
