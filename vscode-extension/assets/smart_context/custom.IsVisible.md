## Function/Symbol: custom.IsVisible

> Check if target position/entity is visible (no obstacles blocking line of sight)

### Required Context

- Functions: engine.TraceLine
- Constants: MASK_SHOT_HULL
- Types: Vector3, Entity, Trace

### Curated Usage Examples

#### Basic visibility check

```lua
local function IsVisible(from, to, skipEnt)
    local trace = engine.TraceLine(from, to, MASK_SHOT_HULL)
    -- fraction > 0.99 means no hit, or we hit the entity we're checking
    return trace.fraction > 0.99 or trace.entity == skipEnt
end

-- Usage
local me = entities.GetLocalPlayer()
local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local target = entities.GetByIndex(targetIdx)

if IsVisible(eyePos, target:GetAbsOrigin(), me) then
    print("Target is visible!")
end
```

#### Check multiple hitboxes

```lua
local function IsAnyHitboxVisible(from, target, skipEnt)
    -- Check head, chest, pelvis
    local hitboxes = {1, 3, 7}

    for _, hitboxId in ipairs(hitboxes) do
        local hitboxPos = target:GetHitboxPos(hitboxId)
        if hitboxPos then
            local trace = engine.TraceLine(from, hitboxPos, MASK_SHOT_HULL)
            if trace.fraction > 0.99 or trace.entity == target then
                return true, hitboxId
            end
        end
    end

    return false
end

-- Usage
local me = entities.GetLocalPlayer()
local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")

for i = 1, entities.GetHighestEntityIndex() do
    local ent = entities.GetByIndex(i)
    if ent and ent:IsPlayer() and ent:IsAlive() and ent ~= me then
        local visible, hitbox = IsAnyHitboxVisible(eyePos, ent, me)
        if visible then
            print(ent:GetName() .. " hitbox " .. hitbox .. " is visible")
        end
    end
end
```

#### Advanced: Skip teammates

```lua
local function IsVisibleToEnemy(from, to, me)
    local trace = engine.TraceLine(from, to, MASK_SHOT_HULL, function(ent, contentsMask)
        if not ent or ent:IsDormant() then return false end
        if ent == me then return false end
        if ent:GetTeamNumber() == me:GetTeamNumber() then return false end
        return true
    end)

    return trace.fraction > 0.99
end

-- Only counts as visible if an enemy is in the way or clear line
local me = entities.GetLocalPlayer()
local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local targetPos = target:GetAbsOrigin()

if IsVisibleToEnemy(eyePos, targetPos, me) then
    print("Clear shot at enemy!")
end
```
