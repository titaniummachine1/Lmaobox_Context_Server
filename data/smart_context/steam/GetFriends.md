## Function/Symbol: steam.GetFriends

> Get table of all friends' SteamID3s

### Curated Usage Examples

```lua
local friends = steam.GetFriends()
for _, steamID in pairs(friends) do
    print("Friend: " .. steam.GetPlayerName(steamID))
end
```

### Notes
- Returns array of SteamID3 strings
