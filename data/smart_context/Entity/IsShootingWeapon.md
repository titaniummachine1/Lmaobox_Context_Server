## Function/Symbol: Entity.IsShootingWeapon

> Check if weapon can shoot projectiles or hitscan

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon and weapon:IsShootingWeapon() then
    print("Can shoot")
end
```

### Notes
- Excludes melee/medigun
