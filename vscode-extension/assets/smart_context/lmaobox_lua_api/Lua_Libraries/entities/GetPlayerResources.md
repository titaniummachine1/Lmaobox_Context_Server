## Function/Symbol: entities.GetPlayerResources

> Returns the `CTFPlayerResource` entity that holds per-player scoreboard data as data tables.
> All props are indexed by **entity index + 1** (1-based Lua table from a 0-based array).

### Signature

```lua
entities.GetPlayerResources() -> Entity?
```

### Key: Index Convention

```lua
-- entity:GetIndex() returns 1–32 (same as slot in the data table)
-- Resources data tables are 1-indexed in Lua (matching entity index directly)
local pr = entities.GetPlayerResources()
local idx = player:GetIndex()
local ping = pr:GetPropDataTableInt("m_iPing")[idx]
```

> **Note**: Some scripts use `GetIndex() + 1`. This appears to be a script-specific offset depending on
> how the entity was found. Most confirmed working code uses `GetIndex()` directly. Test both if in doubt.

### Available Prop Tables (verified from real scripts)

#### Integer tables ( `GetPropDataTableInt` )

| Prop string              | Description                               |
| ------------------------ | ----------------------------------------- |
| `"m_iPing"`              | Player ping in ms                         |
| `"m_iScore"`             | Round score (points)                      |
| `"m_iTotalScore"`        | Total score across rounds                 |
| `"m_iDeaths"`            | Deaths this round                         |
| `"m_iHealth"`            | Current health (alternative to GetHealth) |
| `"m_iMaxHealth"`         | Max health                                |
| `"m_iMaxBuffedHealth"`   | Max overheal                              |
| `"m_iPlayerClass"`       | Class ID (matches E_Character values)     |
| `"m_iTeam"`              | Team number (2=RED, 3=BLU)                |
| `"m_iConnectionState"`   | Player connection state                   |
| `"m_iActiveDominations"` | Number of dominations active              |
| `"m_iChargeLevel"`       | Medigun ÃœberCharge level (0–100)         |
| `"m_iDamage"`            | Damage dealt this round                   |
| `"m_iDamageAssist"`      | Assisted damage                           |
| `"m_iDamageBoss"`        | Damage dealt to MvM boss                  |
| `"m_iHealing"`           | Healing done                              |
| `"m_iHealingAssist"`     | Assisted healing                          |
| `"m_iDamageBlocked"`     | Damage blocked (Demoknight shield)        |
| `"m_iAccountID"`         | Steam account ID (low 32 bits of SteamID) |
| `"m_iUserID"`            | Numeric user ID for this session          |

#### Boolean tables ( `GetPropDataTableBool` )

| Prop string           | Description                            |
| --------------------- | -------------------------------------- |
| `"m_bAlive"`          | Whether player is alive                |
| `"m_bConnected"`      | Whether player is connected            |
| `"m_bValid"`          | Whether slot is a valid player         |
| `"m_bArenaSpectator"` | Whether player is a spectator in Arena |

#### Float tables ( `GetPropDataTableFloat` )

| Prop string             | Description                             |
| ----------------------- | --------------------------------------- |
| `"m_flNextRespawnTime"` | Timestamp when player will next respawn |

### Curated Usage Examples

#### Get ping for a specific player

```lua
local function GetPlayerPing(player)
    local pr = entities.GetPlayerResources()
    if not pr then return 0 end
    local idx = player:GetIndex()
    local pingTable = pr:GetPropDataTableInt("m_iPing")
    if not pingTable then return 0 end
    return pingTable[idx] or 0
end
```

#### Get kills/deaths/score from resources

```lua
local function GetPlayerStats(player)
    local pr = entities.GetPlayerResources()
    if not pr then return nil end
    local idx = player:GetIndex()
    return {
        score  = pr:GetPropDataTableInt("m_iScore")[idx]  or 0,
        deaths = pr:GetPropDataTableInt("m_iDeaths")[idx] or 0,
        damage = pr:GetPropDataTableInt("m_iDamage")[idx] or 0,
        ping   = pr:GetPropDataTableInt("m_iPing")[idx]   or 0,
    }
end
```

#### Check if player is connected

```lua
local function IsPlayerConnected(idx)
    local pr = entities.GetPlayerResources()
    if not pr then return false end
    local connTable = pr:GetPropDataTableBool("m_bConnected")
    if not connTable then return false end
    return connTable[idx] == true
end
```

#### Include ping in latency compensation

```lua
local function GetLatency(player)
    local pr = entities.GetPlayerResources()
    if not pr then return 0 end
    local pingMs = pr:GetPropDataTableInt("m_iPing")[player:GetIndex()] or 0
    return pingMs / 1000.0  -- convert to seconds
end
```

#### Scoreboard-style loop

```lua
callbacks.Register("Draw", "scoreboard_dump", function()
    local pr = entities.GetPlayerResources()
    if not pr then return end

    local pingTbl   = pr:GetPropDataTableInt("m_iPing")
    local scoreTbl  = pr:GetPropDataTableInt("m_iScore")
    local deathsTbl = pr:GetPropDataTableInt("m_iDeaths")
    local aliveTbl  = pr:GetPropDataTableBool("m_bAlive")

    for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
        local idx = ply:GetIndex()
        local ping   = pingTbl[idx]   or 0
        local score  = scoreTbl[idx]  or 0
        local deaths = deathsTbl[idx] or 0
        local alive  = aliveTbl[idx]
        -- use data here...
    end
end)
```

### Notes

- `GetPlayerResources()` can return `nil` before the game fully loads — always nil-check
- Data tables are full 33-slot arrays; unused slots contain 0/false
- `m_iDeaths` is deaths, not kills — there is no `m_iKills` prop on resources; use `m_iScore`
- `m_iChargeLevel` is 0–100 integer (not 0.0–1.0 float)
- `m_iAccountID` is the lower 32 bits of the Steam ID (universe-relative)
