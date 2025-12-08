## Function/Symbol: Entity.GetSwingRange

> Get melee weapon swing range

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon and weapon:IsMeleeWeapon() then
    local range = weapon:GetSwingRange()
    if range then
        print("Melee range: " .. range)
    end
end
```

### Notes
- Returns nil if not melee
- Typical TF2 melee range: 48-72 units
