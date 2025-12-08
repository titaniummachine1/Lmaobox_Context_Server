## Function/Symbol: Entity.GetPropEntity

> Get an entity handle property (e.g., m_hActiveWeapon)

### Required Context
- Parameters: table/field names (varargs)
- Returns: Entity or nil

### Curated Usage Examples

#### Get active weapon
```lua
local me = entities.GetLocalPlayer()
if me then
    local weapon = me:GetPropEntity("m_hActiveWeapon")
    if weapon then
        print("Weapon class: " .. weapon:GetClass())
    end
end
```

#### Get heal target (medigun)
```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon and weapon:IsMedigun() then
    local target = weapon:GetPropEntity("m_hHealingTarget")
    if target then
        print("Healing: " .. target:GetName())
    end
end
```

### Notes
- Returns nil if prop is invalid or missing
- Common handle props: `m_hActiveWeapon`, `m_hOwnerEntity`, `m_hHealingTarget`
