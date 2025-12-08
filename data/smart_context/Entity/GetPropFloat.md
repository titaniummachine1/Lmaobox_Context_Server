## Function/Symbol: Entity.GetPropFloat

> Get a float/number property from entity

### Required Context
- Parameters: table name(s), field name (varargs)
- Returns: number (0.0 if missing)

### Curated Usage Examples

#### Read charge percentage
```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local charge = weapon:GetPropFloat("m_flChargedDamage")
    print("Charge: " .. charge)
end
```

#### Read next attack time
```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local nextAttack = weapon:GetPropFloat("m_flNextPrimaryAttack")
    local curTime = globals.CurTime()
    if curTime >= nextAttack then
        print("Can shoot now")
    end
end
```

### Notes
- Returns 0.0 if prop not found
- Use exact table/field names from entity props

