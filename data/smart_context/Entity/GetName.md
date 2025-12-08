## Function/Symbol: Entity.GetName

> Get player name (if entity is a player)

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent and ent:IsPlayer() then
    print(ent:GetName())
end
```

### Notes

- Returns empty string for non-players

