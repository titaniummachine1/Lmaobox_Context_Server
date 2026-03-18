## Class: EulerAngles

> Represents pitch/yaw/roll in degrees. The fundamental angle type in Lmaobox. **All angles are in degrees — never radians.**

### Key Fields

- `pitch` / `x` — up/down rotation (negative = up, positive = down in Source engine)
- `yaw` / `y` — left/right rotation (0 = east, increases counter-clockwise)
- `roll` / `z` — tilt

Supports arithmetic operators directly: `+`, `-`, `*`, `/`, unary `-`.

### Constructor

```lua
EulerAngles()               -- all zeros
EulerAngles(pitch, yaw, roll) -- from values
```

### Key Methods

- `Unpack()` → `pitch, yaw, roll` — destructure to separate numbers
- `Forward()` → `Vector3` — unit vector pointing in the angle's facing direction
- `Right()` → `Vector3` — unit vector pointing right
- `Up()` → `Vector3` — unit vector pointing up
- `Normalize()` — clamp all components into engine range in-place
- `Clamp()` — clamp pitch to [-89, 89], yaw to [-180, 180], roll to [-50, 50]
- `Clear()` — set all to 0

### Curated Usage Patterns

#### Construct angle to face a position

```lua
local function AngleToPosition(from, to)
    assert(from and to, "AngleToPosition: nil input")
    local delta = to - from
    local len2d = math.sqrt(delta.x * delta.x + delta.y * delta.y)
    local pitch = -math.deg(math.atan(delta.z, len2d))
    local yaw   = math.deg(math.atan(delta.y, delta.x))
    return EulerAngles(pitch, yaw, 0)
end
```

#### Get view direction as Vector3

```lua
local viewAngles = engine.GetViewAngles()
local forward = viewAngles:Forward()
-- forward is a unit Vector3 in the direction the camera faces
```

#### Apply angles to aim in CreateMove

```lua
callbacks.Register("CreateMove", "aim", function(cmd)
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end
    local target = GetBestTarget()
    if not target then return end
    local eye = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
    local aim = AngleToPosition(eye, target:GetAbsOrigin())
    cmd:SetViewAngles(aim.pitch, aim.yaw, 0)
end)
```

#### Arithmetic

```lua
local currentAngles = engine.GetViewAngles()
local smoothed = EulerAngles(
    currentAngles.pitch * 0.8 + targetAngles.pitch * 0.2,
    currentAngles.yaw   * 0.8 + targetAngles.yaw   * 0.2,
    0
)
```

### Notes

- **Pitch is inverted** in Source: looking up = negative pitch, looking down = positive pitch.
- `Normalize()` wraps values into valid range. Use `engine.NormalizeAngle(deg)` for single-component normalization.
- Always construct with `EulerAngles(p, y, r)` — never use a plain table `{pitch=..., yaw=...}`.
- `Forward()` returns a Vector3 unit vector; do NOT normalize again.
- Comparing angles: use `engine.NormalizeAngle` on the difference, not raw subtraction.
