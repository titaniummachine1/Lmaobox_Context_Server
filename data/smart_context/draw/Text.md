## Function/Symbol: draw.Text

> Draw text on screen at pixel coordinates

### Required Context

- Parameters: x, y, text (string)
- Requires: draw.Color set; optional font via draw.SetFont
- Coordinates: screen pixels (origin top-left)

### Curated Usage Examples

#### Basic text

```lua
draw.Color(255, 255, 255, 255)
draw.Text(10, 10, "Hello world")
```

#### Centered text

```lua
local function DrawCenteredText(x, y, text)
    local w, h = draw.GetTextSize(text)
    draw.Text(x - w/2, y - h/2, text)
end

local sw, sh = draw.GetScreenSize()
DrawCenteredText(sw/2, 20, "Top Center")
```

#### With custom font

```lua
local font = draw.CreateFont("Tahoma", 14, 600)
draw.SetFont(font)
draw.Color(0, 255, 0, 255)
draw.Text(20, 40, "Bold green text")
```

#### ESP label

```lua
local function DrawLabel(x, y, name, hp)
    draw.Color(255, 255, 255, 255)
    draw.Text(x, y, name)

    draw.Color(0, 255, 0, 255)
    draw.Text(x, y + 12, "HP: " .. hp)
end
```

### Notes

- Set color and font before calling
- Use `draw.GetTextSize` to align text
- Text is not clipped; ensure coordinates are on-screen
