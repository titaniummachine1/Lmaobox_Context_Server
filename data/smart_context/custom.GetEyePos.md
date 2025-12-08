## Function/Symbol: custom.GetEyePos

> Get player's eye/view position (origin + view offset)

### Required Context

- Entity props: `m_vecViewOffset[0]`
- Types: Vector3, Entity
- Functions: Entity.GetAbsOrigin, Entity.GetPropVector

### Curated Usage Examples

#### Standard implementation

```lua
local function GetEyePos(player)
    if not player then return nil end
    local origin = player:GetAbsOrigin()
    local viewOffset = player:GetPropVector("localdata", "m_vecViewOffset[0]")
    return origin + viewOffset
end
```

#### Usage in aimbot/ESP

```lua
local me = entities.GetLocalPlayer()
local eyePos = GetEyePos(me)

-- Trace from eye to target
for i = 1, entities.GetHighestEntityIndex() do
    local ent = entities.GetByIndex(i)
    if ent and ent:IsPlayer() and ent:IsAlive() and ent ~= me then
        local targetHead = ent:GetHitboxPos(1)
        local trace = engine.TraceLine(eyePos, targetHead, MASK_SHOT_HULL)

        if trace.fraction > 0.99 then
            print(ent:GetName() .. " is visible")
        end
    end
end
```

#### Inline shorthand

```lua
-- When you only need it once
local me = entities.GetLocalPlayer()
local eyePos = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
```
