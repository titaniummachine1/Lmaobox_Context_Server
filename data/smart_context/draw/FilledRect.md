## Function/Symbol: draw.FilledRect

> Draw a filled rectangle on screen

### Required Context

- Parameters: x1, y1, x2, y2 (top-left and bottom-right corners)
- Requires: draw.Color() called first
- Types: Integers for screen coordinates

### Curated Usage Examples

#### Basic rectangle

```lua
-- Set color first
draw.Color(255, 0, 0, 255)

-- Draw 100x50 red rectangle at (10, 10)
draw.FilledRect(10, 10, 110, 60)
```

#### ESP box around player

```lua
local function DrawESPBox(player)
    -- Get player's screen position
    local pos = player:GetAbsOrigin()
    local headPos = pos + Vector3(0, 0, 80) -- Approximate head height

    -- Convert world to screen
    local screenPos = client.WorldToScreen(pos)
    local screenHead = client.WorldToScreen(headPos)

    if not screenPos or not screenHead then return end

    -- Calculate box dimensions
    local height = screenPos[2] - screenHead[2]
    local width = height / 2

    local x1 = screenPos[1] - width / 2
    local y1 = screenHead[2]
    local x2 = screenPos[1] + width / 2
    local y2 = screenPos[2]

    -- Draw filled box
    draw.Color(255, 0, 0, 50) -- Semi-transparent red
    draw.FilledRect(x1, y1, x2, y2)

    -- Draw outline
    draw.Color(255, 255, 255, 255)
    draw.OutlinedRect(x1, y1, x2, y2)
end

-- Usage
for _, player in pairs(entities.FindByClass("CTFPlayer")) do
    if player:IsAlive() and player ~= entities.GetLocalPlayer() then
        DrawESPBox(player)
    end
end
```

#### Health bar

```lua
local function DrawHealthBar(x, y, w, h, health, maxHealth)
    -- Background (dark)
    draw.Color(0, 0, 0, 200)
    draw.FilledRect(x, y, x + w, y + h)

    -- Health fill
    local healthPercent = health / maxHealth
    local fillWidth = w * healthPercent

    -- Color based on health
    if healthPercent > 0.6 then
        draw.Color(0, 255, 0, 255) -- Green
    elseif healthPercent > 0.3 then
        draw.Color(255, 255, 0, 255) -- Yellow
    else
        draw.Color(255, 0, 0, 255) -- Red
    end

    draw.FilledRect(x, y, x + fillWidth, y + h)

    -- Border
    draw.Color(255, 255, 255, 255)
    draw.OutlinedRect(x, y, x + w, y + h)
end

-- Usage
local me = entities.GetLocalPlayer()
if me then
    DrawHealthBar(10, 10, 200, 20, me:GetHealth(), me:GetMaxHealth())
end
```

#### Crosshair

```lua
local function DrawCrosshair()
    local screenW, screenH = draw.GetScreenSize()
    local centerX = screenW / 2
    local centerY = screenH / 2

    local size = 10
    local gap = 5
    local thickness = 2

    draw.Color(0, 255, 0, 255)

    -- Top
    draw.FilledRect(centerX - thickness/2, centerY - gap - size,
                    centerX + thickness/2, centerY - gap)

    -- Bottom
    draw.FilledRect(centerX - thickness/2, centerY + gap,
                    centerX + thickness/2, centerY + gap + size)

    -- Left
    draw.FilledRect(centerX - gap - size, centerY - thickness/2,
                    centerX - gap, centerY + thickness/2)

    -- Right
    draw.FilledRect(centerX + gap, centerY - thickness/2,
                    centerX + gap + size, centerY + thickness/2)
end

DrawCrosshair()
```

#### Progress bar

```lua
local function DrawProgressBar(x, y, w, h, progress, label)
    -- Clamp progress 0-1
    progress = math.max(0, math.min(1, progress))

    -- Background
    draw.Color(0, 0, 0, 200)
    draw.FilledRect(x, y, x + w, y + h)

    -- Progress fill
    local fillWidth = w * progress
    draw.Color(0, 150, 255, 255)
    draw.FilledRect(x, y, x + fillWidth, y + h)

    -- Border
    draw.Color(255, 255, 255, 255)
    draw.OutlinedRect(x, y, x + w, y + h)

    -- Text
    if label then
        local textW, textH = draw.GetTextSize(label)
        draw.Text(x + w/2 - textW/2, y + h/2 - textH/2, label)
    end
end

-- Usage: charge meter
local charge = 0.75 -- 75% charged
DrawProgressBar(10, 50, 200, 30, charge, "Charge: " .. math.floor(charge * 100) .. "%")
```

### Notes

- **Coordinates**: (x1, y1) = top-left, (x2, y2) = bottom-right
- **Call draw.Color()** before drawing to set the color
- **Alpha channel** in Color() controls transparency
- For just an outline, use `draw.OutlinedRect()` instead
- **Performance**: Minimize draw calls per frame
