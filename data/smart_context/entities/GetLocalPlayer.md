## Function/Symbol: entities.GetLocalPlayer

> Get the local player entity (you)

### Required Context

- Returns: Entity or nil
- Types: Entity
- Notes: Always check for nil before using

### Curated Usage Examples

#### Basic usage

```lua
local me = entities.GetLocalPlayer()

if not me then
    print("Not in game yet")
    return
end

print("My name: " .. me:GetName())
print("My health: " .. me:GetHealth())
print("My team: " .. me:GetTeamNumber())
```

#### Common pattern - check alive

```lua
local me = entities.GetLocalPlayer()
if not me or not me:IsAlive() then
    return -- Dead or not in game
end

-- Safe to use me here
local myPos = me:GetAbsOrigin()
local myHealth = me:GetHealth()
```

#### Get eye position

```lua
local me = entities.GetLocalPlayer()
if not me then return end

local origin = me:GetAbsOrigin()
local viewOffset = me:GetPropVector("localdata", "m_vecViewOffset[0]")
local eyePos = origin + viewOffset
```

#### Check weapon

```lua
local me = entities.GetLocalPlayer()
if not me then return end

local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local weaponID = weapon:GetPropInt("m_iItemDefinitionIndex")
    print("Current weapon ID: " .. weaponID)
end
```

#### In callback

```lua
callbacks.Register("CreateMove", function(cmd)
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end

    -- Your aimbot/movement code here
    local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
end)
```

### Notes

- **Always nil-check** before using
- Returns nil if not in a game/server
- Returns nil briefly when respawning
- Cache the result if using multiple times in same frame
