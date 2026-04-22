## Pattern: Draw Filled Circle (via TexturedPolygon)

> Draw a filled circle using polygon vertices

### Required Context

- Functions: draw.CreateTextureRGBA, draw.TexturedPolygon
- Pattern: Generate circle vertices, use white texture for coloring

### Curated Usage Examples

#### Create white texture for coloring

```lua
local whiteTexture = draw.CreateTextureRGBA(string.char(
    0xff, 0xff, 0xff, 255,
    0xff, 0xff, 0xff, 255,
    0xff, 0xff, 0xff, 255,
    0xff, 0xff, 0xff, 255
), 2, 2)
```

#### Generate circle vertices

```lua
local function GenerateCircleVertices(radius)
    local vertices = {}
    local numSegments = math.max(12, math.floor(radius * 2 * math.pi))
    local angleStep = (2 * math.pi) / numSegments

    for i = 0, numSegments do
        local theta = i * angleStep
        local x = radius * math.cos(theta)
        local y = radius * math.sin(theta)
        table.insert(vertices, {math.floor(x + 0.5), math.floor(y + 0.5)})
    end

    return vertices
end
```

#### Draw filled circle

```lua
local function DrawCircleFilled(originX, originY, radius, r, g, b, a)
    local circleVertices = GenerateCircleVertices(radius)

    local adjustedVertices = {}
    for _, vertex in ipairs(circleVertices) do
        local x = originX + vertex[1]
        local y = originY + vertex[2]
        table.insert(adjustedVertices, {x, y, 0, 0})
    end

    draw.Color(r, g, b, a)
    draw.TexturedPolygon(whiteTexture, adjustedVertices, false)
end

-- Usage
DrawCircleFilled(200, 200, 50, 255, 165, 0, 200) -- Orange circle
```

### Notes

- Create white texture once at startup
- Polygon vertices need {x, y, u, v} format (u,v = 0 for solid color)
- More segments = smoother but more expensive
- Use draw.OutlinedCircle for just outline

