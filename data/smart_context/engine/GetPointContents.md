## Function/Symbol: engine.GetPointContents

> Get contents flags at a world position

### Required Context

- Parameters: pos (Vector3)
- Returns: integer (contents flags)
- 0 = empty/air, non-zero = solid/water/etc.

### Curated Usage Examples

#### Check if position is in solid

```lua
local pos = entity:GetAbsOrigin() + Vector3(0, 0, 1)
local contents = engine.GetPointContents(pos)

if contents ~= 0 then
    print("Position is inside solid")
else
    print("Position is in air")
end
```

#### Filter entities in solid (for shouldHitEntity callback)

```lua
local function shouldHitEntityFn(entity, target)
    local pos = entity:GetAbsOrigin() + Vector3(0, 0, 1)
    local contents = engine.GetPointContents(pos)

    if contents ~= 0 then
        return true -- Entity is in solid, can hit
    end

    if entity == target then
        return false -- Don't hit target itself
    end

    if entity:GetTeamNumber() == target:GetTeamNumber() then
        return false -- Don't hit teammates
    end

    return true
end

-- Usage with TraceLine
local trace = engine.TraceLine(src, dst, MASK_SHOT_HULL, shouldHitEntityFn)
```

### Notes

- Returns contents flags (bitmask)
- 0 = air/empty space
- Non-zero = solid, water, or other special contents
- Use in shouldHitEntity callbacks to filter geometry

