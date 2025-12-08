## Function/Symbol: draw.ColoredCircle

> Draw a filled colored circle

### Required Context

- Parameters: centerX, centerY, radius, r, g, b, a
- Requires: nothing else (color per call)

### Curated Usage Examples

#### Basic circle

```lua
draw.ColoredCircle(100, 100, 20, 255, 0, 0, 200)
```

#### Radar blip

```lua
local function DrawBlip(x, y, friendly)
    if friendly then
        draw.ColoredCircle(x, y, 4, 0, 255, 0, 255)
    else
        draw.ColoredCircle(x, y, 4, 255, 0, 0, 255)
    end
end
```

### Notes

- For outlines, use `draw.OutlinedCircle`
