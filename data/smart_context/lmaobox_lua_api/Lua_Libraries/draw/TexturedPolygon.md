## Function/Symbol: draw.TexturedPolygon

> Draw a textured polygon with custom vertices/UVs

### Required Context

- Parameters: textureId, vertices, clipVertices?
- vertices: array of `{x, y, u, v}` — pixel coords (integers), UV 0-1

### Curated Usage Examples

#### Load a texture from a file

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

#### Solid-color polygon (using a white 2x2 RGBA texture)

Create the texture **once at the top of the file** — never inside a callback.

```lua
-- White 2x2 texture: set draw.Color() to control the actual fill color at draw-time
local WHITE_TEX = draw.CreateTextureRGBA(string.char(
    0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff,
    0xff, 0xff, 0xff, 0xff
), 2, 2)

-- Helper: draw a polygon offset from an origin point
-- vertices: array of {dx, dy} offsets (plain numbers, not Vector3)
local function DrawPolygon(originX, originY, vertices, r, g, b, a)
    local adjusted = {}
    for _, v in ipairs(vertices) do
        -- math.floor is required: draw functions only accept integer pixel coords
        local x = math.floor(originX + v[1])
        local y = math.floor(originY + v[2])
        adjusted[#adjusted + 1] = {x, y, 0, 0}
    end
    draw.Color(r, g, b, a)
    draw.TexturedPolygon(WHITE_TEX, adjusted, false)
end

-- Arrow/pentagon shape offsets
local ARROW_SHAPE = {
    {  0,   0},
    {100,   0},
    { 75, 100},
    { 25, 100},
}

callbacks.Register("Draw", "polygon_example", function()
    local sw, sh = draw.GetScreenSize()
    DrawPolygon(math.floor(sw / 2), math.floor(sh / 2), ARROW_SHAPE, 255, 165, 0, 255)
end)
```

### Notes

- UVs are 0-1 across the texture; for solid colors all UVs can be `0, 0`
- `clipVertices=true` clips to screen bounds; `false` skips the clip (faster)
- **Always** call `draw.Color(r, g, b, a)` before `draw.TexturedPolygon` — color resets each frame
- Coordinates must be **integers** — use `math.floor` on any float origin
- Create textures at **top of file**, never inside callbacks (allocation per frame = memory leak)
- Use `draw.DeleteTexture(id)` if you need to free a texture, but do NOT do this per-frame
- For a solid-color fill: create a white 2x2 RGBA texture once, then tint it with `draw.Color()`
