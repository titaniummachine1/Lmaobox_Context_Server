## Function/Symbol: draw.CreateFont

> Create a font for drawing text

### Required Context

- Parameters: name, height, weight, flags (optional)
- Returns: Font handle
- After creation, call draw.SetFont before drawing

### Curated Usage Examples

#### Basic font creation

```lua
local font = draw.CreateFont("Tahoma", 14, 600)
draw.SetFont(font)
draw.Color(255, 255, 255, 255)
draw.Text(10, 10, "Bold Tahoma 14")
```

#### Multiple fonts

```lua
local titleFont = draw.CreateFont("Verdana", 18, 800)
local infoFont  = draw.CreateFont("Verdana", 14, 500)

-- Title
draw.SetFont(titleFont)
draw.Color(255, 200, 0, 255)
draw.Text(20, 20, "ESP Overlay")

-- Info
draw.SetFont(infoFont)
draw.Color(255, 255, 255, 255)
draw.Text(20, 40, "Players: " .. playerCount)
```

#### Custom TTF resource

```lua
-- If you added a TTF via draw.AddFontResource("custom.ttf")
local customFont = draw.CreateFont("custom", 16, 600, FONTFLAG_ANTIALIAS)
draw.SetFont(customFont)
draw.Text(10, 60, "Custom font text")
```

### Notes

- Common weights: 400 (normal), 600 (semi-bold), 800 (bold)
- Flags: FONTFLAG_ANTIALIAS, FONTFLAG_DROPSHADOW, etc.
- Must call `draw.SetFont(font)` before measuring or drawing text
