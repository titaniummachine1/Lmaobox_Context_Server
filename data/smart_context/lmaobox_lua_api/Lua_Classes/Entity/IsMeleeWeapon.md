## Function/Symbol: Entity.IsMeleeWeapon

> Check if weapon is melee

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon and weapon:IsMeleeWeapon() then
    print("Melee equipped")
end
```

### Notes
- Use for melee-specific logic (swing range, etc.)

