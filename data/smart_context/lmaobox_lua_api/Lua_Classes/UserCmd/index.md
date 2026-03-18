## Class: UserCmd

> Represents an outgoing user (movement) command; modifiable in CreateMove

### Key Fields

- `viewangles` (Vector3/EulerAngles)
- `forwardmove`, `sidemove`, `upmove`
- `buttons` (bitmask of IN\_\*)
- `sendpacket` (boolean) – choke packets when false

### Key Methods

- `GetViewAngles()` -> pitch, yaw, roll
- `SetViewAngles(p, y, r)` – silent aim on this command
- `GetButtons()` / `SetButtons(mask)`
- `SetForwardMove`, `SetSideMove`, `SetUpMove`
- `SetSendPacket(bool)` / `GetSendPacket()`

### Curated Usage Patterns

#### Silent aim

```lua
callbacks.Register("CreateMove", "silent_aim", function(cmd)
    local target = GetBestTarget()
    if not target then return end
    local eye = GetEyePos(entities.GetLocalPlayer())
    local aim = AngleToPosition(eye, target:GetHitboxPos(1))
    cmd:SetViewAngles(aim.pitch, aim.yaw, 0) -- does not move camera
end)
```

#### Button masking

```lua
local function AddButton(cmd, bit)
    cmd:SetButtons(cmd:GetButtons() | bit)
end
local function ClearButton(cmd, bit)
    cmd:SetButtons(cmd:GetButtons() & (~bit))
end

callbacks.Register("CreateMove", "auto_jump", function(cmd)
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end
    local onGround = (me:GetPropInt("m_fFlags") & FL_ONGROUND) ~= 0
    if onGround then AddButton(cmd, IN_JUMP) end
end)
```

#### Choke packets (fake lag)

```lua
callbacks.Register("CreateMove", "choke", function(cmd)
    local choke = input.IsButtonDown(KEY_X)
    cmd:SetSendPacket(not choke)
end)
```

#### Movement edits

```lua
callbacks.Register("CreateMove", "slow_walk", function(cmd)
    if input.IsButtonDown(KEY_SHIFT) then
        cmd:SetForwardMove(cmd:GetForwardMove() * 0.4)
        cmd:SetSideMove(cmd:GetSideMove() * 0.4)
    end
end)
```

### Notes

- Use IN\_\* constants for buttons (jump, attack, duck, etc.)
- `SetViewAngles` here is silent (outgoing only); use engine.SetViewAngles for visible camera
- Always nil-check local player and alive state
