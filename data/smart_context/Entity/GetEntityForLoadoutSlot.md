## Function/Symbol: Entity.GetEntityForLoadoutSlot

> Get entity for a specific loadout slot (hat, weapon, etc.)

### Required Context
- Parameters: slot (E_LoadoutSlot constant)
- Constants: E_LoadoutSlot

### Curated Usage Examples

```lua
local me = entities.GetLocalPlayer()
if me then
    local primary = me:GetEntityForLoadoutSlot(LOADOUT_POSITION_PRIMARY)
    if primary then
        print("Primary: " .. primary:GetClass())
    end
end
```

### Notes
- Returns Entity or nil
- Use for checking equipped items/weapons
