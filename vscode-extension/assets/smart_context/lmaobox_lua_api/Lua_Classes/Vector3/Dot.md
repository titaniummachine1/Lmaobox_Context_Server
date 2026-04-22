## Function/Symbol: Vector3.Dot

> Dot product of two vectors

### Curated Usage Examples

```lua
local dot = v1:Dot(v2)
```

#### Check if vectors point same direction

```lua
local dir1 = (target1 - origin) / (target1 - origin):Length()
local dir2 = (target2 - origin) / (target2 - origin):Length()
local dot = dir1:Dot(dir2)

if dot > 0.9 then
    print("Targets are in similar direction")
end
```

#### Check if plane faces player

```lua
local function PlaneFacesPlayer(normal, eyePos, hitPos)
    return normal:Dot(hitPos - eyePos) < 0
end
```

### Notes

- Returns scalar: 1 = same direction, -1 = opposite, 0 = perpendicular
- Use for angle checks, projection, plane facing

