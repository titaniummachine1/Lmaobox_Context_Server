## Function/Symbol: draw.FilledRectFade

> Draw a filled rectangle with fading alpha horizontally or vertically

### Required Context

- Parameters: x1, y1, x2, y2, alpha1, alpha2, horizontal?
- Requires: draw.Color set first (for base color)

### Curated Usage Examples

#### Horizontal fade (default)

```lua
draw.Color(255, 0, 0, 255)
draw.FilledRectFade(10, 10, 110, 40, 255, 0) -- left to right fade
```

#### Vertical fade

```lua
draw.Color(0, 0, 255, 255)
draw.FilledRectFade(10, 50, 110, 80, 255, 0, false) -- top to bottom fade
```

#### Health bar with fade

```lua
local function HealthBar(x, y, w, h, pct)
    local fill = w * pct
    draw.Color(0, 200, 0, 255)
    draw.FilledRectFade(x, y, x + fill, y + h, 255, 100) -- fade to lighter
    draw.Color(255, 255, 255, 255)
    draw.OutlinedRect(x, y, x + w, y + h)
end
```

### Notes

- Alpha1/alpha2 are 0-255
- horizontal defaults to true; pass false for vertical
