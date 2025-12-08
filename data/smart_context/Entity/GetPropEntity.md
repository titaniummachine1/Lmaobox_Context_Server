## Function/Symbol: Entity.GetPropEntity

> Get an entity handle property (e.g., m_hActiveWeapon)

### Required Context

- Parameters: table/field names (varargs)
- Returns: Entity or nil

### Curated Usage Examples

#### Get active weapon (with validation)

```lua
local me = entities.GetLocalPlayer()
if not me then return end

local weapon = me:GetPropEntity("m_hActiveWeapon")
if not weapon or not weapon:IsValid() then
    return
end

print("Weapon class: " .. weapon:GetClass())
```

#### Check ammo before shooting

```lua
local player = entities.GetLocalPlayer()
if not player then return end

local weapon = player:GetPropEntity("m_hActiveWeapon")
if not weapon or not weapon:IsValid() then return end

local ammo = weapon:GetPropInt("LocalWeaponData", "m_iClip1")
if ammo > 0 then
    print("Can shoot, ammo: " .. ammo)
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

#### Detect weapon changes

```lua
local cached_weapon = nil

function OnFrame()
    local player = entities.GetLocalPlayer()
    if not player then return end

    local current = player:GetPropEntity("m_hActiveWeapon")
    if current ~= cached_weapon then
        print("Weapon changed!")
        cached_weapon = current
    end
end
```

### Notes

- Returns nil if prop is invalid or missing
- **Always validate with `:IsValid()` after getting entity handles**
- Common handle props: `m_hActiveWeapon`, `m_hOwnerEntity`, `m_hHealingTarget`, `m_hObserverTarget`
- Entity comparison works with `==` and `~=` operators
