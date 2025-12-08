## Pattern: Extract Complete Weapon Data

> Comprehensive weapon info extraction (item def, attributes, WeaponData)

### Required Context

- Functions: Entity:GetPropInt, Entity:GetWeaponData, itemschema.GetItemDefinitionByID
- Classes: WeaponData, ItemDefinition

### Curated Usage Examples

#### Get active weapon with full data

```lua
local function GetActiveWeaponInfo(player)
    if not player then return nil end

    local weapon = player:GetPropEntity("m_hActiveWeapon")
    if not weapon then return nil end

    local info = {}
    info.entity = weapon
    info.class = weapon:GetClass()

    -- Item definition index
    info.defIndex = weapon:GetPropInt("m_iItemDefinitionIndex")

    -- Get ItemDefinition
    if info.defIndex and info.defIndex > 0 then
        info.itemDef = itemschema.GetItemDefinitionByID(info.defIndex)
        if info.itemDef then
            info.name = info.itemDef:GetName()
            info.typeName = info.itemDef:GetTypeName()
            info.loadoutSlot = info.itemDef:GetLoadoutSlot()
        end
    end

    -- Get WeaponData
    info.weaponData = weapon:GetWeaponData()
    if info.weaponData then
        info.damage = info.weaponData.damage
        info.range = info.weaponData.range
        info.spread = info.weaponData.spread
        info.timeFireDelay = info.weaponData.timeFireDelay
        info.projectile = info.weaponData.projectile
        info.projectileSpeed = info.weaponData.projectileSpeed
    end

    -- Check weapon type
    if weapon.IsShootingWeapon then
        info.isShootingWeapon = weapon:IsShootingWeapon()
        if info.isShootingWeapon then
            info.projectileType = weapon:GetWeaponProjectileType()
            info.projectileSpeed = weapon:GetProjectileSpeed()
            info.projectileGravity = weapon:GetProjectileGravity()
        end
    end

    if weapon.IsMeleeWeapon then
        info.isMelee = weapon:IsMeleeWeapon()
        if info.isMelee then
            info.swingRange = weapon:GetSwingRange()
        end
    end

    if weapon.IsMedigun then
        info.isMedigun = weapon:IsMedigun()
        if info.isMedigun then
            info.healRate = weapon:GetMedigunHealRate()
            info.healRange = weapon:GetMedigunHealingRange()
        end
    end

    -- Ammo
    info.clip = weapon:GetPropInt("LocalWeaponData", "m_iClip1")

    return info
end
```

#### Usage example

```lua
local me = entities.GetLocalPlayer()
if me then
    local wInfo = GetActiveWeaponInfo(me)
    if wInfo then
        print("Weapon: " .. (wInfo.name or "Unknown"))
        print("Type: " .. (wInfo.typeName or "Unknown"))
        if wInfo.isMelee then
            print("Melee range: " .. (wInfo.swingRange or 0))
        end
        if wInfo.projectileSpeed and wInfo.projectileSpeed > 0 then
            print("Projectile speed: " .. wInfo.projectileSpeed)
        end
    end
end
```

### Notes

- Use `weapon:GetWeaponData()` for base stats
- Use specialized getters (GetProjectileSpeed, GetSwingRange) for weapon-specific data
- Some fields may return 0/nil if hardcoded elsewhere; know your weapon defaults

