## Function/Symbol: custom.FilterEnemies

> Collect enemy players (alive, non-dormant) into a list

### Curated Usage Examples

```lua
local function FilterEnemies()
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return {} end
    local myTeam = me:GetTeamNumber()
    local enemies = {}

    for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
        if ply:IsAlive() and ply:GetTeamNumber() ~= myTeam and not ply:IsDormant() then
            table.insert(enemies, ply)
        end
    end

    return enemies
end
```

### Notes

- Adds standard checks: alive, team, not local, not dormant
- Extend with distance/FOV/visibility as needed
