## Function/Symbol: Entity.GetPropInt

> Get an integer property from an entity

### Required Context

- Returns: integer (0 if missing)
- Types: Entity
- Common props: team, flags, health, weapon state

### Curated Usage Examples

#### Get team number (alt to GetTeamNumber)

```lua
local ent = entities.GetByIndex(idx)
if ent then
    local team = ent:GetPropInt("m_iTeamNum")
    print("Team: " .. team)
end
```

#### Check ground flag

```lua
local me = entities.GetLocalPlayer()
if not me then return end

local flags = me:GetPropInt("m_fFlags")
local onGround = (flags & FL_ONGROUND) ~= 0
if onGround then
    -- can jump
end
```

#### Active weapon item definition

```lua
local me = entities.GetLocalPlayer()
if not me then return end

local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local defId = weapon:GetPropInt("m_iItemDefinitionIndex")
    print("Weapon def: " .. defId)
end
```

#### Ammo in clip/reserve

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon then
    local clip = weapon:GetPropInt("m_iClip1")
    local reserve = weapon:GetPropInt("m_iPrimaryReserveAmmoCount")
    print("Ammo: " .. clip .. "/" .. reserve)
end
```

### Notes

- Returns **0** if prop missing
- Use exact table name and field (e.g., `m_hActiveWeapon`, `m_iHealth`)
- For vectors use `GetPropVector`; for floats use `GetPropFloat`
