## Function/Symbol: input.IsButtonReleased

> Check if a key/button was just released this tick

### Required Context

- Parameters: KEY\_ constant
- Returns: state (bool), tick (int)

### Curated Usage Examples

#### Release to stop

```lua
local holding = false

callbacks.Register("CreateMove", "release_stop", function()
    local pressed = input.IsButtonPressed(KEY_MOUSE5)
    local released = input.IsButtonReleased(KEY_MOUSE5)

    if pressed then holding = true end
    if released then holding = false end

    if holding then
        -- do something while held
    end
end)
```

### Notes

- Use with IsButtonPressed/Down to manage hold/toggle states

