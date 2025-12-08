## Function/Symbol: steam.IsFriend

> Check if a SteamID is in your friends list

### Curated Usage Examples

```lua
local info = client.GetPlayerInfo(playerIdx)
if info and steam.IsFriend(info.SteamID) then
    print(info.Name .. " is your friend")
end
```

### Notes
- Use to avoid targeting friends
