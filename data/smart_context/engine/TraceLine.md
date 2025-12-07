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
#### 1. Standard view ray + distance
```lua
local me = entities.GetLocalPlayer()
local source = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local destination = source + engine.GetViewAngles():Forward() * 1000
local trace = engine.TraceLine(source, destination, MASK_SHOT_HULL)

if trace.entity ~= nil then
    print("I am looking at " .. trace.entity:GetClass())
    print("Distance to entity: " .. trace.fraction * 1000)
end
```

#### 2. Custom filter (skip teammates)
```lua
local me = entities.GetLocalPlayer()
local src = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local dst = src + engine.GetViewAngles():Forward() * 1200

local trace = engine.TraceLine(src, dst, MASK_SHOT_HULL, function(ent, contentsMask)
    if not ent or ent:IsDormant() then return false end
    if ent:GetTeamNumber() == me:GetTeamNumber() then return false end
    return true
end)

if trace.entity then
    print("Hit enemy:", trace.entity:GetClass())
end
```

