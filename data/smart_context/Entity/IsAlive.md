## Function/Symbol: Entity.IsAlive

> Check if the entity is alive

### Required Context

- Returns: boolean
- Types: Entity

### Curated Usage Examples

#### Basic check

```lua
local ent = entities.GetByIndex(idx)
if ent and ent:IsAlive() then
    print(ent:GetName() .. " is alive")
end
```

#### Filter enemy players

```lua
local me = entities.GetLocalPlayer()
if not me then return end

for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
    if ply:IsAlive() and ply:GetTeamNumber() ~= me:GetTeamNumber() then
        -- enemy alive
    end
end
```

#### Safe early exits

```lua
local function GetTarget()
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return nil end
    -- ... your logic
end
```

### Notes

- Always combine with nil-check: `if ent and ent:IsAlive()`
- Dead/dormant entities often still exist; filter with this
