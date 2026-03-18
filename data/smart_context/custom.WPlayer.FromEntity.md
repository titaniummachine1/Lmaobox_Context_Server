## Function/Symbol: custom.WPlayer.FromEntity

> Wrap a native player `Entity` into an lnxLib `WPlayer`

### Required Context:

- Input must be a valid player `Entity`
- This wrapper is assert-based, not nil-returning for valid player entities

### Curated Usage Examples:

#### Standard local-player wrap

```lua
local pLocal = entities.GetLocalPlayer()
if not pLocal then
    return
end

local me = WPlayer.FromEntity(pLocal)
```

#### Safe player-only usage

```lua
local ent = entities.GetByIndex(idx)
if not ent or not ent:IsPlayer() then
    return
end

local player = WPlayer.FromEntity(ent)
```

### Notes:

- `WPlayer.FromEntity` asserts if `entity` is nil
- `WPlayer.FromEntity` asserts if `entity:IsPlayer()` is false
- Prefer wrapping the local player or a known player entity, not arbitrary entities
- Do not annotate this as returning `WPlayer?` for valid player inputs; the failure mode is an assert, not a silent nil return
