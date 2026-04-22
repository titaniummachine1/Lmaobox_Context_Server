## Callbacks Overview (callbacks.Register)

> Reference for common callback IDs and patterns

### Core IDs

- `Draw` – per-frame drawing
- `CreateMove` – per input tick, modify UserCmd (aim/move/buttons)
- `FireGameEvent` – game events from server (GameEvent)
- `DispatchUserMessage` – user messages from server
- `FrameStageNotify` – engine frame stages
- `PostPropUpdate` – after entity props update (legacy)
- `Unload` – script unload cleanup

### Examples

#### Draw HUD

```lua
callbacks.Register("Draw", "hud_demo", function()
    draw.Color(255,255,255,255)
    draw.Text(10, 10, "Hello")
end)
```

#### CreateMove aim/move

```lua
callbacks.Register("CreateMove", "cm_demo", function(cmd)
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end
    -- edit cmd: viewangles/buttons/move/sendpacket
end)
```

#### FireGameEvent

```lua
callbacks.Register("FireGameEvent", "events_demo", function(ev)
    if ev:GetName() == "player_hurt" then
        local vic = entities.GetByUserID(ev:GetInt("userid"))
        local dmg = ev:GetInt("damageamount")
        if vic then print(vic:GetName() .. " took " .. dmg) end
    end
end)
```

#### Unload cleanup

```lua
callbacks.Register("Unload", "cleanup", function()
    -- delete textures, reset mouse, etc.
end)
```

### Notes

- Use unique IDs to avoid duplicate registration
- Combine with smart context for GameEvent and UserCmd for details
