## Function/Symbol: client.GetPlayerNameByUserID

> Get player name by userID (from GameEvent)

### Curated Usage Examples

```lua
callbacks.Register("FireGameEvent", "name_from_event", function(ev)
    if ev:GetName() == "player_death" then
        local name = client.GetPlayerNameByUserID(ev:GetInt("userid"))
        print(name .. " died")
    end
end)
```

### Notes
- Use in FireGameEvent callbacks
