## Constants Reference: TF2 Conditions (E_TFCOND)

> Common TFCond\_\* constants for Entity:InCond checks

### Critical TFConds (3A)

| Constant Name           | Integer | Description                          |
| ----------------------- | ------- | ------------------------------------ |
| `TFCond_Slowed`         | 0       | Result of Revving Minigun/Sniper Aim |
| `TFCond_Zoomed`         | 1       | Sniper Scoped In                     |
| `TFCond_Disguising`     | 2       | Spy Disguise Smoke                   |
| `TFCond_Disguised`      | 3       | Spy Fully Disguised                  |
| `TFCond_Cloaked`        | 4       | Invisible Spy                        |
| `TFCond_Ubercharged`    | 5       | Standard Invulnerability             |
| `TFCond_TeleportedGlow` | 6       | Glowing feet after teleport          |
| `TFCond_Kritzkrieged`   | 11      | Critical hit boost                   |
| `TFCond_Bonked`         | 14      | Scout Invulnerability                |
| `TFCond_Dazed`          | 15      | Stunned / Ghost effect               |
| `TFCond_Buffed`         | 16      | Soldier Banner Effect                |
| `TFCond_MegaHeal`       | 24      | Quick-Fix Uber                       |
| `TFCond_King`           | 109     | Mannpower King Powerup               |

> These are the high-priority enum mappings used by the MCP smart context to avoid number guessing.
> For exhaustive coverage, check `types/lmaobox_lua_api/constants/E_TFCOND.d.lua`.

### Core Conditions

- `TFCond_Ubercharged` - Regular ubercharge
- `TFCond_Kritzkrieged` - Kritzkrieg crits
- `TFCond_Cloaked` - Spy cloak active
- `TFCond_Disguised` - Spy disguised
- `TFCond_Disguising` - Spy disguising
- `TFCond_Bonked` - Scout Bonk! effect
- `TFCond_Charging` - Demoknight charging
- `TFCond_OnFire` - Burning
- `TFCond_Jarated` - Covered in Jarate
- `TFCond_Bleeding` - Bleeding
- `TFCond_Dazed` - Stunned
- `TFCond_Taunting` - Taunting
- `TFCond_Zoomed` - Sniper scoped

### Usage Patterns

#### Check invulnerability

```lua
local function IsInvulnerable(player)
    return player:InCond(TFCond_Ubercharged)
        or player:InCond(TFCond_Bonked)
        or player:InCond(TFCond_UberchargedHidden)
end

if IsInvulnerable(target) then
    print("Don't attack - invuln active")
end
```

#### Check spy status

```lua
local function IsSpyCloaked(player)
    return player:InCond(TFCond_Cloaked) or player:InCond(TFCond_CloakFlicker)
end

local function IsSpyDisguised(player)
    return player:InCond(TFCond_Disguised) or player:InCond(TFCond_Disguising)
end
```

#### Check debuffs

```lua
local function HasDebuff(player)
    return player:InCond(TFCond_OnFire)
        or player:InCond(TFCond_Jarated)
        or player:InCond(TFCond_Bleeding)
end
```

### Notes

- Use with `Entity:InCond(condition)` to check
- Multiple conditions can be active simultaneously
- Some conditions have hidden variants (e.g., Ubercharged_Hidden)
- Check E_TFCOND.d.lua for full list
