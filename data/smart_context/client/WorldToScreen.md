## Function/Symbol: client.WorldToScreen

> Convert 3D world position to 2D screen coordinates

### Required Context
- Parameters: position (Vector3), view (ViewSetup, optional)
- Returns: {x, y} table or nil (if off-screen)

### Curated Usage Examples

#### Basic world-to-screen
```lua
local pos = target:GetAbsOrigin()
local screen = client.WorldToScreen(pos)

if screen then
    draw.Color(255, 0, 0, 255)
    draw.Text(screen[1], screen[2], target:GetName())
end
```

#### ESP box from world bounds
```lua
local function DrawEntityBox(ent)
    local origin = ent:GetAbsOrigin()
    local mins = ent:GetMins()
    local maxs = ent:GetMaxs()
    
    local corners = {
        origin + Vector3(mins.x, mins.y, mins.z),
        origin + Vector3(maxs.x, mins.y, mins.z),
        origin + Vector3(maxs.x, maxs.y, mins.z),
        origin + Vector3(mins.x, maxs.y, mins.z),
        origin + Vector3(mins.x, mins.y, maxs.z),
        origin + Vector3(maxs.x, mins.y, maxs.z),
        origin + Vector3(maxs.x, maxs.y, maxs.z),
        origin + Vector3(mins.x, maxs.y, maxs.z),
    }
    
    local screenCorners = {}
    for _, corner in ipairs(corners) do
        local screen = client.WorldToScreen(corner)
        if not screen then return end
        table.insert(screenCorners, screen)
    end
    
    -- Find bounding box in screen space
    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for _, sc in ipairs(screenCorners) do
        minX = math.min(minX, sc[1])
        minY = math.min(minY, sc[2])
        maxX = math.max(maxX, sc[1])
        maxY = math.max(maxY, sc[2])
    end
    
    draw.Color(255, 0, 0, 255)
    draw.OutlinedRect(minX, minY, maxX, maxY)
end
```

### Notes
- Returns nil if position is off-screen or behind camera
- Always nil-check result before using
- Use for ESP, labels, snaplines
