## Function/Symbol: input.SetMouseInputEnabled

> Enable/disable mouse visibility and focus on topmost panel

### Curated Usage Examples

#### Toggle mouse for UI

```lua
local uiOpen = false
callbacks.Register("CreateMove", "toggle_ui", function()
    if input.IsButtonPressed(KEY_INSERT) then
        uiOpen = not uiOpen
        input.SetMouseInputEnabled(uiOpen)
    end
end)
```

### Notes

- When enabled, mouse is visible and captures input for UI
- Remember to disable on unload if you enabled it

