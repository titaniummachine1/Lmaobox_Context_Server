## Function/Symbol: Entity.GetProjectileGravity

> Get projectile gravity multiplier of a weapon

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local grav = weapon:GetProjectileGravity()
    if grav and grav > 0 then
        print("Gravity: " .. grav)
        -- use for arc prediction (pipes, huntsman, etc.)
    end
end
```

### Notes
- Returns nil if not a projectile weapon
- Can return 0 if hardcoded; default gravity is often 1.0 or specific per weapon
