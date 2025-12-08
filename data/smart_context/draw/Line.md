## Function/Symbol: draw.Line

> Draw a line between two screen coordinates

### Required Context

- Parameters: x1, y1, x2, y2
- Requires: draw.Color first

### Curated Usage Examples

#### Simple line

```lua
draw.Color(255, 255, 0, 255)
draw.Line(10, 10, 100, 100)
```

#### Snapline ESP

```lua
local function DrawSnapline(x, y)
    local sw, sh = draw.GetScreenSize()
    draw.Color(0, 255, 0, 200)
    draw.Line(sw/2, sh, x, y)
end
```

#### Crosshair lines

```lua
local function DrawSimpleCrosshair()
    local sw, sh = draw.GetScreenSize()
    local cx, cy = sw/2, sh/2
    draw.Color(0, 255, 0, 255)
    draw.Line(cx - 5, cy, cx + 5, cy)
    draw.Line(cx, cy - 5, cx, cy + 5)
end
```

#### Box outline (manual)

```lua
local function DrawBox(x1, y1, x2, y2)
    draw.Line(x1, y1, x2, y1)
    draw.Line(x2, y1, x2, y2)
    draw.Line(x2, y2, x1, y2)
    draw.Line(x1, y2, x1, y1)
end
```

### Notes

- Lines are 1-pixel thick; for thicker lines, draw multiple offset lines
- Always set draw.Color before drawing
