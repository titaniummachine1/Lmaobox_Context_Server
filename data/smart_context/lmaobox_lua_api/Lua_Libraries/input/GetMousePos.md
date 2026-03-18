## Function/Symbol: input.GetMousePos

> Get current mouse cursor position on screen

### Required Context

- Returns: table {x, y} in screen pixels
- Coordinates: origin at top-left

### Curated Usage Examples

#### Basic read

```lua
local pos = input.GetMousePos()
print("Mouse at: " .. pos[1] .. ", " .. pos[2])
```

#### Draw marker at mouse

```lua
callbacks.Register("Draw", "mouse_marker", function()
    local pos = input.GetMousePos()
    draw.Color(0, 255, 0, 255)
    draw.FilledRect(pos[1] - 2, pos[2] - 2, pos[1] + 2, pos[2] + 2)
end)
```

### Notes

- Values are screen-space pixels

