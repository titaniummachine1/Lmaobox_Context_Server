## Function/Symbol: entities.GetHighestEntityIndex

> Get the highest valid entity index

### Required Context

- Returns: integer
- Use with entities.GetByIndex to iterate

### Curated Usage Examples

#### Iterate all entities

```lua
for i = 1, entities.GetHighestEntityIndex() do
    local ent = entities.GetByIndex(i)
    if ent and ent:IsPlayer() and ent:IsAlive() then
        print(i, ent:GetName())
    end
end
```

#### Count players

```lua
local function CountPlayers()
    local count = 0
    for i = 1, entities.GetHighestEntityIndex() do
        local ent = entities.GetByIndex(i)
        if ent and ent:IsPlayer() and ent:IsAlive() then
            count = count + 1
        end
    end
    return count
end
```

#### Find by class in one pass

```lua
local function FindByClassOnce(className)
    local results = {}
    for i = 1, entities.GetHighestEntityIndex() do
        local ent = entities.GetByIndex(i)
        if ent and ent:GetClass() == className then
            table.insert(results, ent)
        end
    end
    return results
end
```

### Notes

- The index range may include many nil slots; nil-check each
- Players/buildings typically occupy lower indices but not guaranteed
