## Function/Symbol: Entity.SetPropFloat

> Set a float property on an entity

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    weapon:SetPropFloat(100.0, "m_flChargedDamage")
end
```

### Notes
- Use sparingly; modifying props can cause issues or kicks

