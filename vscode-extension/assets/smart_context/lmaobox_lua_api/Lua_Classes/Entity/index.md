## Class: Entity — Overview and Common Methods

> All entities in the game. Includes players, buildings, projectiles, weapons, and world objects.
> `get_types("Entity.MethodName")` often fails — use `smart_search` or this file for discovery.

### Validity and Safety

```lua
-- Always nil-check before use. Entity handles can go invalid mid-frame.
local ent = entities.GetByIndex(idx)
if not ent then return end

-- IsValid() checks handle is still alive in engine
-- (note: most lmaobox API functions implicitly handle this,
--  but always nil-check the return value from entities.* calls)
```

### Core Identity Methods

| Method                      | Returns    | Notes                                      |
|-----------------------------|------------|--------------------------------------------|
| `ent:GetIndex()`            | integer    | Entity index (1–32 for players)            |
| `ent:GetClass()`            | string     | Class name: `"CTFPlayer"`, `"CObjectSentrygun"` etc. |
| `ent:GetName()`             | string     | Player name (only meaningful for players)  |
| `ent:IsPlayer()`            | boolean    | True if `CTFPlayer`                        |
| `ent:IsWeapon()`            | boolean    | True if a weapon entity                    |

### State Methods

| Method                      | Returns    | Notes                                      |
|-----------------------------|------------|--------------------------------------------|
| `ent:IsAlive()`             | boolean    | False for dead/dying players               |
| `ent:IsDormant()`           | boolean    | True if not being networked (far away, etc)|
| `ent:GetHealth()`           | integer    | Current HP                                 |
| `ent:GetMaxHealth()`        | integer    | Max HP                                     |
| `ent:GetTeamNumber()`       | integer    | 2 = RED, 3 = BLU, 1 = unassigned          |
| `ent:GetMoveType()`         | integer    | E_MoveType constant                        |
| `ent:InCond(cond)`          | boolean    | Check TF condition (E_TFCOND.TFCond_*)     |

### Position and Geometry

| Method                               | Returns    | Notes                                 |
|--------------------------------------|------------|---------------------------------------|
| `ent:GetAbsOrigin()`                 | Vector3    | World position                        |
| `ent:GetAbsAngles()`                 | EulerAngles| World rotation                        |
| `ent:GetMins()`                      | Vector3    | Bounding box min offset               |
| `ent:GetMaxs()`                      | Vector3    | Bounding box max offset               |
| `ent:EstimateAbsVelocity()`          | Vector3    | Estimated velocity                    |
| `ent:GetHitboxPos(hitboxIndex)`      | Vector3?   | Position of specific hitbox           |
| `ent:GetHitboxes()`                  | table      | All hitbox positions                  |
| `ent:SetupBones()`                   | table?     | Bone transform matrices               |

### Prop Access (network properties)

| Method                                    | Returns  | Notes                          |
|-------------------------------------------|----------|--------------------------------|
| `ent:GetPropInt(table, key)`              | integer  | Single or two-arg: `GetPropInt("m_iHealth")` or `GetPropInt("tbl", "key")` |
| `ent:GetPropFloat(table, key)`            | number   |                                |
| `ent:GetPropBool(table, key)`             | boolean  |                                |
| `ent:GetPropString(table, key)`           | string   |                                |
| `ent:GetPropVector(table, key)`           | Vector3  |                                |
| `ent:GetPropEntity(table, key)`           | Entity?  |                                |
| `ent:GetPropDataTableInt(table)`          | integer[]| Returns indexed array for all players |
| `ent:SetPropInt(table, key, value)`       | —        | Write prop (local-only, not networked) |

### Weapon-specific Methods

