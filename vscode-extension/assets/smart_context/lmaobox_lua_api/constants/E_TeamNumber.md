## Constants Reference: E_TeamNumber

> TF2 team identifiers. Used with `Entity:GetTeamNumber()`.

### Constants

| Constant          | Value | Meaning                      |
| ----------------- | ----- | ---------------------------- |
| `TEAM_UNASSIGNED` | 0     | Not on a team (e.g. loading) |
| `TEAM_SPECTATOR`  | 1     | Spectator                    |
| `TEAM_BLU`        | 2     | BLU team                     |
| `TEAM_RED`        | 3     | RED team                     |

### Curated Usage Examples

#### Enemy check

```lua
local me = entities.GetLocalPlayer()
local myTeam = me:GetTeamNumber()

for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
    local isEnemy = ply:GetTeamNumber() ~= myTeam and ply:GetTeamNumber() ~= TEAM_SPECTATOR
    if isEnemy and ply:IsAlive() and not ply:IsDormant() then
        -- valid target
    end
end
```

#### Team-aware logic

```lua
local isOnBlu = entity:GetTeamNumber() == TEAM_BLU
local isOnRed = entity:GetTeamNumber() == TEAM_RED
local isSpectator = entity:GetTeamNumber() == TEAM_SPECTATOR
```

### Notes

- TF2 uses `2` (BLU) and `3` (RED) regardless of map naming conventions.
- Spectators still have an entity and may appear in `FindByClass("CTFPlayer")` — always filter by team.
