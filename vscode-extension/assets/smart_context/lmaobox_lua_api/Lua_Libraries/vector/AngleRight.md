## Function/Symbol: vector.AngleRight

> Get right vector from Euler angles

### Required Context

- Parameters: vec (Vector3 angles)
- Returns: EulerAngles (?) right vector

### Curated Usage Examples

```lua
local right = vector.AngleRight(engine.GetViewAngles())
local strafePos = eyePos + right * 50
```

### Notes

- Prefer AngleVectors for full basis
