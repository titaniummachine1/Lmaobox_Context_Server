## Function/Symbol: Entity.GetTeamNumber

> Get the team number of an entity

### Required Context

- Returns: integer (2=RED, 3=BLU in TF2)
- Types: Entity

### Curated Usage Examples

#### Basic usage

```lua
local ent = entities.GetByIndex(idx)
if ent then
    print("Team: " .. ent:GetTeamNumber())
end
```

#### Filter enemies

```lua
local me = entities.GetLocalPlayer()
if not me then return end
local myTeam = me:GetTeamNumber()

for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
    if ply:IsAlive() and ply:GetTeamNumber() ~= myTeam then
        -- enemy player
    end
end
```

#### Team-colored ESP

```lua
local function SetTeamColor(team)
    if team == 2 then
        draw.Color(255, 0, 0, 200)
    elseif team == 3 then
        draw.Color(0, 100, 255, 200)
    else
        draw.Color(255, 255, 255, 200)
    end
end

local me = entities.GetLocalPlayer()
if not me then return end
for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
    if ply:IsAlive() then
        SetTeamColor(ply:GetTeamNumber())
        -- draw ESP
    end
end
```

### Notes

- Use alongside `IsAlive` to filter valid targets
- Spectators/unassigned may return other values
