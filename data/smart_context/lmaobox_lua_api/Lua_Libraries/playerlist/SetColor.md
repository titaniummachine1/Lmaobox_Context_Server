## Function/Symbol: playerlist.SetColor

> Set player's color in playerlist/ESP

### Curated Usage Examples

```lua
local player = entities.GetByIndex(idx)
if player then
    playerlist.SetColor(player, 0xFF0000FF) -- red
end
```

### Notes
- Color is RGBA as integer (0xRRGGBBAA)

