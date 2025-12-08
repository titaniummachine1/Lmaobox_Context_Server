## Function/Symbol: Entity.SetPropEntity

> Set an entity handle property

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    ent:SetPropEntity(targetEnt, "m_hSomeHandle")
end
```

### Notes
- Rare; handle modifications can desync
