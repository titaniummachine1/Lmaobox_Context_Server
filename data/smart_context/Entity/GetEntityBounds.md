## Pattern: Get Entity Collision Bounds (AABB)

> Get the axis-aligned bounding box for physics/collision

### Basic Usage

```lua
---@param entity Entity
---@return Vector3 mins, Vector3 maxs
local function GetEntityBounds(entity)
    local mins = entity:GetMins()
    local maxs = entity:GetMaxs()
    return mins, maxs
end
```

### Returns

- **mins**: Bottom-back-left corner offset from origin
- **maxs**: Top-front-right corner offset from origin

Example: Standing player

- `mins = Vector3(-24, -24, 0)`
- `maxs = Vector3(24, 24, 82)`

### World Space Bounds

```lua
-- Get world-space AABB corners
local function GetWorldBounds(entity)
    local origin = entity:GetAbsOrigin()
    local mins, maxs = GetEntityBounds(entity)

    local worldMins = origin + mins
    local worldMaxs = origin + maxs

    return worldMins, worldMaxs
end
```

### Visualize Bounds

```lua
local function DrawEntityBounds(entity)
    local origin = entity:GetAbsOrigin()
    local mins = entity:GetMins()
    local maxs = entity:GetMaxs()

    local corners = {
        origin + mins,
        origin + maxs,
        origin + Vector3(mins.x, maxs.y, mins.z),
        origin + Vector3(maxs.x, mins.y, mins.z),
        -- ... etc
    }

    -- Draw box outline
    draw.Color(255, 255, 0, 255)
    for _, corner in ipairs(corners) do
        local screen = client.WorldToScreen(corner)
        if screen then
            draw.FilledRect(screen[1] - 2, screen[2] - 2, screen[1] + 2, screen[2] + 2)
        end
    end
end
```

### Use with TraceHull

```lua
-- Check if path is clear
local function IsPathClear(entity, targetPos)
    local startPos = entity:GetAbsOrigin()
    local mins, maxs = GetEntityBounds(entity)

    local trace = engine.TraceHull(
        startPos,
        targetPos,
        mins,
        maxs,
        MASK_PLAYERSOLID
    )

    return trace.fraction == 1  -- No collision if fraction is 1
end
```

### Class-Specific Sizes

Different entity types have different bounds:

```lua
-- Scout: smaller
-- mins = Vector3(-24, -24, 0)
-- maxs = Vector3(24, 24, 82)

-- Heavy: same width, different maxs.z when spun up
-- Sentry: different shape entirely

-- Always use GetMins()/GetMaxs() for accurate bounds
```

### Ducking Detection

Players have different bounds when crouching:

```lua
local function IsDucking(entity)
    local flags = entity:GetPropInt("m_fFlags")
    return (flags & FL_DUCKING) ~= 0
end

-- Note: GetMaxs() already returns correct ducked height
-- No need to manually adjust
```

### Notes

- AABB (Axis-Aligned Bounding Box) is used for physics/movement
- Different from hitboxes (used for damage)
- Values are offsets from entity origin (`GetAbsOrigin()`)
- Updated automatically when entity ducks/changes state
- Use with `TraceHull` for collision detection
