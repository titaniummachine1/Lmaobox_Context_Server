## Constants Reference: Player Flags (m_fFlags)

> Common FL\_\* flags for player state

### Core Flags

- `FL_ONGROUND` - Player is on ground (can jump)
- `FL_DUCKING` - Player is crouched
- `FL_ANIMDUCKING` - Player is in crouch animation
- `FL_WATERJUMP` - Player is water jumping
- `FL_SWIM` - Player is swimming
- `FL_INWATER` - Player is in water
- `FL_FLY` - Player can fly (noclip)
- `FL_FROZEN` - Player is frozen

### Usage Patterns

#### Check if on ground

```lua
local flags = player:GetPropInt("m_fFlags")
local onGround = (flags & FL_ONGROUND) ~= 0

if onGround then
    print("Can jump")
end
```

#### Bhop logic

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

#### Check crouch state

```lua
local flags = player:GetPropInt("m_fFlags")
local isCrouching = (flags & FL_DUCKING) ~= 0
```

### Notes

- Flags are bitmask; use `&` to check
- Most common check: FL_ONGROUND for movement/jump logic
- Multiple flags can be active: `(flags & (FL_ONGROUND | FL_DUCKING))`
