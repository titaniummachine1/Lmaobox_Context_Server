## Function/Symbol: callbacks.Register

> Register a function to run on a specific event/callback

### Required Context

- Parameters: eventName, identifier, func
- Common events: "CreateMove", "Draw", "FireGameEvent", "Unload"
- Identifier: string to avoid duplicate registrations

### Curated Usage Examples

#### Basic registration

```lua
callbacks.Register("Draw", "my_draw_id", function()
    draw.Color(255, 255, 255, 255)
    draw.Text(10, 10, "Hello from Draw")
end)
```

#### CreateMove aimbot skeleton

```lua
callbacks.Register("CreateMove", "aimbot", function(cmd)
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end

    local target = GetBestTarget()
    if not target then return end

    local eye = GetEyePos(me)
    local aim = AngleToPosition(eye, target:GetHitboxPos(1))
    cmd:SetViewAngles(aim) -- silent aim
end)
```

#### FireGameEvent example

```lua
callbacks.Register("FireGameEvent", "chat_print", function(event)
    if event:GetName() == "player_death" then
        local victim = client.GetPlayerName(event:GetInt("userid"))
        print(victim .. " died")
    end
end)
```

#### Unload cleanup

```lua
callbacks.Register("Unload", "cleanup", function()
    print("Script unloaded, cleanup here")
end)
```

### Notes

- Use a unique identifier string per registration to prevent duplicates
- To remove a callback, re-register with same id and `nil`? (depends on environment)
- Keep callbacks lightweight; heavy work should be cached
