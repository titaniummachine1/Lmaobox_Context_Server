## Function/Symbol: vector.Distance

> Distance between two vectors/positions

### Required Context

- Parameters: a, b (Vector3 or {x,y,z})
- Returns: number

### Curated Usage Examples

#### Quick distance

```lua
local d = vector.Distance(posA, posB)
if d < 300 then
    print("Close")
end
```

#### Closest entity using vector lib

```lua
local function Closest(entitiesList, point)
    local best, bestDist = nil, math.huge
    for _, ent in pairs(entitiesList) do
        local dist = vector.Distance(ent:GetAbsOrigin(), point)
        if dist < bestDist then
            best, bestDist = ent, dist
        end
    end
    return best, bestDist
end
```

### Notes

- Equivalent to `(b - a):Length()`; vector.Distance can be simpler
