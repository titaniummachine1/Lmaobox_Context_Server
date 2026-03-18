## Function/Symbol: draw.OutlinedRect

> Draw an outlined rectangle on screen

### Required Context

- Parameters: x1, y1, x2, y2
- Requires: draw.Color set first

### Curated Usage Examples

#### Basic outline

```lua
draw.Color(255, 255, 255, 255)
draw.OutlinedRect(10, 10, 110, 60)
```

#### ESP box outline (paired with filled rect)

```lua
local function DrawESPBox(x1, y1, x2, y2)
    draw.Color(255, 0, 0, 40) -- fill
    draw.FilledRect(x1, y1, x2, y2)
    draw.Color(255, 255, 255, 255) -- outline
    draw.OutlinedRect(x1, y1, x2, y2)
end
```

#### Health bar border

```lua
local function DrawHealthBar(x, y, w, h, percent)
    draw.Color(0, 0, 0, 200)
    draw.FilledRect(x, y, x + w, y + h)
    draw.Color(0, 200, 50, 255)
    draw.FilledRect(x, y, x + w * percent, y + h)
    draw.Color(255, 255, 255, 255)
    draw.OutlinedRect(x, y, x + w, y + h)
end
```

### Notes

- Combine with `draw.FilledRect` for filled + border
- Coordinates are pixel positions (top-left origin)
