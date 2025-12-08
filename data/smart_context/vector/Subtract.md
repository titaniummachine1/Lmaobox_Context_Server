## Function/Symbol: vector.Subtract

> Subtract two vectors

### Required Context

- Parameters: a, b (Vector3 or {x,y,z})
- Returns: Vector3

### Curated Usage Examples

#### Direction vector

```lua
local dir = vector.Subtract(targetPos, myPos)
```

#### Delta for distance

```lua
local delta = vector.Subtract(pos2, pos1)
local dist = delta:Length()
```

### Notes

- Equivalent to `a - b`; provided for table-style vectors
