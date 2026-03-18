## Function/Symbol: vector.LengthSqr

> Squared length of a vector (faster than Length)

### Required Context

- Parameters: vec (Vector3 or {x,y,z})
- Returns: number

### Curated Usage Examples

#### Compare distances without sqrt

```lua
local function IsCloser(aPos, bPos, origin)
    local da = vector.LengthSqr(aPos - origin)
    local db = vector.LengthSqr(bPos - origin)
    return da < db
end
```

#### Radius checks

```lua
local radius = 300
local r2 = radius * radius
local dist2 = vector.LengthSqr(target:GetAbsOrigin() - me:GetAbsOrigin())
if dist2 < r2 then
    print("Inside radius")
end
```

### Notes

- Use squared length for performance when only comparisons are needed
