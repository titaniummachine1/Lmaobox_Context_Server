## Function/Symbol: entities.GetByIndex

> Get an entity by index

### Required Context

- Parameters: index (integer)
- Returns: Entity or nil

### Curated Usage Examples

#### Basic access

```lua
local ent = entities.GetByIndex(idx)
if ent and ent:IsValid() then
    print(ent:GetClass())
end
```

#### Iterate all entities

```lua
for i = 1, entities.GetHighestEntityIndex() do
    local ent = entities.GetByIndex(i)
    if ent and ent:IsPlayer() and ent:IsAlive() then
        print(i, ent:GetName())
    end
end
```

#### Safely handle nil/invalid

```lua
local function GetEntitySafe(i)
    local ent = entities.GetByIndex(i)
    if not ent or not ent:IsValid() then return nil end
    return ent
end
```

### Notes

- Some indices may be nil or invalid; always nil-check
- Combine with `GetHighestEntityIndex` for full iteration
