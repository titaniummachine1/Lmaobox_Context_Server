## Function/Symbol: Entity.GetMins

> Get collision mins vector (local space)

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    local mins = ent:GetMins()
    local maxs = ent:GetMaxs()
    print("BBox mins:", tostring(mins), "maxs:", tostring(maxs))
end
```

### Notes

- Combine with origin to compute bounding box in world

