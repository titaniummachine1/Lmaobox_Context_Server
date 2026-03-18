## Function/Symbol: vector.AngleForward

> Get forward vector from Euler angles

### Required Context

- Parameters: vec (Vector3 angles)
- Returns: EulerAngles (forward?) -> note: per docs returns EulerAngles; but typical forward vector; use consistent

### Curated Usage Examples

#### Move forward from angles

```lua
local forward = vector.AngleForward(engine.GetViewAngles())
local ahead = eyePos + forward * 500
```

### Notes

- Provided for completeness; prefer AngleVectors for fwd/right/up together
