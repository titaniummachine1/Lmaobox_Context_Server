## Function/Symbol: Entity.GetWeaponData

> Get weapon's attributes (WeaponData class)

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local data = weapon:GetWeaponData()
    -- WeaponData fields: damage, range, etc. (see WeaponData class)
end
```

### Notes
- Returns WeaponData object; check WeaponData class for fields
