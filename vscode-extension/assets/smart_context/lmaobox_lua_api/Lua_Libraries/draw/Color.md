## Function/Symbol: draw.Color

> Set the color for subsequent draw calls

### Required Context

- Parameters: r, g, b, a (integers 0-255)
- Affects: All draw.\* functions until next Color() call
- Types: Integers for RGBA values

### Curated Usage Examples

#### Basic colors

```lua
-- Red
draw.Color(255, 0, 0, 255)
draw.FilledRect(10, 10, 50, 50)

-- Green with transparency
draw.Color(0, 255, 0, 128)
draw.FilledRect(60, 10, 100, 50)

-- White
draw.Color(255, 255, 255, 255)
draw.Text(10, 60, "White text")
```

#### Team colors

```lua
local function SetTeamColor(teamNum, alpha)
    alpha = alpha or 255

    if teamNum == 2 then
        draw.Color(255, 0, 0, alpha) -- RED team
    elseif teamNum == 3 then
        draw.Color(0, 0, 255, alpha) -- BLU team
    else
        draw.Color(255, 255, 255, alpha) -- Spectator/unknown
    end
end

-- Usage in ESP
for _, player in pairs(entities.FindByClass("CTFPlayer")) do
    if player:IsAlive() then
        SetTeamColor(player:GetTeamNumber())
        -- Draw ESP box here
    end
end
```

#### Health-based color

```lua
local function SetHealthColor(health, maxHealth)
    local healthPercent = health / maxHealth

    if healthPercent > 0.75 then
        draw.Color(0, 255, 0, 255) -- Green
    elseif healthPercent > 0.5 then
        draw.Color(255, 255, 0, 255) -- Yellow
    elseif healthPercent > 0.25 then
        draw.Color(255, 165, 0, 255) -- Orange
    else
        draw.Color(255, 0, 0, 255) -- Red
    end
end

-- Usage
local player = entities.GetLocalPlayer()
if player then
    SetHealthColor(player:GetHealth(), player:GetMaxHealth())
    draw.Text(10, 10, "HP: " .. player:GetHealth())
end
```

#### Visibility-based color

```lua
-- Green if visible, red if occluded
local function SetVisibilityColor(isVisible)
    if isVisible then
        draw.Color(0, 255, 0, 255) -- Green = can see
    else
        draw.Color(255, 0, 0, 255) -- Red = behind wall
    end
end

-- Usage in wallhack ESP
for _, player in pairs(enemies) do
    local visible = IsVisible(eyePos, player:GetAbsOrigin(), me)
    SetVisibilityColor(visible)
    -- Draw ESP
end
```

#### Gradient effect (manual)

```lua
-- Draw a vertical gradient bar
local function DrawGradientBar(x, y, w, h)
    local steps = h

    for i = 0, steps do
        local percent = i / steps
        local red = math.floor(255 * percent)
        local green = math.floor(255 * (1 - percent))

        draw.Color(red, green, 0, 255)
        draw.FilledRect(x, y + i, x + w, y + i + 1)
    end
end

DrawGradientBar(10, 10, 20, 100)
```

### Common Colors

```lua
-- Primary colors
draw.Color(255, 0, 0, 255)   -- Red
draw.Color(0, 255, 0, 255)   -- Green
draw.Color(0, 0, 255, 255)   -- Blue

-- Utility colors
draw.Color(255, 255, 255, 255) -- White
draw.Color(0, 0, 0, 255)       -- Black
draw.Color(255, 255, 0, 255)   -- Yellow
draw.Color(255, 0, 255, 255)   -- Magenta
draw.Color(0, 255, 255, 255)   -- Cyan

-- Transparency
draw.Color(255, 255, 255, 128) -- 50% transparent white
draw.Color(0, 0, 0, 200)       -- Nearly opaque black
```

### Notes

- **Alpha channel** (4th parameter): 0 = fully transparent, 255 = fully opaque
- Color **persists** until you call `draw.Color()` again
- Set color **before** drawing (affects next draw call)
- **Performance**: Minimize color changes per frame
