## Function: draw.Text

> Draw text at screen coordinates

### Signature

```lua
draw.Text(x, y, text)
```

### Parameters

- `x` (integer) - Screen X coordinate
- `y` (integer) - Screen Y coordinate
- `text` (string) - Text to draw

### Critical Requirement

**You MUST call `draw.SetFont()` before using `draw.Text()` or it will error.**

### Setup Pattern

```lua
-- Create font ONCE (typically at script load)
local font = draw.CreateFont("Verdana", 14, 800)
draw.SetFont(font)

-- Now you can draw text
draw.Color(255, 255, 255, 255)
draw.Text(10, 10, "Hello World")
```

### Common Mistake

```lua
-- ❌ WRONG - Will error "Font not set"
draw.Text(10, 10, "Text")

-- ✅ CORRECT
local font = draw.CreateFont("Verdana", 14, 800)
draw.SetFont(font)
draw.Text(10, 10, "Text")
```

### Font Creation

```lua
---@param name string -- Font name (e.g., "Verdana", "Arial")
---@param height integer -- Font size in pixels
---@param weight integer -- Font weight (400=normal, 800=bold)
---@param flags? E_FontFlag -- Optional flags (default: FONTFLAG_CUSTOM | FONTFLAG_ANTIALIAS)
---@return Font
draw.CreateFont(name, height, weight, flags)
```

### Example: HUD Text

```lua
local hudFont = draw.CreateFont("Tahoma", 16, 800)

local function OnDraw()
    draw.SetFont(hudFont)
    draw.Color(255, 255, 255, 255)

    local x, y = 10, 10
    draw.Text(x, y, "FPS: " .. math.floor(1 / globals.FrameTime()))
    draw.Text(x, y + 20, "Tick: " .. globals.TickCount())
end

callbacks.Register("Draw", "HUD", OnDraw)
```

### Example: Multiple Fonts

```lua
local titleFont = draw.CreateFont("Arial", 24, 800)
local bodyFont = draw.CreateFont("Verdana", 14, 400)

local function OnDraw()
    -- Draw title
    draw.SetFont(titleFont)
    draw.Color(255, 200, 0, 255)
    draw.Text(100, 50, "Title Text")

    -- Draw body (switch font)
    draw.SetFont(bodyFont)
    draw.Color(255, 255, 255, 255)
    draw.Text(100, 80, "Body text here")
end
```

### Performance Tip

Create fonts once at script initialization, not every frame:

```lua
-- ✅ GOOD - Create once
local font = draw.CreateFont("Verdana", 14, 800)

local function OnDraw()
    draw.SetFont(font)
    draw.Text(10, 10, "Text")
end

-- ❌ BAD - Creates new font every frame (slow)
local function OnDraw()
    local font = draw.CreateFont("Verdana", 14, 800)
    draw.SetFont(font)
    draw.Text(10, 10, "Text")
end
```

### Related

- `draw.CreateFont` - Create font object
- `draw.SetFont` - Set active font
- `draw.Color` - Set text color
- `draw.GetTextSize` - Calculate text dimensions
