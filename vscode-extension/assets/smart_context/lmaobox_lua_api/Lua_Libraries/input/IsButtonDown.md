## Function/Symbol: input.IsButtonDown

> Check if a key/button is currently held down

### Required Context

- Parameters: KEY\_ constant (e.g., KEY_MOUSE1, KEY_SPACE)
- Returns: boolean

### Curated Usage Examples

#### Simple check

```lua
if input.IsButtonDown(KEY_SPACE) then
    print("Space is held")
end
```

#### Toggle on key press (edge detection)

```lua
local toggled = false
local last = false

callbacks.Register("CreateMove", "key_toggle", function()
    local down = input.IsButtonDown(KEY_MOUSE3)
    if down and not last then
        toggled = not toggled
        print("Toggled: " .. tostring(toggled))
    end
    last = down
end)
```

#### Hold-to-aim

```lua
callbacks.Register("CreateMove", "hold_aim", function(cmd)
    if not input.IsButtonDown(KEY_MOUSE2) then return end
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end
    -- aim logic here
end)
```

### Notes

- Use edge detection (current vs previous) for toggles
- For mouse wheel/buttons, use correct KEY\_ constants
