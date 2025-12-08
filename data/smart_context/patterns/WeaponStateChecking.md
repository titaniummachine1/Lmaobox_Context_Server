## Pattern: Weapon State Checking & Caching

> Efficiently check if player can shoot by caching weapon state

### Context

Weapon firing checks happen every frame in CreateMove. Getting weapon properties repeatedly is expensive. This pattern caches weapon state and only updates when necessary.

### Complete Implementation

```lua
local wep_utils = {}

local old_weapon, lastFire, nextAttack = nil, 0, 0

local function GetLastFireTime(weapon)
    return weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime")
end

local function GetNextPrimaryAttack(weapon)
    return weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
end

function wep_utils.CanShoot()
    local player = entities:GetLocalPlayer()
    if not player then
        return false
    end

    local weapon = player:GetPropEntity("m_hActiveWeapon")
    if not weapon or not weapon:IsValid() then
        return false
    end

    if weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then
        return false
    end

    local lastfiretime = GetLastFireTime(weapon)
    if lastFire ~= lastfiretime or weapon ~= old_weapon then
        lastFire = lastfiretime
        nextAttack = GetNextPrimaryAttack(weapon)
    end

    old_weapon = weapon

    return nextAttack < globals.CurTime()
end

return wep_utils
```

### Key Concepts

#### 1. State Caching

```lua
local old_weapon, lastFire, nextAttack = nil, 0, 0
```

- Stores previous weapon state outside function scope
- Persists between function calls
- Avoids repeated property lookups

#### 2. Change Detection

```lua
if lastFire ~= lastfiretime or weapon ~= old_weapon then
    -- Only update cache when state changes
    nextAttack = GetNextPrimaryAttack(weapon)
end
```

- Detects weapon switches (`weapon ~= old_weapon`)
- Detects new shots (`lastFire ~= lastfiretime`)
- Only queries `nextAttack` when needed

#### 3. Guard Clauses

```lua
if not player then return false end
if not weapon or not weapon:IsValid() then return false end
if weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then return false end
```

- Check most common failures first
- Early return pattern
- No error logging (silent failures)

### Weapon Property Tables

Different weapon data is stored in separate property tables:

- **LocalActiveTFWeaponData**: TF2-specific active weapon data

  - `m_flLastFireTime` - When weapon was last fired

- **LocalActiveWeaponData**: General active weapon data

  - `m_flNextPrimaryAttack` - When weapon can fire again
  - `m_flNextSecondaryAttack` - Secondary attack timing

- **LocalWeaponData**: Weapon info
  - `m_iClip1` - Primary ammo count
  - `m_iClip2` - Secondary ammo count

### Performance Impact

Without caching:

- 3 property lookups per frame × 60 FPS = 180 lookups/second

With caching:

- 1-3 property lookups only on weapon switch or shot
- ~90-99% reduction in property access

### Usage in CreateMove

```lua
local function OnCreateMove(cmd)
    if not wep_utils.CanShoot() then
        return
    end

    -- Safe to shoot now
    if should_aim() then
        aim_at_target()
        cmd.buttons = cmd.buttons | IN_ATTACK
    end
end

callbacks.Register("CreateMove", OnCreateMove)
```

### Related Patterns

- **State Caching**: See also entity caching, position caching
- **Guard Clauses**: See error handling patterns
- **Timing Checks**: See globals.CurTime() documentation

### External References

- [UnknownCheats: CanShoot Function](https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html)

### Notes

- This pattern is critical for aimbot/triggerbot implementations
- Can be extended to cache other weapon properties
- Consider adding reloading check: `weapon:GetPropBool("m_bInReload")`
- For rapid-fire weapons, add fire rate limit check
