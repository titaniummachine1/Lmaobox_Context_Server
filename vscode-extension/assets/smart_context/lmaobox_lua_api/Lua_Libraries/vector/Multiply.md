## Function/Symbol: vector.Multiply

> Multiply a vector by a scalar

### Required Context

- Parameters: vec, scalar
- Returns: Vector3

### Curated Usage Examples

#### Scale direction

```lua
local dir = vector.Normalize(target - origin)
local far = vector.Multiply(dir, 1000)
```

#### Extend position

```lua
local ahead = vector.Multiply(engine.GetViewAngles():Forward(), 500)
```

### Notes

- Equivalent to `vec * scalar`; provided for table-style vectors
