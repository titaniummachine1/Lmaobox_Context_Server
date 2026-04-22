## Constants Reference: E_MoveType

> Movement type constants; read from `Entity:GetMoveType()` or `m_MoveType` prop.

### Constants

| Constant              | Value | Meaning                                      |
| --------------------- | ----- | -------------------------------------------- |
| `MOVETYPE_NONE`       | 0     | Not moving                                   |
| `MOVETYPE_ISOMETRIC`  | 1     | Isometric movement (not used in TF2)         |
| `MOVETYPE_WALK`       | 2     | Normal ground walking                        |
| `MOVETYPE_STEP`       | 3     | NPCs stepping                                |
| `MOVETYPE_FLY`        | 4     | Fly without gravity                          |
| `MOVETYPE_FLYGRAVITY` | 5     | Fly with gravity (e.g. rocket while boosted) |
| `MOVETYPE_VPHYSICS`   | 6     | Physics-driven object                        |
| `MOVETYPE_PUSH`       | 7     | Pushed by map entity                         |
| `MOVETYPE_NOCLIP`     | 8     | Noclip                                       |
| `MOVETYPE_LADDER`     | 9     | On a ladder                                  |
| `MOVETYPE_OBSERVER`   | 10    | Spectator/observer                           |
| `MOVETYPE_CUSTOM`     | 11    | Custom movement                              |

### Curated Usage Examples

#### Detect noclip / spectator movement

```lua
local moveType = entity:GetMoveType()
local isNoclip = moveType == MOVETYPE_NOCLIP
local isOnLadder = moveType == MOVETYPE_LADDER
local isObserver = moveType == MOVETYPE_OBSERVER
```

#### Skip non-walking players (common in projectile sim)

```lua
-- Ground-based prediction is only valid for walking players
local moveType = entity:GetMoveType()
local isGroundBased = moveType == MOVETYPE_WALK or moveType == MOVETYPE_STEP
```

### Notes

- Use `entity:GetMoveType()` — cleaner than reading `m_MoveType` prop directly.
- Taunt, spawn-room blocking, and other states may not change `MoveType` — check `m_fFlags` too.
