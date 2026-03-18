## Function/Symbol: vector.Normalize

> Normalize a vector in-place (makes length = 1)

### Required Context

- Parameters: vec (Vector3 or {x,y,z})
- Modifies the vector directly

### Curated Usage Examples

#### Normalize direction

```lua
local dir = { x = 10, y = 0, z = 5 }
vector.Normalize(dir)
-- dir is now unit length
```

#### Use on Vector3

```lua
local v = Vector3(100, 50, 0)
vector.Normalize(v)
-- v now has length 1
```

### Notes

- In-place: no return value; pass by reference
- Engine handles zero-length safely, but avoid for logic that needs direction
- For non-mutating, use `vec / vec:Length()` pattern
