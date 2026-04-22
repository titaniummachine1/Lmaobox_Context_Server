## Function/Symbol: Entity.GetMoveType

> Get the move type of an entity (E_MoveType)

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    local mt = ent:GetMoveType()
    -- Compare with constants in E_MoveType
end
```

### Notes

- Use constants (e.g., MOVETYPE_WALK, MOVETYPE_FLY) from enums if available

