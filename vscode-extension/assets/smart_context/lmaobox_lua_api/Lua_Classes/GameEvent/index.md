## Class: GameEvent

> Represents a server-sent game event (FireGameEvent)

### Key Methods

- `GetName()` -> string
- `GetString(field)` -> string
- `GetInt(field)` -> int
- `GetFloat(field)` -> number
- `SetString/SetInt/SetFloat/SetBool(field, value)`

### Curated Usage Patterns

#### Basic FireGameEvent handling

```lua
callbacks.Register("FireGameEvent", "log_events", function(event)
    local name = event:GetName()
    if name == "player_death" then
        local victim = entities.GetByUserID(event:GetInt("userid"))
        local attacker = entities.GetByUserID(event:GetInt("attacker"))
        if victim then print("Victim: " .. victim:GetName()) end
        if attacker then print("Attacker: " .. attacker:GetName()) end
    end
end)
```

#### Chat message (say_text2)

```lua
callbacks.Register("FireGameEvent", "chat_tap", function(ev)
    if ev:GetName() ~= "say_text2" then return end
    local msg = ev:GetString("param1")
    local player = entities.GetByUserID(ev:GetInt("userid"))
    if player then
        print("[CHAT] " .. player:GetName() .. ": " .. msg)
    end
end)
```

#### Round state events

```lua
callbacks.Register("FireGameEvent", "round_state", function(ev)
    local name = ev:GetName()
    if name == "teamplay_round_start" then
        print("Round start")
    elseif name == "teamplay_round_win" then
        local team = ev:GetInt("team")
        print("Team " .. team .. " won the round")
    end
end)
```

#### Modify event (rare)

```lua
callbacks.Register("FireGameEvent", "edit_event", function(ev)
    if ev:GetName() == "player_spawn" then
        ev:SetInt("class", 1) -- example: change class field
    end
end)
```

### Notes

- Use `entities.GetByUserID` to map event user IDs to entities
- Event names are lowercase; match with `GetName()`
- See TF2 event list: https://wiki.alliedmods.net/Team_Fortress_2_Events
