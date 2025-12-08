## Function/Symbol: draw.OutlinedCircle

> Draw an outlined circle using line segments

### Required Context

- Parameters: x, y, radius, segments
- Requires: draw.Color

### Curated Usage Examples

#### Simple outline

```lua
draw.Color(255, 255, 255, 255)
draw.OutlinedCircle(200, 200, 30, 64)
```

#### FOV indicator

```lua
local sw, sh = draw.GetScreenSize()
local radius = 120
local segments = 64
draw.Color(0, 200, 255, 180)
draw.OutlinedCircle(sw/2, sh/2, radius, segments)
```

### Notes

- More segments = smoother circle (costs more draw calls)
