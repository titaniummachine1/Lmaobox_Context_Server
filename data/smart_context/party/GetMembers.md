## Function/Symbol: party.GetMembers

> Get table of party members' SteamID3s

### Curated Usage Examples

```lua
local members = party.GetMembers()
if members then
    for _, steamID in pairs(members) do
        print("Party member: " .. steam.GetPlayerName(steamID))
    end
end
```

### Notes
- Returns nil if not in a party
