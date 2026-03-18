## Function/Symbol: globals.CurTime

> Get current server time (seconds since map start)

### Curated Usage Examples

#### Check weapon cooldown (basic)

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local nextAttack = weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
    if nextAttack < globals.CurTime() then
        print("Weapon ready to fire")
    end
end
```

#### Efficient CanShoot check (with caching)

```lua
local old_weapon, lastFire, nextAttack = nil, 0, 0

function CanShoot()
    local player = entities.GetLocalPlayer()
    if not player then return false end

    local weapon = player:GetPropEntity("m_hActiveWeapon")
    if not weapon or not weapon:IsValid() then return false end

    -- Cache nextAttack time to avoid repeated prop lookups
    local lastfiretime = weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime")
    if lastFire ~= lastfiretime or weapon ~= old_weapon then
        lastFire = lastfiretime
        nextAttack = weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
    end

    old_weapon = weapon
    return nextAttack < globals.CurTime()
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

#### Track time since last action

```lua
local actionTime = 0

function DoAction()
    actionTime = globals.CurTime()
end

function TimeSinceAction()
    return globals.CurTime() - actionTime
end
```

### Notes

- Returns game time in seconds since map start
- **Use for timing checks, cooldowns, delays**
- Advances with server ticks (not wall clock time)
- Use `<` not `<=` for "ready now" checks (e.g., `nextAttack < CurTime()`)
- Cache timing values to reduce prop lookups in performance-critical code
