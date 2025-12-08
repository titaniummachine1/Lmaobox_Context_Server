## Function/Symbol: engine.TraceLine

> Signature: function engine.TraceLine(src, dst, mask, shouldHitEntity) end

### Required Context

- MASK_SHOT_HULL (TraceLine masks; see constants/E_TraceLine.d.lua)
- Params:
  - src: Vector3
  - dst: Vector3
  - mask (optional): integer (trace mask)
  - shouldHitEntity (optional): fun(ent: Entity, contentsMask: integer): boolean
- Returns: Trace (see Lua_Classes/Trace.d.lua for fields like `fraction`, `entity`, hit info)

### Curated Usage Examples

#### Basic what im looking at

```lua
local me = entities.GetLocalPlayer()
local eye = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local dest = eye + engine.GetViewAngles():Forward() * 1000
local trace = engine.TraceLine(eye, dest, MASK_SHOT_HULL)

if trace.entity then
    print("Looking at: " .. trace.entity:GetClass())
    print("Distance: " .. math.floor(trace.fraction * 1000) .. " units")
end
```

#### Custom filter (skip teammates)

```lua
local me = entities.GetLocalPlayer()
local eye = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local dest = eye + engine.GetViewAngles():Forward() * 1200

local trace = engine.TraceLine(eye, dest, MASK_SHOT_HULL, function(ent, contentsMask)
    if not ent or ent:IsDormant() then return false end
    if ent:GetTeamNumber() == me:GetTeamNumber() then return false end
    return true
end)

if trace.entity then
    print("Hit enemy:", trace.entity:GetClass())
end
```

#### Splash damage visibility (check if wall faces player)

```lua
local function PlaneFacesPlayer(normal, eyePos, hitPos)
    return normal:Dot(hitPos - eyePos) < 0
end

local me = entities.GetLocalPlayer()
local eye = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local dest = target:GetAbsOrigin()

local trace = engine.TraceLine(eye, dest, MASK_SHOT_HULL)

if trace.fraction < 1.0 then
    -- Hit a wall
    if PlaneFacesPlayer(trace.plane, eye, trace.endpos) then
        print("Wall faces us - good for splash")
    else
        print("Wall faces away - splash won't reach")
    end
end
```

#### Check point contents

```lua
local pos = entity:GetAbsOrigin() + Vector3(0, 0, 1)
local contents = engine.GetPointContents(pos)

if contents ~= 0 then
    print("Point is inside solid")
end

-- Use with TraceLine to filter solid surfaces
local trace = engine.TraceLine(eye, dest, MASK_SHOT_HULL)
if trace.contents ~= 0 then
    print("Hit solid: " .. trace.contents)
end
```

#### Trace result fields reference

```lua
-- After TraceLine/TraceHull:
-- trace.fraction  -- 0-1: how far the trace went (1.0 = no hit)
-- trace.entity    -- Entity hit (nil if world)
-- trace.plane     -- Normal vector of hit surface (Vector3, unit length)
-- trace.contents  -- Surface contents flags (integer)
-- trace.endpos    -- World position where trace stopped (Vector3)
-- trace.hitbox    -- Hitbox ID hit (if entity)
-- trace.hitgroup  -- Hitgroup hit (if entity)
-- trace.startpos  -- Start position (Vector3)
-- trace.allsolid  -- True if trace is entirely in solid
-- trace.startsolid -- True if trace started in solid
```
