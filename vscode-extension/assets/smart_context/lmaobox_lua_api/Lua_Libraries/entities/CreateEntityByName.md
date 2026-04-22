## Function/Symbol: entities.CreateEntityByName

> Create a non-networkable entity by class name (manual lifecycle)

### Required Context

- Parameters: className (string)
- Returns: Entity or nil
- You must call `entity:Release()` when done

### Curated Usage Examples

```lua
local ent = entities.CreateEntityByName("prop_dynamic")
if ent then
    -- configure via props if needed
    -- remember to release when done
    ent:Release()
end
```

### Notes

- Use sparingly; you manage its lifecycle
- For temp effects, prefer TempEntity

