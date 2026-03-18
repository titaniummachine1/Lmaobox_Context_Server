## Function/Symbol: draw.TexturedPolygon

> Draw a textured polygon with custom vertices/UVs

### Required Context

- Parameters: textureId, vertices, clipVertices?
- vertices: array of {x, y, u, v}

### Curated Usage Examples

```lua
local texId = draw.CreateTexture("materials/vgui/replay/thumbnails/default.jpg")
local verts = {
    {100, 100, 0, 0},
    {200, 100, 1, 0},
    {200, 200, 1, 1},
    {100, 200, 0, 1},
}

callbacks.Register("Draw", "tex_poly", function()
    if texId then
        draw.TexturedPolygon(texId, verts, true)
    end
end)
```

### Notes

- UVs are 0-1 across the texture
- clipVertices=true will clip to screen

