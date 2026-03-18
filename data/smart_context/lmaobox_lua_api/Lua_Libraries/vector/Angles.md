## Function/Symbol: vector.Angles

> Convert a vector to Euler angles

### Required Context

- Parameters: vec (Vector3)
- Returns: EulerAngles

### Curated Usage Examples

#### Direction to angles

```lua
local dir = (to - from)
local ang = vector.Angles(dir)
```

#### Use for aim

```lua
local aim = vector.Angles(targetPos - eyePos)
engine.SetViewAngles(aim)
```

### Notes

- Similar to AngleToPosition helper; uses built-in conversion
