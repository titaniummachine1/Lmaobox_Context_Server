## Function/Symbol: draw.SetFont

> Set the current font for subsequent text drawing

### Required Context

- Parameters: font (from draw.CreateFont)
- Affects: draw.Text, draw.TextShadow, draw.GetTextSize

### Curated Usage Examples

```lua
local titleFont = draw.CreateFont("Verdana", 18, 800)
draw.SetFont(titleFont)
draw.Color(255, 200, 0, 255)
draw.Text(20, 20, "Title")
```

### Notes

- Call after `draw.CreateFont`
- Must set before measuring or drawing text

