## Function/Symbol: itemschema.GetItemDefinitionByID

> Get ItemDefinition by item definition index

### Required Context

- Parameters: id (integer - weapon/item ID)
- Returns: ItemDefinition

### Curated Usage Examples

#### Get weapon definition

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local defIdx = weapon:GetPropInt("m_iItemDefinitionIndex")
    local itemDef = itemschema.GetItemDefinitionByID(defIdx)

    if itemDef then
        print("Weapon: " .. itemDef:GetName())
        print("Type: " .. itemDef:GetTypeName())
        print("Slot: " .. itemDef:GetLoadoutSlot())
    end
end
```

#### Check for specific items

```lua
-- Check if player has Eyelander (item ID 132)
local melee = me:GetEntityForLoadoutSlot(LOADOUT_POSITION_MELEE)
if melee then
    local defIdx = melee:GetPropInt("m_iItemDefinitionIndex")
    if defIdx == 132 then
        print("Has Eyelander")
    end
end
```

### Notes

- Returns ItemDefinition for querying name, type, loadout slot
- Common weapon IDs: check TF2 wiki for specific IDs

