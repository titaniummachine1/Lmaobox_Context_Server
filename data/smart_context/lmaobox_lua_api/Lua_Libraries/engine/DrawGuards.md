## Function/Symbol: engine.Con_IsVisible / IsGameUIVisible / IsChatOpen / IsTakingScreenshot

> State-query guards used at the top of every `Draw` callback to suppress rendering when non-game UI is active

### Signatures

```lua
engine.Con_IsVisible()       → boolean   -- developer console is open
engine.IsGameUIVisible()     → boolean   -- game UI (main menu/pause) is open
engine.IsChatOpen()          → boolean   -- chat input box is open
engine.IsTakingScreenshot()  → boolean   -- screenshot is being captured
```

### Canonical Draw Guard Pattern

```lua
callbacks.Register("Draw", "my_esp", function()
    -- Early exits: never draw ESP on screenshots or when UI is blocking
    if engine.Con_IsVisible() then return end
    if engine.IsGameUIVisible() then return end
    if engine.IsChatOpen() then return end
    if engine.IsTakingScreenshot() then return end

    local localPlayer = entities.GetLocalPlayer()
    if not localPlayer then return end
    if not localPlayer:IsAlive() then return end

    -- ESP draw logic here
end)
```

### Notes

- `Con_IsVisible()` — returns true when the developer console (`~`) is open
- `IsGameUIVisible()` — returns true on the main menu, pause menu, and loading screen
- `IsChatOpen()` — returns true while the chat input box is active (player typing)
- `IsTakingScreenshot()` — returns true on the frame a screenshot (`F5`) is captured; use to suppress HUD on screenshots
- These guards are optional but strongly recommended: drawing ESP while console is open causes visual clutter, and screenshots with ESP are a risk
