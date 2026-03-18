## Function: draw.CreateFont

> Create a font for text rendering

### Signature

```lua
---@param name string
---@param height integer
---@param weight integer
---@param flags? E_FontFlag
---@return Font
draw.CreateFont(name, height, weight, flags)
```

### Parameters

- `name` (string) - Font name (e.g., "Verdana", "Arial", "Tahoma")
- `height` (integer) - Font size in pixels
- `weight` (integer) - Font weight
  - `400` = Normal
  - `700` = Bold
  - `800` = Extra Bold
  - `900` = Heavy
- `flags` (optional) - Font flags (default: `FONTFLAG_CUSTOM | FONTFLAG_ANTIALIAS`)

### Returns

`Font` object to use with `draw.SetFont()`

### Basic Usage

```lua
-- Create font
local font = draw.CreateFont("Verdana", 14, 800)

-- Set as active font
draw.SetFont(font)

-- Now you can draw text
draw.Text(10, 10, "Hello")
```

### Common Font Names

Windows fonts available in TF2:

```lua
local verdana = draw.CreateFont("Verdana", 14, 400)
local arial = draw.CreateFont("Arial", 16, 700)
local tahoma = draw.CreateFont("Tahoma", 12, 400)
local courier = draw.CreateFont("Courier New", 14, 400)
```

### Font Weights

```lua
-- Thin to Heavy
local thin = draw.CreateFont("Verdana", 14, 100)
local normal = draw.CreateFont("Verdana", 14, 400)
local bold = draw.CreateFont("Verdana", 14, 700)
local extraBold = draw.CreateFont("Verdana", 14, 800)
local heavy = draw.CreateFont("Verdana", 14, 900)
```

### Performance: Create Once

**Always create fonts at initialization, never per-frame:**

```lua
-- ✅ GOOD - Create at top level
local myFont = draw.CreateFont("Verdana", 14, 800)

local function OnDraw()
    draw.SetFont(myFont)
    draw.Text(10, 10, "Text")
end

-- ❌ BAD - Creates font every frame
local function OnDraw()
    local font = draw.CreateFont("Verdana", 14, 800)
    draw.SetFont(font)
    draw.Text(10, 10, "Text")
end
```

### Example: Multiple Font Styles

```lua
-- Create fonts once
local fonts = {
    title = draw.CreateFont("Arial", 24, 900),
    subtitle = draw.CreateFont("Arial", 18, 700),
    body = draw.CreateFont("Verdana", 14, 400),
    small = draw.CreateFont("Verdana", 11, 400)
}

local function DrawUI()
    -- Title
    draw.SetFont(fonts.title)
    draw.Color(255, 200, 0, 255)
    draw.Text(100, 50, "Main Title")

    -- Subtitle
    draw.SetFont(fonts.subtitle)
    draw.Color(200, 200, 200, 255)
    draw.Text(100, 80, "Subtitle Here")

    -- Body text
    draw.SetFont(fonts.body)
    draw.Color(255, 255, 255, 255)
    draw.Text(100, 110, "Body content...")
end
```

### Example: Monospace Font

```lua
-- For numbers/code display
local monoFont = draw.CreateFont("Courier New", 14, 400)

local function DrawDebug()
    draw.SetFont(monoFont)
    draw.Color(0, 255, 0, 255)

    local y = 10
    draw.Text(10, y, string.format("X: %8.2f", pos.x)); y = y + 15
    draw.Text(10, y, string.format("Y: %8.2f", pos.y)); y = y + 15
    draw.Text(10, y, string.format("Z: %8.2f", pos.z))
end
```

### Notes

- Fonts are cached - creating same font twice is fine
- Invalid font names fall back to default system font
- Font size affects `draw.GetTextSize()` calculations
- Must call `draw.SetFont()` before `draw.Text()`

### Related

- `draw.SetFont` - Set active font
- `draw.Text` - Draw text (requires font)
- `draw.GetTextSize` - Get text dimensions
