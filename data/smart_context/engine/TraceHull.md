## Function/Symbol: engine.TraceHull

> Trace a hull (box-shaped volume) from source to destination

### Required Context

- Constants: MASK_SHOT_HULL, E_TraceLine masks
- Types: Vector3, Trace, Entity
- Similar to: engine.TraceLine (but checks a volume instead of a line)

### Curated Usage Examples

#### Basic hull trace

```lua
-- Hull trace checks a 3D box moving from src to dst
local me = entities.GetLocalPlayer()
local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local forward = engine.GetViewAngles():Forward()
local destination = eyePos + forward * 1000

-- Define hull size (mins/maxs define the box dimensions)
local mins = Vector3(-8, -8, -8)
local maxs = Vector3(8, 8, 8)

local trace = engine.TraceHull(eyePos, destination, mins, maxs, MASK_SHOT_HULL)

if trace.entity then
    print("Hull hit: " .. trace.entity:GetClass())
end
```

#### Player hull size trace

```lua
-- Use player-sized hull for movement checks
local function CanFitInGap(from, to)
    -- TF2 player hull dimensions
    local mins = Vector3(-24, -24, 0)
    local maxs = Vector3(24, 24, 82)

    local trace = engine.TraceHull(from, to, mins, maxs, MASK_PLAYERSOLID)

    return trace.fraction > 0.99 -- Can fit if no obstruction
end

-- Check if player can move to position
local me = entities.GetLocalPlayer()
local myPos = me:GetAbsOrigin()
local targetPos = myPos + Vector3(100, 0, 0) -- 100 units forward

if CanFitInGap(myPos, targetPos) then
    print("Path is clear")
else
    print("Blocked")
end
```

#### Melee weapon range check

```lua
-- Check if melee weapon can hit (uses hull trace)
local function IsInMeleeRange(target)
    local me = entities.GetLocalPlayer()
    local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local forward = engine.GetViewAngles():Forward()

    -- Melee range in TF2 is ~48-72 units
    local meleeEnd = eyePos + forward * 72

    -- Small hull for melee sweep
    local mins = Vector3(-18, -18, -18)
    local maxs = Vector3(18, 18, 18)

    local trace = engine.TraceHull(eyePos, meleeEnd, mins, maxs, MASK_SHOT_HULL)

    return trace.entity == target
end

-- Usage in melee aimbot
for i = 1, entities.GetHighestEntityIndex() do
    local ent = entities.GetByIndex(i)
    if ent and ent:IsPlayer() and ent:IsAlive() then
        if IsInMeleeRange(ent) then
            print(ent:GetName() .. " in melee range!")
        end
    end
end
```

### Notes

- **mins/maxs** define the hull box size relative to the trace line
- Use **MASK_PLAYERSOLID** for movement/collision checks
- Use **MASK_SHOT_HULL** for weapon hit detection
- Hull traces are more expensive than line traces - use sparingly
