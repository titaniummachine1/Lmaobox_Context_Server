## Constants Reference: TF2 Conditions (E_TFCOND)

> Common TFCond\_\* constants for Entity:InCond checks

### Core Conditions

- `TFCond_Ubercharged` (5) - Regular ubercharge
- `TFCond_Kritzkrieged` (11) - Kritzkrieg crits
- `TFCond_Cloaked` (4) - Spy cloak active
- `TFCond_Disguised` (3) - Spy disguised
- `TFCond_Disguising` (2) - Spy disguising
- `TFCond_Bonked` (14) - Scout Bonk! effect
- `TFCond_Charging` (17) - Demoknight charging
- `TFCond_OnFire` (22) - Burning
- `TFCond_Jarated` (24) - Covered in Jarate
- `TFCond_Bleeding` (25) - Bleeding
- `TFCond_Dazed` (15) - Stunned
- `TFCond_Taunting` (7) - Taunting
- `TFCond_Zoomed` (1) - Sniper scoped

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

