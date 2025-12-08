## Function/Symbol: Entity.SetPropVector

> Set a Vector3 property on an entity

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    ent:SetPropVector(Vector3(0, 0, 100), "m_vecSomePos")
end
```

### Notes
- Use caution; can cause desyncs
