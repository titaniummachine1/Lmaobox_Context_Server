## Function/Symbol: Entity.GetPropBool

> Get a boolean property from entity

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    local isDefending = ent:GetPropBool("m_bDefending")
    -- example; actual bool props vary
end
```

### Notes
- Returns false if prop not found

