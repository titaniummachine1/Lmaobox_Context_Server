## Function/Symbol: inventory.Enumerate

> Iterate through all items in player's inventory

### Required Context

- Parameters: callback(item: Item)
- Item type: Item class

### Curated Usage Examples

#### List all inventory items

```lua
inventory.Enumerate(function(item)
    local defIdx = item:GetDefinitionIndex()
    local itemDef = itemschema.GetItemDefinitionByID(defIdx)
    if itemDef then
        print("Item: " .. itemDef:GetName())
    end
end)
```

#### Find equipped items

```lua
local equipped = {}

inventory.Enumerate(function(item)
    if item:IsEquipped(4) then -- 4 = Demoman
        local defIdx = item:GetDefinitionIndex()
        local slot = item:GetLoadoutSlot(4)
        equipped[slot] = defIdx
    end
end)

print("Primary: " .. (equipped[0] or "None"))
print("Secondary: " .. (equipped[1] or "None"))
print("Melee: " .. (equipped[2] or "None"))
```

### Notes

- Callback is called for each Item in inventory
- Use Item:IsEquipped(classID) to check if equipped

