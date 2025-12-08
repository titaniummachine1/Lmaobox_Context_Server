## Function/Symbol: draw.TexturedRect

> Draw a textured rectangle

### Required Context

- Parameters: textureId, x1, y1, x2, y2
- Requires: valid TextureID from CreateTexture/CreateTextureRGBA

### Curated Usage Examples

```lua
local texId = draw.CreateTexture("materials/vgui/replay/thumbnails/default.jpg")

callbacks.Register("Draw", "tex_rect", function()
    if not texId then return end
    draw.TexturedRect(texId, 50, 50, 150, 150)
end)
```

### Notes

- Coordinates are in screen pixels
- Manage texture lifecycle; delete on unload

