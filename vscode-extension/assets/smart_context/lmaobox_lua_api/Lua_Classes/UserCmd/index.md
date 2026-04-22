## Class: UserCmd

> Represents an outgoing user (movement) command sent each tick in `CreateMove`.
> Fields are directly readable and writable. Methods also exist but real scripts use direct field access.

### CRITICAL: Lua 5.4 Bitwise — `bit.band` does NOT exist

Lmaobox runs **Lua 5.4**. Use native integer bitwise operators.

| Operation  | Lua 5.4 syntax | WRONG (Lua 5.1 legacy) |
| ---------- | -------------- | ---------------------- |
| AND        | `a & b`        | `bit.band(a, b)` ❌    |
| OR         | `a \| b`       | `bit.bor(a, b)` ❌     |
| NOT        | `~a`           | `bit.bnot(a)` ❌       |
| XOR        | `a ~ b`        | `bit.bxor(a, b)` ❌    |
| Left shift | `a << n`       | `bit.lshift(a, n)` ❌  |

### Field Reference (direct access — primary pattern in real scripts)

| Field                | Type    | Notes                                                     |
| -------------------- | ------- | --------------------------------------------------------- |
| `cmd.buttons`        | integer | Bitmask of `IN_*` constants. OR to add, AND NOT to remove |
| `cmd.viewangles`     | Vector3 | Set for silent aim; only affects outgoing packet          |
| `cmd.forwardmove`    | number  | Forward/back movement (-450 to 450)                       |
| `cmd.sidemove`       | number  | Strafe movement (-450 to 450)                             |
| `cmd.upmove`         | number  | Vertical movement                                         |
| `cmd.sendpacket`     | boolean | `false` = choke packet (server never sees this tick)      |
| `cmd.command_number` | integer | Current command number                                    |
| `cmd.tick_count`     | integer | Current tick count                                        |

### Available Methods (same as fields)

- `cmd:GetViewAngles()` → pitch, yaw, roll
- `cmd:SetViewAngles(pitch, yaw, roll)` — silent aim on this command only
- `cmd:GetButtons()` / `cmd:SetButtons(mask)`
- `cmd:GetForwardMove()` / `cmd:SetForwardMove(v)`
- `cmd:GetSideMove()` / `cmd:SetSideMove(v)`
- `cmd:GetUpMove()` / `cmd:SetUpMove(v)`
- `cmd:GetSendPacket()` / `cmd:SetSendPacket(bool)`

### Curated Usage Patterns

#### Button add / remove (Lua 5.4 bitwise, field access)

```lua
-- Add a button (field access — most common in real scripts)
cmd.buttons = cmd.buttons | IN_ATTACK

-- Remove a button
cmd.buttons = cmd.buttons & ~IN_ATTACK

-- Check a button is pressed
local isAttacking = (cmd.buttons & IN_ATTACK) ~= 0
```

#### Silent aim – projectile and melee ONLY

> **Hitscan is patched server-side**: on hitscan weapons the server forces the shot toward where
> the player was actually looking when the attack packet arrived, ignoring `cmd.viewangles`.
> Silent aim via `cmd.viewangles` only works for **projectiles** (rockets, pipes, arrows) and **melee**.

```lua
callbacks.Register("CreateMove", "silent_proj_aim", function(cmd)
    local angle = GetProjectileAngle() -- your calc
    if not angle then return end

    -- Set viewangles on the command — silent, camera does NOT move
    cmd.viewangles = Vector3(angle:Unpack())

    -- For "silent +" mode: also choke the packet until the attack lands
    cmd.sendpacket = false
end)
```

#### Silent aim via SetViewAngles method (alternative)

```lua
callbacks.Register("CreateMove", "silent_aim_method", function(cmd)
    local angle = GetAimAngle()
    if not angle then return end
    cmd:SetViewAngles(angle.x, angle.y, 0) -- pitch, yaw, roll
    -- camera stays at original view — only the outgoing packet carries the new angle
end)
```

#### Full projectile aimbot pattern (real-world)

```lua
-- state.angle is an EulerAngles calculated in Draw callback
local function OnCreateMove(cmd)
    if not state.angle then return end

    -- Charge weapon: hold attack until charged enough
    if state.charges and state.charge < 0.1 then
        cmd.buttons = cmd.buttons | IN_ATTACK
        return
    end

    -- Release attack while still charging
    if state.charges then
        cmd.buttons = cmd.buttons & ~IN_ATTACK
    else
        cmd.buttons = cmd.buttons | IN_ATTACK
    end

    -- Packet choke for "silent +" mode
    if state.silent and isSilentPlus then
        cmd.sendpacket = false
    end

    -- Only move camera for non-silent modes
    if not isSilent then
        engine.SetViewAngles(state.angle)
    end

    cmd.viewangles = Vector3(state.angle:Unpack())
end
callbacks.Register("CreateMove", "proj_aimbot", OnCreateMove)
```

#### Auto-bhop (check ground flag)

```lua
callbacks.Register("CreateMove", "bhop", function(cmd)
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end
    local flags = me:GetPropInt("m_fFlags")
    local onGround = (flags & FL_ONGROUND) ~= 0
    if onGround then
        cmd.buttons = cmd.buttons | IN_JUMP
    else
        cmd.buttons = cmd.buttons & ~IN_JUMP
    end
end)
```

#### Slow-walk / movement scale

```lua
callbacks.Register("CreateMove", "slow_walk", function(cmd)
    local isSlowWalking = input.IsButtonDown(KEY_SHIFT)
    if not isSlowWalking then return end
    cmd.forwardmove = cmd.forwardmove * 0.3
    cmd.sidemove = cmd.sidemove * 0.3
end)
```

#### Packet choke (fake lag)

```lua
local chopTicks = 0
local MAX_CHOKE = 14

callbacks.Register("CreateMove", "fake_lag", function(cmd)
    local doChoke = input.IsButtonDown(KEY_X)
    if not doChoke then
        chopTicks = 0
        return
    end
    if chopTicks < MAX_CHOKE then
        cmd.sendpacket = false
        chopTicks = chopTicks + 1
    else
        cmd.sendpacket = true
        chopTicks = 0
    end
end)
```

#### Attack with secondary fire for specific weapons

```lua
-- Some throwable weapons (Gift Wrap, Lunchbox) fire via IN_ATTACK2
cmd.buttons = cmd.buttons | IN_ATTACK2
```

### cmd.viewangles vs engine.SetViewAngles

|                         | cmd.viewangles   | engine.SetViewAngles |
| ----------------------- | ---------------- | -------------------- |
| Affects camera          | NO               | YES                  |
| Affects outgoing packet | YES              | NO (only camera)     |
| Works for silent aim    | YES (proj/melee) | NO                   |
| Typical use             | Silent aimbot    | Visible aim snap     |

To do **non-silent** aim snap (camera + server) use both:

```lua
engine.SetViewAngles(state.angle) -- move camera
cmd.viewangles = Vector3(state.angle:Unpack()) -- also send to server
```

### Notes

- `bit.band`, `bit.bor`, `bit.bnot` do **not exist** in Lua 5.4 — calling them crashes the script
- `cmd.sendpacket = false` chokes the packet; the server does NOT process that tick
- Choked packets still increment `command_number` locally; they send when `sendpacket = true` again
- Engine-enforces hitscan direction server-side — silent aim on hitscan **always misses**
- Always nil-check `entities.GetLocalPlayer()` and `me:IsAlive()` before modifying cmd
