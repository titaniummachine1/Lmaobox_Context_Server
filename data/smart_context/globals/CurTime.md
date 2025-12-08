## Function/Symbol: globals.CurTime

> Get current server time (seconds since map start)

### Curated Usage Examples

#### Check weapon cooldown
```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local nextAttack = weapon:GetPropFloat("m_flNextPrimaryAttack")
    local curTime = globals.CurTime()
    if curTime >= nextAttack then
        print("Can attack now")
    end
end
```

#### Cooldown timer
```lua
local lastUse = 0

callbacks.Register("CreateMove", "cooldown_demo", function()
    local now = globals.CurTime()
    if now - lastUse > 3.0 then
        -- do thing
        lastUse = now
    end
end)
```

### Notes
- Use for timing checks, cooldowns, delays
- Advances with server ticks

