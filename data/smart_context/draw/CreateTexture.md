## Function/Symbol: draw.CreateTexture

> Create a texture from an image file

### Required Context

- Parameters: texturePath (string). If relative, searches LocalAppData then TF2 root
- Supported: PNG, JPG, BMP, TGA, VTF
- Returns: TextureID
- Image dimensions should be power-of-two to avoid checker artifacts

### Curated Usage Examples

```lua
local texId = draw.CreateTexture("materials/vgui/replay/thumbnails/default.jpg")

callbacks.Register("Draw", "tex_demo", function()
    if not texId then return end
    draw.TexturedRect(texId, 50, 50, 150, 150)
end)
```

### Notes

- Store the TextureID and reuse; delete on unload with draw.DeleteTexture

