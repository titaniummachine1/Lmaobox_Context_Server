## Function/Symbol: Entity.DoSwingTrace

> Simulate a melee weapon swing and return Trace result

### Required Context
- Returns: Trace
- Types: Trace, Entity

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon and weapon:IsMeleeWeapon() then
    local trace = weapon:DoSwingTrace()
    if trace.entity then
        print("Melee would hit: " .. trace.entity:GetClass())
    end
end
```

### Notes
- Simulates what the melee swing would hit (doesn't actually swing)
- Use for melee aimbot target detection
