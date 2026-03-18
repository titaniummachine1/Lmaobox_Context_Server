## Function/Symbol: Entity.GetMaxs

> Get collision maxs vector (local space)

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    local mins = ent:GetMins()
    local maxs = ent:GetMaxs()
    -- Use with origin for world bounds
end
```

### Notes

- Pair with GetMins

