## Constants Reference: UserCmd Button Flags

> IN\_\* button flags for UserCmd button field

### Common Buttons

- `IN_ATTACK` - Primary fire (Mouse1)
- `IN_ATTACK2` - Secondary fire (Mouse2)
- `IN_ATTACK3` - Taunt / Special (default G)
- `IN_JUMP` - Jump (Space)
- `IN_DUCK` - Crouch (Ctrl)
- `IN_FORWARD` - Move forward (W)
- `IN_BACK` - Move back (S)
- `IN_MOVELEFT` - Strafe left (A)
- `IN_MOVERIGHT` - Strafe right (D)
- `IN_RELOAD` - Reload (R)
- `IN_USE` - Use (E)
- `IN_SCORE` - Scoreboard (Tab)
- `IN_BULLRUSH` - Demoknight charge

### Button Masking

#### Add button (OR)

```lua
local function AddButton(cmd, button)
    cmd:SetButtons(cmd:GetButtons() | button)
end

-- Auto-jump
callbacks.Register("CreateMove", "bhop", function(cmd)
    local me = entities.GetLocalPlayer()
    if me then
        local onGround = (me:GetPropInt("m_fFlags") & FL_ONGROUND) ~= 0
        if onGround then
            AddButton(cmd, IN_JUMP)
        end
    end
end)
```

#### Remove button (AND NOT)

```lua
local function RemoveButton(cmd, button)
    cmd:SetButtons(cmd:GetButtons() & (~button))
end

-- Disable attack
RemoveButton(cmd, IN_ATTACK)
```

#### Check if button pressed

```lua
local buttons = cmd:GetButtons()
if (buttons & IN_ATTACK) ~= 0 then
    print("Attacking")
end
```

#### Set specific buttons

```lua
-- Jump + Duck (crouch jump)
cmd:SetButtons(IN_JUMP | IN_DUCK)

-- Forward + Attack
cmd:SetButtons(IN_FORWARD | IN_ATTACK)
```

### Notes

- Buttons are bitmask; use `|` to combine, `&` to check
- Always use `GetButtons()` first before modifying
- Use `~` to negate for removal: `buttons & (~IN_JUMP)`

