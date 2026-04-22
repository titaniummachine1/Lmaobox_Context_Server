## Class: Trace

> Return value of `engine.TraceLine` and `engine.TraceHull`. A plain table of read-only fields — no methods.

### Key Fields

| Field        | Type          | Meaning                                                   |
| ------------ | ------------- | --------------------------------------------------------- |
| `fraction`   | `number`      | How far the trace traveled (0.0–1.0). `1.0` = not blocked |
| `entity`     | `Entity\|nil` | The entity hit, or `nil` if world/open air                |
| `plane`      | `Vector3`     | Surface normal at hit point                               |
| `contents`   | `integer`     | Surface content flags at hit point                        |
| `hitbox`     | `E_Hitbox`    | Hitbox index hit (if entity was a player)                 |
| `hitgroup`   | `integer`     | Hitgroup hit (e.g. 1 = head, 7 = pelvis)                  |
| `allsolid`   | `boolean`     | Entire trace was inside solid                             |
| `startsolid` | `boolean`     | Trace started inside solid                                |
| `startpos`   | `Vector3`     | Start of trace (same as src param)                        |
| `endpos`     | `Vector3`     | Actual world position where trace stopped                 |

### Curated Usage Patterns

#### Visibility check (is target visible?)

```lua
local function IsVisible(fromPos, toPos, ignoreEntity)
    local trace = engine.TraceLine(fromPos, toPos, MASK_SHOT_HULL, function(ent)
        return ent ~= ignoreEntity
    end)
    return trace.fraction > 0.99
end
```

#### Get world hit position and surface normal

```lua
local eye = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local dest = eye + engine.GetViewAngles():Forward() * 8192
local trace = engine.TraceLine(eye, dest, MASK_SHOT_HULL)

local hitPos   = trace.endpos               -- world-space impact point
local normal   = trace.plane                -- surface normal at that point
local didHit   = trace.fraction < 1.0
local hitEnemy = trace.entity ~= nil and trace.entity:GetTeamNumber() ~= me:GetTeamNumber()
```

#### Head-shot confirmation

```lua
local trace = engine.TraceLine(eye, targetHeadPos, MASK_SHOT_HULL)
if trace.entity and trace.entity == target then
    local isHead = trace.hitgroup == 1  -- HITGROUP_HEAD
    print("Head shot:", isHead)
end
```

#### Detect start-in-solid

```lua
-- If startsolid is true, the trace origin is inside geometry.
-- This usually means the eye position is clipping into the world.
local trace = engine.TraceLine(eye, dest, MASK_SOLID)
if trace.startsolid then
    print("Origin is inside solid — trace is unreliable")
end
```

### Notes

- `endpos` is always valid (it equals `dst` when `fraction = 1.0`), so you can use it as a safe final point even when the trace didn't hit anything.
- `entity` is `nil` for world hits — always nil-check.
- `fraction < 1.0` means something blocked the trace; `fraction >= 0.99` is the common "visible" threshold (accounts for float imprecision).
- `hitbox` / `hitgroup` are only meaningful if `entity` is a player. For non-player hits these may be 0.
- See `constants/TraceMasks.md` for mask constants.
