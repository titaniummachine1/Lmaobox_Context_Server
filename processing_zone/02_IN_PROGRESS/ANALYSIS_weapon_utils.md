# Pattern Analysis: weapon_utils.lua

## File: projaimbot_utils_weapon_utils.lua

### Purpose

Utility module for checking if the player can shoot their weapon. Tracks weapon state and firing cooldowns using netprops.

### Key Patterns Identified

#### 1. API Usage Patterns

- **entities API:**
  - `entities:GetLocalPlayer()` - Get local player entity
- **Entity methods:**

  - `entity:GetPropEntity("m_hActiveWeapon")` - Get active weapon
  - `entity:IsValid()` - Validate entity
  - `weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime")` - Weapon fire timing
  - `weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")` - Attack cooldown
  - `weapon:GetPropInt("LocalWeaponData", "m_iClip1")` - Ammo count

- **globals API:**
  - `globals.CurTime()` - Current game time

#### 2. Common Utilities

- **State Caching Pattern:**
  ```lua
  local old_weapon, lastFire, nextAttack = nil, 0, 0
  ```
  - Caches previous weapon state to avoid unnecessary prop lookups
  - Only updates when weapon changes or fire time changes
  - Performance optimization pattern

#### 3. Guard Clauses & Error Handling

```lua
if not player then return false end
if not weapon or not weapon:IsValid() then return false end
if weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then return false end
```

- Early returns for invalid states
- Checks in order of likelihood (common failures first)
- No error logging (silent failures)

#### 4. Entity Manipulation

- **Property Access Patterns:**

  - Uses string-based property paths: `"LocalActiveTFWeaponData"`, `"LocalWeaponData"`
  - Separate tables for different weapon data types
  - Float props for timing, Int props for counts

- **Weapon State Tracking:**
  - Compares `lastFire` to detect new shots
  - Compares weapon entity to detect weapon switches
  - Updates cached `nextAttack` time only when needed

#### 5. Callback Structure

- **Module Pattern:**
  - Returns table with public functions
  - Private helper functions are local
  - No direct callback registration (utility module)

#### 6. Math/Timing Operations

- **Cooldown Check:**
  ```lua
  return nextAttack < globals.CurTime()
  ```
  - Simple time comparison
  - No epsilon/tolerance needed
  - Game time vs wall time (uses game time)

### Smart Context Opportunities

#### Functions to Document

1. **Entity:GetPropEntity**

   - Add example showing `"m_hActiveWeapon"` handle property
   - Document that it returns an Entity or nil
   - Show validation pattern with `IsValid()`

2. **Entity:GetPropFloat / GetPropInt**

   - Add more examples with weapon-specific paths:
     - `"LocalActiveTFWeaponData", "m_flLastFireTime"`
     - `"LocalActiveWeaponData", "m_flNextPrimaryAttack"`
     - `"LocalWeaponData", "m_iClip1"`
   - Document the table + property name pattern

3. **globals.CurTime()**
   - Add usage example for timing comparisons
   - Mention it's game time (not wall clock)
   - Show cooldown pattern

#### Usage Examples to Add

1. **CanShoot Pattern:**

   ```lua
   -- Efficient weapon state checking with caching
   local old_weapon, lastFire, nextAttack = nil, 0, 0

   function CanShoot()
       local player = entities:GetLocalPlayer()
       if not player then return false end

       local weapon = player:GetPropEntity("m_hActiveWeapon")
       if not weapon or not weapon:IsValid() then return false end

       -- Check ammo
       if weapon:GetPropInt("LocalWeaponData", "m_iClip1") == 0 then
           return false
       end

       -- Cache weapon state to avoid repeated prop lookups
       local lastfiretime = weapon:GetPropFloat("LocalActiveTFWeaponData", "m_flLastFireTime")
       if lastFire ~= lastfiretime or weapon ~= old_weapon then
           lastFire = lastfiretime
           nextAttack = weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
       end

       old_weapon = weapon
       return nextAttack < globals.CurTime()
   end
   ```

2. **Weapon Change Detection:**

   ```lua
   -- Detect when player switches weapons
   local cached_weapon = nil

   function OnWeaponChanged()
       local player = entities:GetLocalPlayer()
       if not player then return end

       local current = player:GetPropEntity("m_hActiveWeapon")
       if current ~= cached_weapon then
           -- Weapon changed, do something
           cached_weapon = current
       end
   end
   ```

#### Common Patterns to Document

1. **State Caching for Performance**

   - Cache expensive prop lookups
   - Only update when state changes
   - Compare both value and entity reference

2. **Weapon Property Paths**

   - Document the different `LocalWeaponData` tables
   - Explain when to use each
   - List common properties in each table

3. **Timing Checks**
   - Always use `globals.CurTime()` for game timing
   - Store next action time in local variables
   - Simple `<` comparison for "can act now" checks

### Notes

- **External Reference:**

  - Comment links to unknowncheats forum: https://www.unknowncheats.me/forum/team-fortress-2-a/273821-canshoot-function.html
  - This pattern is community-tested

- **Lmaobox API Quirks:**

  - Property paths use string table names, not direct paths
  - Must use `:IsValid()` after `:GetPropEntity()` calls
  - Property names follow Source Engine naming (m\_ prefix)

- **Performance Considerations:**
  - Caching pattern reduces prop lookups from 3 per frame to 1-3 per weapon switch
  - Critical for functions called every frame in CreateMove

### Recommended Smart Context Updates

1. **Create new file:** `data/smart_context/patterns/WeaponStateChecking.md`

   - Document the caching pattern
   - Show the CanShoot implementation
   - Explain when to use this approach

2. **Update:** `data/smart_context/Entity/GetPropEntity.md`

   - Add `m_hActiveWeapon` example
   - Show validation pattern

3. **Update:** `data/smart_context/Entity/GetPropFloat.md`

   - Add weapon timing examples
   - Show table + property syntax

4. **Update:** `data/smart_context/Entity/GetPropInt.md`

   - Add ammo check example
   - Show LocalWeaponData usage

5. **Update:** `data/smart_context/globals/CurTime.md`
   - Add cooldown checking example
   - Explain game time vs wall time

### Implementation Priority: HIGH

This is a fundamental pattern used in almost all combat-related scripts. The caching pattern is critical for performance and should be prominently featured.
