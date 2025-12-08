## Function/Symbol: custom.DistanceTo

> Calculate distance between two positions or entities

### Required Context

- Types: Vector3, Entity
- Methods: Vector3.Length, Entity.GetAbsOrigin

### Curated Usage Examples

#### Basic distance calculation

```lua
local function DistanceTo(pos1, pos2)
    return (pos2 - pos1):Length()
end

-- Usage
local me = entities.GetLocalPlayer()
local target = entities.GetByIndex(targetIdx)
local dist = DistanceTo(me:GetAbsOrigin(), target:GetAbsOrigin())
print("Distance: " .. math.floor(dist) .. " units")
```

#### 2D distance (ignore height)

```lua
local function Distance2D(pos1, pos2)
    local delta = pos2 - pos1
    delta.z = 0
    return delta:Length()
end

-- Useful for checking if target is in range on same floor
local me = entities.GetLocalPlayer()
local target = entities.GetByIndex(idx)
local flatDist = Distance2D(me:GetAbsOrigin(), target:GetAbsOrigin())

if flatDist < 500 then
    print("Target is nearby (2D)")
end
```

#### Find closest entity

```lua
local function GetClosestEntity(myPos, entities)
    local closest = nil
    local closestDist = math.huge

    for _, ent in pairs(entities) do
        local dist = (ent:GetAbsOrigin() - myPos):Length()
        if dist < closestDist then
            closest = ent
            closestDist = dist
        end
    end

    return closest, closestDist
end

-- Usage
local me = entities.GetLocalPlayer()
local players = entities.FindByClass("CTFPlayer")
local nearest, dist = GetClosestEntity(me:GetAbsOrigin(), players)
if nearest then
    print("Closest player: " .. nearest:GetName() .. " at " .. math.floor(dist))
end
```
