## Function/Symbol: Entity.IsPlayer

> Check if entity is a player

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(i)
if ent and ent:IsPlayer() then
    print("Player: " .. ent:GetName())
end
```

### Notes

- Use with `IsAlive`/`GetTeamNumber` to filter valid targets

