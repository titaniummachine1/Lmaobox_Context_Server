## Function/Symbol: custom.GetPlayerClass

> Get TF2 player class name from entity

### Required Context

- Props: `m_iClass` (integer)
- Constants: TF2 class IDs (1=Scout, 2=Sniper, 3=Soldier, 4=Demo, 5=Medic, 6=Heavy, 7=Pyro, 8=Spy, 9=Engineer)

### Curated Usage Examples

#### Class ID mapping

```lua
local CLASS_INDEX_TO_NAME = {
    [1] = "Scout",
    [2] = "Sniper",
    [3] = "Soldier",
    [4] = "Demoman",
    [5] = "Medic",
    [6] = "Heavy",
    [7] = "Pyro",
    [8] = "Spy",
    [9] = "Engineer",
}

local function GetPlayerClass(player)
    if not player or not player:IsValid() then return nil end
    local classIdx = player:GetPropInt("m_iClass")
    if classIdx == 0 then return nil end
    return CLASS_INDEX_TO_NAME[classIdx]
end
```

#### Class-based targeting

```lua
local function GetBestTargetByClass()
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return nil end

    local priorities = {
        Medic = 10,
        Sniper = 8,
        Engineer = 7,
        -- other classes...
    }

    local best, bestScore = nil, -1
    for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
        if ply:IsAlive() and ply:GetTeamNumber() ~= me:GetTeamNumber() then
            local class = GetPlayerClass(ply)
            local score = priorities[class] or 0
            if score > bestScore then
                best, bestScore = ply, score
            end
        end
    end
    return best
end
```

#### Auto-priority by class

```lua
local function UpdatePlayerPriority(player)
    local class = GetPlayerClass(player)
    if not class then return end

    local priority = 0
    if class == "Medic" then priority = 10
    elseif class == "Sniper" then priority = 8
    elseif class == "Engineer" then priority = 7
    end

    playerlist.SetPriority(player, priority)
end

callbacks.Register("CreateMove", "class_priority", function()
    for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
        if ply:IsValid() and ply:IsAlive() then
            UpdatePlayerPriority(ply)
        end
    end
end)
```

### Notes

- `m_iClass` returns 0 if player hasn't selected class yet
- Use in target selection to prioritize threats (Medics, Snipers)
- Class IDs are TF2-specific and fixed

