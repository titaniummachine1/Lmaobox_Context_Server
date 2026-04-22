## Constants Reference: E_PlayerFlag

> Player flag bitfield constants. Read from `entity:GetPropInt("m_fFlags")`.

### Constants

| Constant        | Bit      | Meaning                   |
| --------------- | -------- | ------------------------- |
| `FL_ONGROUND`   | `1 << 0` | On solid ground           |
| `FL_DUCKING`    | `1 << 1` | Currently ducking         |
| `FL_WATERJUMP`  | `1 << 2` | Jumping out of water      |
| `FL_ONTRAIN`    | `1 << 3` | On a train/vehicle        |
| `FL_INRAIN`     | `1 << 4` | In rain volume            |
| `FL_FROZEN`     | `1 << 5` | Movement frozen           |
| `FL_ATCONTROLS` | `1 << 6` | At controls (train etc.)  |
| `FL_CLIENT`     | `1 << 7` | Is a player/client entity |
| `FL_FAKECLIENT` | `1 << 8` | Is a bot                  |
| `FL_INWATER`    | `1 << 9` | Partially in water        |

### Curated Usage Examples

#### Ground and duck checks

```lua
local flags = entity:GetPropInt("m_fFlags")
local isOnGround = (flags & FL_ONGROUND) ~= 0
local isDucking   = (flags & FL_DUCKING) ~= 0
local isFrozen    = (flags & FL_FROZEN) ~= 0
```

#### Jump when on ground

```lua
callbacks.Register("CreateMove", "bhop", function(cmd)
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end
    local flags = me:GetPropInt("m_fFlags")
    local onGround = (flags & FL_ONGROUND) ~= 0
    if onGround then
        cmd:SetButtons(cmd:GetButtons() | IN_JUMP)
    end
end)
```

### Notes

- Always use `(flags & CONSTANT) ~= 0` — **never** compare to `1`. Flags are bitfields.
- `m_fFlags` is a networked prop and will be stale on dormant players.
- `FL_DUCKING` being set means the duck animation is active; `IN_DUCK` button pressed is a separate concept.
