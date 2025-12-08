## Function/Symbol: entities.GetByUserID

> Get an entity by userID (from game events)

### Required Context

- Parameters: userID (integer from GameEvent)
- Returns: Entity or nil

### Curated Usage Examples

#### From player_death event

```lua
callbacks.Register("FireGameEvent", "on_death", function(event)
    if event:GetName() ~= "player_death" then return end
    local victim = entities.GetByUserID(event:GetInt("userid"))
    local attacker = entities.GetByUserID(event:GetInt("attacker"))

    if victim then print("Victim: " .. victim:GetName()) end
    if attacker then print("Killer: " .. attacker:GetName()) end
end)
```

### Notes

- userID comes from GameEvent fields, not entity index

