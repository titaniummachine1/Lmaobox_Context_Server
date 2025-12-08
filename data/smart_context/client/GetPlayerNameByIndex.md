## Function/Symbol: client.GetPlayerNameByIndex

> Get player name by entity index

### Curated Usage Examples

```lua
local name = client.GetPlayerNameByIndex(playerIdx)
print("Player " .. playerIdx .. ": " .. name)
```

### Notes
- Alternative to `entities.GetByIndex(idx):GetName()`

