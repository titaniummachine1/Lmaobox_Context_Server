## Function/Symbol: Entity.IsDormant

> Check if entity is dormant (not being updated by server)

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent and not ent:IsDormant() and ent:IsAlive() then
    -- entity is active and alive
end
```

### Notes
- Dormant entities should not be targeted or drawn
- Common filter: `if ent and not ent:IsDormant() and ent:IsAlive()`

