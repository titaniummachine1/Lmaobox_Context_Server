## Function/Symbol: warp.CanWarp / warp.IsWarping

### Signatures

```lua
warp.CanWarp()    → boolean   -- warp system is available and charged enough for a basic warp
warp.IsWarping()  → boolean   -- currently in an active warp tick
```

### Curated Usage Examples

#### Basic availability check

```lua
-- CanWarp() is a weaker check — guarantees the warp mechanism is active,
-- but doesn't guarantee a full doubletap charge.
-- Use CanDoubleTap(weapon) for a full doubletap guarantee.
if warp.CanWarp() then
    warp.TriggerWarp()
end
```

#### suppress movement during warp

```lua
-- IsWarping() is only meaningful inside CreateMove
callbacks.Register("CreateMove", "warp_freeze", function(cmd)
    local isWarping = warp.IsWarping()
    if isWarping then
        -- Clear movement during warp to prevent position desync
        cmd:SetForwardMove(0)
        cmd:SetSideMove(0)
    end
end)
```

#### Full charge check

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if not weapon then return end

local canDoubleTap = warp.CanDoubleTap(weapon)  -- stronger: full charge + weapon-specific check
local canBasicWarp = warp.CanWarp()              -- weaker: just checks warp is available

if canDoubleTap then
    warp.TriggerDoubleTap()
elseif canBasicWarp then
    warp.TriggerWarp()
end
```

### Notes

- `CanWarp()` is a weaker availability check than `CanDoubleTap(weapon)` — prefer `CanDoubleTap` for doubletap logic
- `IsWarping()` is only meaningful inside `CreateMove`; the warp window is extremely short (1–2 ticks)
- Do not call warp trigger functions outside `CreateMove`
