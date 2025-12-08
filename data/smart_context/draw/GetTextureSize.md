## Function/Symbol: draw.GetTextureSize

> Get width/height of a texture

### Required Context

- Parameters: textureId (TextureID)
- Returns: width, height

### Curated Usage Examples

```lua
local w, h = draw.GetTextureSize(texId)
draw.TexturedRect(texId, 10, 10, 10 + w, 10 + h)
```

### Notes

- Call after creating the texture

