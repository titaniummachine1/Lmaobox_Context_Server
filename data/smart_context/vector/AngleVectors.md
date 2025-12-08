## Function/Symbol: vector.AngleVectors

> Convert Euler angles to forward/right/up vectors

### Required Context

- Parameters: angles (EulerAngles)
- Returns: forward, right, up (Vector3)

### Curated Usage Examples

#### Build basis

```lua
local ang = engine.GetViewAngles()
local fwd, right, up = vector.AngleVectors(ang)
```

#### Move in view direction

```lua
local me = entities.GetLocalPlayer()
if not me then return end
local fwd = vector.AngleVectors(engine.GetViewAngles())
local ahead = me:GetAbsOrigin() + fwd * 100
```

#### Projectile lead example

```lua
local ang = AngleToPosition(eyePos, predictedPos)
local fwd = vector.AngleVectors(ang)
local travel = fwd * projectileSpeed * dt
```

### Notes

- Returned vectors are unit length
- Useful for movement, aimbot math, and projections
