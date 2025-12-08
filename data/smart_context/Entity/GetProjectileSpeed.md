## Function/Symbol: Entity.GetProjectileSpeed

> Get projectile speed of a weapon (units/sec)

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local speed = weapon:GetProjectileSpeed()
    if speed and speed > 0 then
        print("Projectile speed: " .. speed)
        -- use for prediction
        local travelTime = distance / speed
        local predicted = PredictPosition(target, travelTime)
    end
end
```

### Notes
- Returns nil if not a projectile weapon
- Can return 0 if hardcoded; you must know defaults (e.g., rockets ~1100)
