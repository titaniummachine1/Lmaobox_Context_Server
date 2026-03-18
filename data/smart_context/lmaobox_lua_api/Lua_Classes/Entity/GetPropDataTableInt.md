## Function/Symbol: Entity.GetPropDataTableInt

> Get array of integers from a data table property

### Required Context

- Parameters: table names, field name (varargs)
- Returns: table<integer, integer>

### Curated Usage Examples

#### Get ammo table

```lua
local me = entities.GetLocalPlayer()
if me then
    local ammoTable = me:GetPropDataTableInt("localdata", "m_iAmmo")
    if ammoTable then
        for i, ammoCount in ipairs(ammoTable) do
            print("Ammo slot " .. i .. ": " .. ammoCount)
        end
    end
end
```

### Notes

- Array properties return indexed tables
- Useful for ammo, multiple values per entity

