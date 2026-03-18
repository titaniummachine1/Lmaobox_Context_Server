## Constants Reference: E_FontFlag

> Font rendering flags for `draw.CreateFont(name, size, weight, flags)`

### All Flags

| Constant                | Hex Value | Description                                  |
| ----------------------- | --------- | -------------------------------------------- |
| `FONTFLAG_NONE`         | `0x000`   | No extra rendering                           |
| `FONTFLAG_ITALIC`       | `0x001`   | Italic style                                 |
| `FONTFLAG_UNDERLINE`    | `0x002`   | Underline                                    |
| `FONTFLAG_STRIKEOUT`    | `0x004`   | Strikethrough                                |
| `FONTFLAG_SYMBOL`       | `0x008`   | Symbol charset                               |
| `FONTFLAG_ANTIALIAS`    | `0x010`   | Anti-aliased rendering (smooth edges)        |
| `FONTFLAG_GAUSSIANBLUR` | `0x020`   | Gaussian blur (blurry/glow text)             |
| `FONTFLAG_ROTARY`       | `0x040`   | Rotary font support                          |
| `FONTFLAG_DROPSHADOW`   | `0x080`   | Drop shadow                                  |
| `FONTFLAG_ADDITIVE`     | `0x100`   | Additive blending                            |
| `FONTFLAG_OUTLINE`      | `0x200`   | Outline/border around characters             |
| `FONTFLAG_CUSTOM`       | `0x400`   | Custom font (required for `draw.CreateFont`) |
| `FONTFLAG_BITMAP`       | `0x800`   | Bitmap font (no anti-aliasing)               |

### Curated Usage Examples

#### Most Common: Outlined font (clean ESP text)

```lua
-- Outlined text is the standard for ESP — readable on any background
local font = draw.CreateFont("Arial", 14, 800, FONTFLAG_CUSTOM | FONTFLAG_OUTLINE)
draw.SetFont(font)
draw.Color(255, 255, 255, 255)
draw.Text(x, y, "Target")
```

#### Anti-aliased font (smooth, no border)

```lua
local font = draw.CreateFont("Verdana", 12, 400, FONTFLAG_CUSTOM | FONTFLAG_ANTIALIAS)
```

#### Drop shadow variant

```lua
local font = draw.CreateFont("Tahoma", 13, 700, FONTFLAG_CUSTOM | FONTFLAG_DROPSHADOW)
```

#### Combining flags with bitwise OR

```lua
-- Antialias + dropshadow
local flags = FONTFLAG_CUSTOM | FONTFLAG_ANTIALIAS | FONTFLAG_DROPSHADOW
local font = draw.CreateFont("Arial", 14, 400, flags)
```

### Notes

- `FONTFLAG_CUSTOM` is **required** for fonts created with `draw.CreateFont` — always include it
- Default if `flags` is omitted: `FONTFLAG_CUSTOM | FONTFLAG_ANTIALIAS`
- `FONTFLAG_OUTLINE` and `FONTFLAG_DROPSHADOW` cannot be meaningfully combined (outline takes precedence)
- Font creation should happen at **module init time**, never inside per-frame callbacks
