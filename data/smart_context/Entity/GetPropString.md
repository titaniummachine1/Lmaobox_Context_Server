## Function/Symbol: Entity.GetPropString

> Get a string property from entity

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    local str = ent:GetPropString("m_iName")
    -- example; actual string props vary
end
```

### Notes
- Returns empty string if prop not found

