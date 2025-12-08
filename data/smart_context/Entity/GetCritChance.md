## Function/Symbol: Entity.GetCritChance

> Get weapon's current crit chance (0-1, changes with damage dealt)

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local chance = weapon:GetCritChance()
    print("Crit chance: " .. math.floor(chance * 100) .. "%")
end
```

### Notes
- TF2 crit chance increases with recent damage
- Returns 0-1 float

