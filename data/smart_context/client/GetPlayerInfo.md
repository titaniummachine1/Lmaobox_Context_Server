## Function/Symbol: client.GetPlayerInfo

> Get detailed info about a player by index

### Required Context
- Parameters: index (integer)
- Returns: {Name, UserID, SteamID, IsBot, IsHLTV} table

### Curated Usage Examples

```lua
local info = client.GetPlayerInfo(playerIdx)
if info then
    print("Name: " .. info.Name)
    print("UserID: " .. info.UserID)
    print("SteamID: " .. info.SteamID)
    print("Is bot: " .. tostring(info.IsBot))
end
```

### Notes
- UserID/SteamID only available when fully connected
