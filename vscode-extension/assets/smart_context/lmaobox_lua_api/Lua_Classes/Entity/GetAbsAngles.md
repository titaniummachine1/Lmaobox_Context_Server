## Function/Symbol: Entity.GetAbsAngles

> Get world angles (Euler) of an entity

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    local ang = ent:GetAbsAngles()
    print("Yaw: " .. ang.yaw)
end
```

### Notes

- Pair with GetAbsOrigin for full transform

