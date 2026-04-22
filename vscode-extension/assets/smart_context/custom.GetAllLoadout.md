## Pattern: Get All Equipped Weapons/Wearables

> Retrieve primary, secondary, melee, and wearables

### Required Context

- Functions: Entity:GetEntityForLoadoutSlot, entities.FindByClass
- Constants: LOADOUT_POSITION_PRIMARY (0), SECONDARY (1), MELEE (2)

### Curated Usage Examples

#### Get weapons by loadout slot

```lua
local function GetPlayerLoadout(player)
    if not player then return nil end

    local loadout = {}

    -- Get weapons
    loadout.primary = player:GetEntityForLoadoutSlot(LOADOUT_POSITION_PRIMARY)
    loadout.secondary = player:GetEntityForLoadoutSlot(LOADOUT_POSITION_SECONDARY)
    loadout.melee = player:GetEntityForLoadoutSlot(LOADOUT_POSITION_MELEE)

    -- Get wearables (shields, boots, etc.)
    loadout.wearables = {}

    local wearableClasses = {
        "CTFWearable", "CTFWearableDemoShield", "CTFWearableItem",
        "CTFPowerupBottle"
    }

    for _, className in ipairs(wearableClasses) do
        local items = entities.FindByClass(className)
        for _, item in pairs(items) do
            local owner = item:GetPropEntity("m_hOwnerEntity")
            if owner and owner == player then
                table.insert(loadout.wearables, item)
            end
        end
    end

    return loadout
end
```

#### Usage for shield detection (Demoknight)

```lua
local function HasShield(player)
    local loadout = GetPlayerLoadout(player)
    if not loadout then return false end

    for _, wearable in ipairs(loadout.wearables) do
        local class = wearable:GetClass()
        if string.find(class, "Shield") then
            return true
        end
    end
    return false
end

local target = entities.GetByIndex(targetIdx)
if target and HasShield(target) then
    print("Target has shield - adjust damage calc")
end
```

### Notes

- Wearables require iteration through FindByClass + owner check
- Shield detection is critical for Demoknight/melee predictions
- Some slots may be nil if not equipped

