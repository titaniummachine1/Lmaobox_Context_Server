## Function/Symbol: input.IsButtonPressed

> Check if a key/button was just pressed this tick

### Required Context

- Parameters: KEY\_ constant
- Returns: state (bool), tick (int)

### Curated Usage Examples

#### Edge detection toggle

```lua
local toggled = false

callbacks.Register("CreateMove", "toggle_press", function()
    local pressed, tick = input.IsButtonPressed(KEY_INSERT)
    if pressed then
        toggled = not toggled
        print("Toggle now: " .. tostring(toggled))
    end
end)
```

#### Fire once per press

```lua
callbacks.Register("CreateMove", "once_press", function()
    local pressed = input.IsButtonPressed(KEY_MOUSE4)
    if pressed then
        client.Command("slot3", true)
    end
end)
```

### Notes

- Use `IsButtonPressed` for single-fire actions; `IsButtonDown` for hold

