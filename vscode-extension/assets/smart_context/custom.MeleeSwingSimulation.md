## Pattern: Melee Swing Simulation with TraceHull

> Predict melee weapon hits using hull traces

### Required Context

- Functions: Entity:GetSwingRange, Entity:DoSwingTrace, engine.TraceHull
- Constants: MASK_SHOT_HULL
- Pattern: Simulate melee swing arc with hull trace

### Curated Usage Examples

#### Basic melee hit check

```lua
local function CanHitWithMelee(weapon, target)
    if not weapon or not weapon:IsMeleeWeapon() then return false end

    local swingRange = weapon:GetSwingRange()
    if not swingRange then return false end

    local me = entities.GetLocalPlayer()
    local eye = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local forward = engine.GetViewAngles():Forward()

    -- Melee hull dimensions (typical TF2 melee sweep)
    local mins = Vector3(-18, -18, -18)
    local maxs = Vector3(18, 18, 18)

    local swingEnd = eye + forward * swingRange
    local trace = engine.TraceHull(eye, swingEnd, mins, maxs, MASK_SHOT_HULL)

    return trace.entity == target
end

-- Usage
local weapon = me:GetPropEntity("m_hActiveWeapon")
local target = GetBestTarget()

if weapon and target and CanHitWithMelee(weapon, target) then
    print("In melee range!")
end
```

#### Use DoSwingTrace for precise check

```lua
local function WillHitOnSwing(weapon, target)
    if not weapon or not weapon:IsMeleeWeapon() then return false end

    local trace = weapon:DoSwingTrace()
    return trace.entity == target
end
```

### Notes

- `DoSwingTrace` uses exact game logic (more accurate)
- Manual hull trace gives you control over range/size
- Typical TF2 melee range: 48-72 units (varies by weapon)
- Use `-18,-18,-18` to `18,18,18` hull for standard melee sweep

