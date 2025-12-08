## Function/Symbol: Entity.IsMedigun

> Check if weapon is a medigun (any type)

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon and weapon:IsMedigun() then
    local target = weapon:GetPropEntity("m_hHealingTarget")
    if target then
        print("Healing: " .. target:GetName())
    end
end
```

### Notes
- Supports all medigun variants
