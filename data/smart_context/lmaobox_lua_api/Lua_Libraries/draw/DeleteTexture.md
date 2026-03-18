## Function/Symbol: draw.DeleteTexture

> Delete a texture created with draw.CreateTexture/Draw.CreateTextureRGBA

### Required Context

- Parameters: textureId
- Use on unload/cleanup

### Curated Usage Examples

```lua
local texId = draw.CreateTexture("materials/vgui/replay/thumbnails/default.jpg")

callbacks.Register("Unload", "cleanup_tex", function()
    if texId then
        draw.DeleteTexture(texId)
        texId = nil
    end
end)
```

### Notes

- Always free textures you create to avoid leaks

