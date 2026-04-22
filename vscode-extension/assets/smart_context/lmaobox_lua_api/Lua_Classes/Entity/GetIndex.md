## Function/Symbol: Entity.GetIndex

> Get the entity's index

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    print("Index: " .. ent:GetIndex())
end
```

### Notes

- Indexes range up to `entities.GetHighestEntityIndex()`

