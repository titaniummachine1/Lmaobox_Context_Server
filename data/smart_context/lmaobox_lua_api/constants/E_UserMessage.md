## Constants Reference: E_UserMessage

> User message type IDs used in `callbacks.Register("DispatchUserMessage", ...)` to identify incoming messages

### Core Values

| Constant           | Value | Description                              |
| ------------------ | ----- | ---------------------------------------- |
| `Geiger`           | 0     | Geiger counter proximity                 |
| `Train`            | 1     | Train/cart push indicator                |
| `HudText`          | 2     | HUD text message                         |
| `SayText`          | 3     | Old-style chat text (legacy)             |
| `SayText2`         | 4     | Current chat text (colored, with sender) |
| `TextMsg`          | 5     | Console/center text message              |
| `ResetHUD`         | 6     | HUD reset signal                         |
| `GameTitle`        | 7     | Game title screen                        |
| `ItemPickup`       | 8     | Item acquired notification               |
| `ShowMenu`         | 9     | Valve-side menu                          |
| `Shake`            | 10    | Screen shake                             |
| `Fade`             | 11    | Screen fade                              |
| `VGUIMenu`         | 12    | VGUI panel open                          |
| `Rumble`           | 13    | Controller rumble                        |
| `CloseCaption`     | 14    | Closed caption subtitle                  |
| `SendAudio`        | 15    | Play audio event                         |
| `VoiceMask`        | 16    | Voice communication mask                 |
| `RequestState`     | 17    | Request game state                       |
| `Damage`           | 18    | Damage indicator                         |
| `HintText`         | 19    | Hint bar text                            |
| `KeyHintText`      | 20    | Key hint prompt                          |
| `HudMsg`           | 21    | HUD message (positioned)                 |
| `AmmoDenied`       | 22    | Ammo denied sound/feedback               |
| `AchievementEvent` | 23    | Achievement unlock                       |
| `UpdateRadar`      | 24    | Radar update (MVM etc.)                  |

### Curated Usage Examples

#### Listen for incoming chat messages (SayText2)

```lua
callbacks.Unregister("DispatchUserMessage", "chat_spy")
callbacks.Register("DispatchUserMessage", "chat_spy", function(msgType, plyIndex, buffer)
    local isChatMsg = msgType == SayText2
    if not isChatMsg then return end

    -- buffer is a BitBuffer — read fields in order
    local senderIdx = buffer:ReadByte()
    local teamMsg   = buffer:ReadBool()
    local msgText   = buffer:ReadString()

    if msgText then
        print("Chat from player #" .. senderIdx .. ": " .. msgText)
    end
end)
```

#### Detect damage events

```lua
callbacks.Unregister("DispatchUserMessage", "dmg_watch")
callbacks.Register("DispatchUserMessage", "dmg_watch", function(msgType, plyIndex, buffer)
    local isDamageMsg = msgType == Damage
    if not isDamageMsg then return end

    local damage = buffer:ReadByte()
    print("You took " .. damage .. " damage")
end)
```

#### Suppress a HUD message

```lua
callbacks.Register("DispatchUserMessage", "suppress_hud", function(msgType, plyIndex, buffer)
    local isHudMsg = msgType == HudMsg
    if not isHudMsg then return end
    return true  -- returning true suppresses the message
end)
```

### Notes

- Callback signature: `function(msgType: integer, playerIndex: integer, buffer: BitBuffer) → boolean?`
- Return `true` from the callback to suppress the user message (prevent it from being processed)
- `buffer` read order is message-type-specific and must match server-side write order exactly
- `SayText2` is the active chat message type in TF2; `SayText` is legacy
- `Damage` reports damage to the **local player** only
