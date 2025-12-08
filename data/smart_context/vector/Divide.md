## Function/Symbol: vector.Divide

> Divide a vector by a scalar

### Required Context

- Parameters: vec, scalar
- Returns: Vector3

### Curated Usage Examples

#### Normalize manually

```lua
local dir = vector.Divide(delta, delta:Length())
```

#### Scale down

```lua
local small = vector.Divide(bigVec, 10)
```

### Notes

- Equivalent to `vec / scalar`; provided for table-style vectors
