## Constants Reference: E_Hitbox

> Hitbox index constants for TF2 player models. Used with `Entity:GetHitboxes()` and `WPlayer:GetHitboxPos()`.

### Warning: Index Instability

**These constants are NOT guaranteed to match the actual hitbox indices from `GetHitboxes()`.** The engine-level hitbox indices depend on the player class and hitbox set loaded for that model. `HITBOX_HEAD` is `0` in the enum but some classes return head at index `1` when using `GetHitboxes()`.

- For `GetHitboxes()` (deprecated) — probe `0` then fall back to `1` for head; use `(mins + maxs) * 0.5` for center.
- For the studio pipeline — match via `StudioBBox:GetGroup()` (`HITGROUP_HEAD = 1`) or `StudioBBox:GetName()`. See `custom.StudioHitbox_pipeline.md`.
- For lnxLib `WPlayer:GetHitboxPos(id)` — these constants are safe to pass directly.

### Constants

| Constant            | Value | Body Part       |
| ------------------- | ----- | --------------- |
| `HITBOX_HEAD`       | 0     | Head            |
| `HITBOX_PELVIS`     | 1     | Pelvis          |
| `HITBOX_SPINE_0`    | 2     | Lower spine     |
| `HITBOX_SPINE_1`    | 3     | Mid spine       |
| `HITBOX_SPINE_2`    | 4     | Upper spine     |
| `HITBOX_SPINE_3`    | 5     | Neck            |
| `HITBOX_UPPERARM_L` | 6     | Left upper arm  |
| `HITBOX_LOWERARM_L` | 7     | Left forearm    |
| `HITBOX_HAND_L`     | 8     | Left hand       |
| `HITBOX_UPPERARM_R` | 9     | Right upper arm |
| `HITBOX_LOWERARM_R` | 10    | Right forearm   |
| `HITBOX_HAND_R`     | 11    | Right hand      |
| `HITBOX_HIP_L`      | 12    | Left hip        |
| `HITBOX_KNEE_L`     | 13    | Left knee       |
| `HITBOX_FOOT_L`     | 14    | Left foot       |
| `HITBOX_HIP_R`      | 15    | Right hip       |
| `HITBOX_KNEE_R`     | 16    | Right knee      |
| `HITBOX_FOOT_R`     | 17    | Right foot      |

### Curated Usage Examples

#### Head position with WPlayer (lnxLib — preferred)

```lua
-- WPlayer:GetHitboxPos is the safest path; it handles class differences internally.
local function GetHeadPos(wPlayer)
    assert(wPlayer, "GetHeadPos: wPlayer missing")
    return wPlayer:GetHitboxPos(HITBOX_HEAD)
end
```

#### Head position via deprecated GetHitboxes (no lnxLib)

```lua
-- GetHitboxes() index 0/1 does NOT reliably map to HITBOX_HEAD across all classes.
-- Probe both; treat result as approximate.
local function GetHeadPosApprox(entity)
    assert(entity, "GetHeadPosApprox: entity missing")
    local boxes = entity:GetHitboxes(globals.CurTime())
    if not boxes then return nil end
    local box = boxes[0] or boxes[1]
    if not box or not box[1] or not box[2] then return nil end
    return (box[1] + box[2]) * 0.5
end
```

#### Studio pipeline — match head by group

```lua
-- HITGROUP_HEAD = 1 is stable in the studio model data.
-- Use StudioBBox:GetGroup() not raw index to find the head hitbox.
for _, hitbox in pairs(hitboxSet:GetHitboxes()) do
    local isHead = hitbox:GetGroup() == 1
    if isHead then
        -- transform with SetupBones matrix...
    end
end
```

### Notes

- **`HITGROUP_HEAD = 1`** (from the Source hitgroup enum) is the reliable group identifier in the studio pipeline. It is distinct from `HITBOX_HEAD = 0`.
- When in doubt, log `StudioBBox:GetName()` and `GetGroup()` to see what's actually present for the model you're working with.
