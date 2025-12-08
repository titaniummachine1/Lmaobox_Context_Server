## Function/Symbol: vector.Add

> Add two vectors

### Required Context

- Parameters: a, b (Vector3 or {x,y,z})
- Returns: Vector3

### Curated Usage Examples

#### Basic addition

```lua
local sum = vector.Add(posA, posB)
```

#### Offset a position

```lua
local up50 = vector.Add(pos, {0, 0, 50})
```

### Notes

- Equivalent to `a + b`; provided for table-style vectors
