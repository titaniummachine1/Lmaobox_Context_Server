## Function/Symbol: Entity.IsWeapon

> Check if entity is a weapon

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(i)
if ent and ent:IsWeapon() then
    print("Weapon class: " .. ent:GetClass())
end
```

### Notes

- Useful when iterating all entities to find dropped weapons

