## Function/Symbol: input.IsMouseInputEnabled

> Check if mouse input is enabled (visible and focused)

### Curated Usage Examples

```lua
if input.IsMouseInputEnabled() then
    local pos = input.GetMousePos()
    draw.Color(0, 255, 0, 255)
    draw.Text(pos[1] + 5, pos[2] + 5, "Mouse active")
end
```

### Notes

- Useful for UI scripts to pause logic when mouse not focused

