## Function/Symbol: draw.CreateTextureRGBA

> Create a texture from raw RGBA string data

### Required Context

- Parameters: rgbaData (string), width, height (power-of-two recommended)
- Returns: TextureID

### Curated Usage Examples

```lua
-- Example solid red 2x2 texture
local rgba = string.char(
    255,0,0,255, 255,0,0,255,
    255,0,0,255, 255,0,0,255
)
local texId = draw.CreateTextureRGBA(rgba, 2, 2)

callbacks.Register("Draw", "tex_rgba", function()
    draw.TexturedRect(texId, 10, 10, 50, 50)
end)
```

### Notes

- Useful for dynamic or generated images
- Keep data size small; power-of-two dims avoid artifacts

