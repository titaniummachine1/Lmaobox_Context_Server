## Function/Symbol: Vector3.Normalize

> Normalize vector in-place (instance method)

### Curated Usage Examples

```lua
local dir = target - origin
dir:Normalize()
-- dir is now unit length
```

### Notes

- Modifies the vector directly (no return)
- For non-mutating: `dir / dir:Length()`