| Method                          | Returns    | Notes                                       |
|---------------------------------|------------|---------------------------------------------|
| `ent:GetWeaponID()`             | integer    | E_WeaponBaseID constant                     |
| `ent:GetWeaponData()`           | table?     | Weapon data (damage, speed, etc.)           |
| `ent:IsShootingWeapon()`        | boolean    |                                             |
| `ent:IsMeleeWeapon()`           | boolean    |                                             |
| `ent:IsMedigun()`               | boolean    |                                             |
| `ent:GetProjectileSpeed()`      | number     | Actual projectile speed (with modifiers)    |
| `ent:GetProjectileGravity()`    | number     | Gravity scale                               |
| `ent:GetLoadoutSlot()`          | integer    | 0=primary, 1=secondary, 2=melee             |
| `ent:IsViewModelFlipped()`      | boolean    |                                             |
| `ent:GetCurrentCharge()`        | number     | For charge weapons (0.0–1.0)                |
| `ent:CanRandomCrit()`           | boolean    |                                             |
| `ent:DoSwingTrace()`            | Trace      | Simulates melee swing                       |
| `ent:GetSwingRange()`           | number     | Melee range                                 |

### Player-specific Props via GetPropInt

```lua
-- Class ID
local classId = player:GetPropInt("m_iClass") -- compare to E_Character.*

-- Ground check (important for bhop / movement)
local flags = player:GetPropInt("m_fFlags")
local onGround = (flags & FL_ONGROUND) ~= 0

-- View offset (eye position above origin)
local viewOffset = player:GetPropVector("localdata", "m_vecViewOffset[0]")
local eyePos = player:GetAbsOrigin() + viewOffset

-- Active weapon handle
local weapon = player:GetPropEntity("m_hActiveWeapon")
```

### Common Usage Patterns

#### Enemy player filter (the standard loop)

```lua
local function GetEnemyPlayers()
    local me = entities.GetLocalPlayer()
    if not me then return {} end

    local myTeam = me:GetTeamNumber()
    local results = {}

    for _, ply in pairs(entities.FindByClass("CTFPlayer")) do
        local isEnemy = ply:GetTeamNumber() ~= myTeam
        local isAlive = ply:IsAlive()
        local isVisible = not ply:IsDormant()
        local isCloaked = ply:InCond(E_TFCOND.TFCond_Cloaked)

        if isEnemy and isAlive and isVisible and not isCloaked then
            results[#results + 1] = ply
        end
    end

    return results
end
```

#### Eye position helper

```lua
local function GetEyePos(player)
    local origin = player:GetAbsOrigin()
    local viewOffset = player:GetPropVector("localdata", "m_vecViewOffset[0]")
    assert(origin, "GetEyePos: missing origin")
    assert(viewOffset, "GetEyePos: missing viewOffset")
    return origin + viewOffset
end
```

#### Team-based color selection

```lua
local function GetTeamColor(entity)
    local team = entity:GetTeamNumber()
    if team == 2 then return 255, 50,  50,  255 end  -- RED
    if team == 3 then return 50,  100, 255, 255 end  -- BLU
    return 200, 200, 200, 255                         -- fallback
end
```

#### Bounding box center

```lua
local function GetEntityCenter(entity)
    local origin = entity:GetAbsOrigin()
    local mins = entity:GetMins()
    local maxs = entity:GetMaxs()
    return origin + (mins + maxs) * 0.5
end
```

#### BuildingFilter for targeting sentries/dispensers/teleporters

```lua
local BUILDING_CLASSES = {
    ["CObjectSentrygun"]  = true,
    ["CObjectDispenser"]  = true,
    ["CObjectTeleporter"] = true,
}

local function IsEnemyBuilding(entity, myTeam)
    local class = entity:GetClass()
    if not BUILDING_CLASSES[class] then return false end
    if entity:GetTeamNumber() == myTeam then return false end
    if entity:GetHealth() <= 0 then return false end
    if entity:IsDormant() then return false end
    return true
end
```

### Notes

- `GetClass()` returns the C++ class name — useful for filtering; see valve wiki for class names
- `IsDormant()` returns true for players that aren't networked (outside PVS or too far)
- Never call `GetHitboxPos` or `GetHitboxes` without checking `IsAlive()` first — crashes on dead players
- `EstimateAbsVelocity()` can return `nil` — always guard with `or Vector3(0,0,0)`
- Buildings are NOT players: `IsPlayer()` returns false; use `GetClass()` to identify them
- `GetHealth()` on buildings returns current HP correctly
