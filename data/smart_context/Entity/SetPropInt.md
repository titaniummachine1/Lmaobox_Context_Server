## Function/Symbol: Entity.SetPropInt

> Set an integer property on an entity

### Curated Usage Examples

```lua
local ent = entities.GetLocalPlayer()
if ent then
    ent:SetPropInt(300, "m_iHealth")
end
```

### Notes
- Modifying health/ammo can cause kicks; use caution
