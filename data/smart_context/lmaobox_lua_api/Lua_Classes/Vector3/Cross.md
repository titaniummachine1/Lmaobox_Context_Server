## Function/Symbol: Vector3.Cross

> Cross product of two vectors (perpendicular vector)

### Curated Usage Examples

```lua
local perp = v1:Cross(v2)
```

#### Build orthonormal basis

```lua
local function BuildBasis(normal)
    local tmp = (math.abs(normal.z) < 0.9) and Vector3(0, 0, 1) or Vector3(1, 0, 0)
    local u = tmp:Cross(normal)
    u = u / u:Length()
    local v = normal:Cross(u)
    return u, v
end
```

### Notes

- Returns vector perpendicular to both inputs
- Result length = |v1| _ |v2| _ sin(angle)
- Use for building coordinate systems, plane projection

