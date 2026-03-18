## Function/Symbol: draw.GetTextSize

> Get width/height of text for current font

### Required Context

- Parameters: text (string)
- Returns: width, height
- Font: uses current font set via draw.SetFont (default if none)

### Curated Usage Examples

#### Center text

```lua
local function DrawCentered(x, y, text)
    local w, h = draw.GetTextSize(text)
    draw.Text(x - w/2, y - h/2, text)
end

local sw, sh = draw.GetScreenSize()
DrawCentered(sw/2, 30, "Centered text")
```

#### Align right

```lua
local function DrawRightAligned(x, y, text)
    local w, _ = draw.GetTextSize(text)
    draw.Text(x - w, y, text)
end

DrawRightAligned(300, 10, "Right aligned")
```

#### Measure for backgrounds

```lua
local function DrawLabelWithBg(x, y, text)
    local w, h = draw.GetTextSize(text)
    draw.Color(0, 0, 0, 160)
    draw.FilledRect(x - 2, y - 2, x + w + 2, y + h + 2)
    draw.Color(255, 255, 255, 255)
    draw.Text(x, y, text)
end
```

### Notes

- Call **after** setting font and color
- Use measurements to align/box text cleanly
