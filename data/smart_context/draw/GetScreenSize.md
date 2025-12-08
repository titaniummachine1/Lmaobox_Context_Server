## Function/Symbol: draw.GetScreenSize

> Get the current screen resolution (width, height)

### Required Context

- Returns: width, height (integers)

### Curated Usage Examples

#### Center screen coordinates

```lua
local w, h = draw.GetScreenSize()
local cx, cy = w/2, h/2
```

#### Position elements relative to screen

```lua
local sw, sh = draw.GetScreenSize()
draw.Text(sw - 150, 20, "Top-right text")
```

#### Normalize positions

```lua
local sw, sh = draw.GetScreenSize()
local function ToScreenPercent(px, py)
    return px / sw, py / sh
end
```

### Notes

- Useful for centering, snaplines, crosshairs, UI layout
