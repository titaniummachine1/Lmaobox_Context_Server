## Function/Symbol: engine.GetViewAngles

> Get the current view angles of the local player

### Required Context

- Returns: EulerAngles
- Types: EulerAngles

### Curated Usage Examples

#### Read current view

```lua
local angles = engine.GetViewAngles()
print("View pitch: " .. angles.pitch .. " yaw: " .. angles.yaw)
```

#### Calculate forward/right/up vectors

```lua
local function GetBasis()
    local ang = engine.GetViewAngles()
    local fwd = ang:Forward()
    local right = ang:Right()
    local up = ang:Up()
    return fwd, right, up
end
```

#### Build a direction ray

```lua
local me = entities.GetLocalPlayer()
if not me then return end

local eye = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local dir = engine.GetViewAngles():Forward()
local dst = eye + dir * 1000

local trace = engine.TraceLine(eye, dst, MASK_SHOT_HULL)
```

#### Aimbot delta

```lua
local current = engine.GetViewAngles()
local target = AngleToPosition(eyePos, targetPos)
local delta = target - current
```

### Notes

- Returns **camera angles**, not weapon recoil-compensated angles
- Combine with `SetViewAngles` for aiming
