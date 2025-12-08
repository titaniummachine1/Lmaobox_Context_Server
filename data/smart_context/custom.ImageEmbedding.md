## Pattern: Embed Images in Lua Scripts

> Embed images as binary data strings for portable textures

### Required Context

- Functions: draw.CreateTextureRGBA
- External tool: https://github.com/titaniummachine1/lua-image-embeding
- Format: \xXX escaped bytes with dimensions header

### Curated Usage Examples

#### Image data format

```lua
-- Format: first 8 bytes = width and height (big-endian), then RGBA data
local binary_image = [[
\x00\x00\x00\x10\x00\x00\x00\x10
\xff\x00\x00\xff\xff\x00\x00\xff...
]]
-- ^ Width=16, Height=16, then 16*16*4 bytes of RGBA
```

#### Parse embedded image

```lua
local function to_raw_bytes(data)
    local raw = {}
    for byte in data:gmatch("\\x(%x%x)") do
        table.insert(raw, string.char(tonumber(byte, 16)))
    end
    return table.concat(raw)
end

local function extract_dimensions(data)
    local width = (data:byte(1) * 16777216) + (data:byte(2) * 65536) +
                  (data:byte(3) * 256) + data:byte(4)
    local height = (data:byte(5) * 16777216) + (data:byte(6) * 65536) +
                   (data:byte(7) * 256) + data:byte(8)
    return width, height
end

local function create_texture_from_binary(binary_data)
    local raw_binary = to_raw_bytes(binary_data)
    local width, height = extract_dimensions(raw_binary)
    local rgba_data = raw_binary:sub(9)
    return draw.CreateTextureRGBA(rgba_data, width, height), width, height
end
```

#### Draw embedded texture

```lua
local texture, width, height = create_texture_from_binary(binary_image)

callbacks.Register("Draw", "draw_image", function()
    draw.Color(255, 255, 255, 255)
    draw.TexturedRect(texture, 100, 100, 100 + width, 100 + height)
end)
```

#### Cleanup

```lua
callbacks.Register("Unload", "cleanup_texture", function()
    if texture then
        draw.DeleteTexture(texture)
    end
end)
```

### Image Embedding Tool

- Tool: https://github.com/titaniummachine1/lua-image-embeding
- Converts PNG/JPG to Lua string format
- Automatically adds dimension header (8 bytes)
- Output is copy-paste ready for Lua scripts

### Notes

- Keep images small (power-of-two dimensions recommended)
- Large images increase script file size
- Delete texture on unload to avoid leaks
- Binary data goes at top of script, parsing functions after

