## Constants Reference: E_Character (TF2 Class IDs)

> Player class integer IDs. Used with `entity:GetPropInt("m_iClass")` and `E_Character.*` enum.
> The `E_Character` table is globally available; individual constants are also global integers.

### Class ID Table

| Constant               | Value | Class         |
|------------------------|-------|---------------|
| `E_Character.TF2_Scout`    | 1 | Scout         |
| `E_Character.TF2_Sniper`   | 2 | Sniper        |
| `E_Character.TF2_Soldier`  | 3 | Soldier       |
| `E_Character.TF2_Demoman`  | 4 | Demoman       |
| `E_Character.TF2_Medic`    | 5 | Medic         |
| `E_Character.TF2_Heavy`    | 6 | Heavy         |
| `E_Character.TF2_Pyro`     | 7 | Pyro          |
| `E_Character.TF2_Spy`      | 8 | Spy           |
| `E_Character.TF2_Engineer` | 9 | Engineer      |

> **Note**: The local definition `E_Character = { TF2_Scout = 1, ... }` seen in some scripts is a
> user-defined table. The constants are also defined globally by the engine environment — both forms work.

### Curated Usage Examples

#### Get local player class

```lua
local me = entities.GetLocalPlayer()
if not me then return end
local classId = me:GetPropInt("m_iClass")
local isScout = classId == E_Character.TF2_Scout
```

#### Class-specific logic in Draw

```lua
callbacks.Register("Draw", "class_check", function()
    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then return end

    local class = me:GetPropInt("m_iClass")

    if class == E_Character.TF2_Scout then
        -- double jump logic
    elseif class == E_Character.TF2_Medic then
        -- uber tracking logic
    elseif class == E_Character.TF2_Engineer then
        -- sentry tracking
    end
end)
```

#### Target filtering by class

```lua
local function IsHardToHit(entity)
    local class = entity:GetPropInt("m_iClass")
    -- Scouts are fast; Snipers are often stationary
    return class == E_Character.TF2_Scout
end

local function GetHitboxBonus(entity)
    local class = entity:GetPropInt("m_iClass")
    if class == E_Character.TF2_Heavy or class == E_Character.TF2_Soldier then
        return 5  -- bonus score: big hitbox
    end
    if class == E_Character.TF2_Scout then
        return -10  -- penalty: small and fast
    end
    return 0
end
```

#### Class name lookup (for display)

```lua
local CLASS_NAMES = {
    [1] = "Scout",
    [2] = "Sniper",
    [3] = "Soldier",
    [4] = "Demoman",
    [5] = "Medic",
    [6] = "Heavy",
    [7] = "Pyro",
    [8] = "Spy",
    [9] = "Engineer",
}

local function GetClassName(entity)
    local classId = entity:GetPropInt("m_iClass")
    return CLASS_NAMES[classId] or ("Unknown(" .. tostring(classId) .. ")")
end
```

#### In CalculateHitchance / confidence scoring

```lua
-- From real projectile aimbot: penalize Scouts, bonus for Heavy/Sniper
local class = entity:GetPropInt("m_iClass")
if class == E_Character.TF2_Scout then
    score = score - 10
elseif class == E_Character.TF2_Heavy or class == E_Character.TF2_Sniper then
    score = score + 5
end
```

### Notes

- `m_iClass` is the prop path; no sub-table needed
- Class `0` = no class (spectator or unassigned)
- The `E_Character` enum table uses `TF2_` prefix, not `TF_CLASS_` (that's Source engine C++, not Lua API)
- For enemy players iteration: `entities.FindByClass("CTFPlayer")` returns all players — filter by `GetTeamNumber()` not class
