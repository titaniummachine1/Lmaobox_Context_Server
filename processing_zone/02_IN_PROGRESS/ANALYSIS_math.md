# Pattern Analysis: math.lua (Projectile Utilities)

## File: projaimbot_utils_math.lua

### Purpose
Comprehensive math utility library for projectile aimbots. Handles ballistic arc calculations, angle conversions, FOV calculations, and vector operations. Core module for any projectile prediction system.

### Key Patterns Identified

#### 1. API Usage Patterns

- **Lua math library:**
  - `math.atan()` - Arctangent for angle calculations
  - `math.acos()` - Arccosine for FOV calculations
  - `math.asin()` - Arcsine for direction to angles
  - `math.sqrt()` - Square root for discriminant calculations
  - `math.sin()` - Sine for flight time calculations
  - `math.pi` - Pi constant for radian/degree conversion
  - `math.max()`, `math.min()` - Clamping values

- **Vector3 methods:**
  - `vector:Length()` - Vector magnitude
  - `vector:Length2D()` - Horizontal distance (ignoring Z)
  - `vector:LengthSqr()` - Squared length (optimization)
  - `vector:Dot()` - Dot product for angles
  - `vector:Cross()` - Cross product for perpendicular vectors
  - Vector arithmetic: `+`, `-`, `*`, `/`

- **EulerAngles:**
  - `EulerAngles(pitch, yaw, roll)` - Constructor
  - `angles:Forward()` - Get forward direction vector
  - `angles:Unpack()` - Extract pitch, yaw, roll

#### 2. Common Utilities

- **NaN Detection:**
  ```lua
  local function isNaN(x) return x ~= x end
  ```
  - IEEE 754 NaN property: NaN ≠ NaN
  - Used to sanitize math results
  - Prevents crash/freeze from invalid calculations

- **Radian to Degree Conversion:**
  ```lua
  local M_RADPI = 180 / math.pi
  ```
  - Constant for rad→deg conversion
  - Multiply angle by M_RADPI
  - Named from LnxLib (credited in comments)

- **Vector Normalization:**
  ```lua
  local function NormalizeVector(vec)
      return vec / vec:Length()
  end
  ```
  - Simple in-place normalization
  - No zero-check (trusts environment handles division by zero)
  - Returns unit vector

#### 3. Guard Clauses & Error Handling

```lua
if root < 0 then return nil end
if dx == 0 then return nil, nil end
if discriminant < 0 then return nil end
if isNaN(pitch) then pitch = 0 end
```

- **Graceful Failures:**
  - Returns `nil` when no solution exists
  - Sanitizes NaN to 0 (prevents propagation)
  - No error logging (silent failures)
  - Caller must check for nil

- **Mathematical Validity:**
  - Checks discriminant before sqrt
  - Prevents divide-by-zero in atan
  - Handles edge cases in ballistic equations

#### 4. Ballistic Calculations

**Core Physics:**
- Uses quadratic formula for projectile arcs
- Discriminant: `speed² * speed² - g * (g * dx² + 2 * dy * speed²)`
- Low arc: `(speed² - √discriminant) / (g * dx)`
- High arc: `(speed² + √discriminant) / (g * dx)`

**Z-Axis Convention:**
- Positive Z = Up
- Negative pitch = Looking up
- TF2/Source engine convention

#### 5. Function Categories

**Angle Calculations:**
1. `PositionAngles(source, dest)` - Look angles from point to point
2. `AngleFov(vFrom, vTo)` - FOV between two angles
3. `DirectionToAngles(direction)` - Direction vector to angles

**Ballistic Solutions:**
1. `SolveBallisticArc(p0, p1, speed, gravity)` - Get low arc aim angles
2. `SolveBallisticArcBoth(p0, p1, speed, gravity)` - Get both arcs
3. `GetBallisticFlightTime(p0, p1, speed, gravity)` - Time to impact

**Utilities:**
1. `EstimateTravelTime(shootPos, targetPos, speed)` - Simple distance/speed
2. `clamp(val, min, max)` - Value clamping
3. `RotateOffsetAlongDirection(offset, direction)` - Transform offset vector
4. `NormalizeVector(vec)` - Unit vector

#### 6. Vector/Math Operations

**Cross Product Usage:**
```lua
local right = NormalizeVector(forward:Cross(up))
up = NormalizeVector(right:Cross(forward))
```
- Constructs orthonormal basis
- Creates coordinate system from forward vector
- Used in `RotateOffsetAlongDirection`

**Dot Product for Angles:**
```lua
local fov = M_RADPI * math.acos(vDst:Dot(vSrc) / vDst:LengthSqr())
```
- Dot product gives cos(angle)
- Acos converts to angle
- Divided by LengthSqr (should be Length² of both vectors)
  - **BUG**: Should be `vDst:Length() * vSrc:Length()` or both normalized first

**2D vs 3D Distance:**
- `Length2D()` - Horizontal distance only
- `Length()` - Full 3D distance
- Critical distinction for ballistic calculations

### Smart Context Opportunities

#### Functions to Document

1. **Vector3:Length2D()**
   - Document horizontal distance calculation
   - Show ballistic arc usage
   - Explain when to use vs Length()

2. **Vector3:Cross()**
   - Document cross product
   - Show orthonormal basis construction
   - Explain right-hand rule

3. **EulerAngles:Forward()**
   - Convert angles to direction vector
   - Show FOV calculation usage
   - Explain coordinate system

4. **math.atan(y, x)** (two-argument form)
   - Document atan2 functionality
   - Show yaw calculation from x,y
   - Explain quadrant handling

#### Usage Examples to Add

1. **Ballistic Arc Aiming:**
   ```lua
   local eyePos = localPlayer:GetAbsOrigin() + localPlayer:GetPropVector("localdata", "m_vecViewOffset[0]")
   local targetPos = target:GetAbsOrigin()
   local speed = 1100 -- projectile speed
   local gravity = 800 -- sv_gravity * 0.5
   
   local angle = Math.SolveBallisticArc(eyePos, targetPos, speed, gravity)
   if angle then
       cmd.viewangles = Vector3(angle:Unpack())
   end
   ```

2. **FOV Check for Aimbot:**
   ```lua
   local viewAngles = engine.GetViewAngles()
   local targetAngles = Math.PositionAngles(eyePos, targetPos)
   local fov = Math.AngleFov(viewAngles, targetAngles)
   
   if fov <= maxFOV then
       -- Target in FOV, can aim
   end
   ```

3. **NaN Sanitization Pattern:**
   ```lua
   local function isNaN(x) 
       return x ~= x 
   end
   
   local pitch = calculatePitch()
   if isNaN(pitch) then 
       pitch = 0 
   end
   ```

4. **Coordinate System Construction:**
   ```lua
   local forward = NormalizeVector(aimDirection)
   local up = Vector3(0, 0, 1)
   local right = NormalizeVector(forward:Cross(up))
   up = NormalizeVector(right:Cross(forward))
   
   -- Now have complete orthonormal basis
   local transformed = forward * offset.x + right * offset.y + up * offset.z
   ```

#### Common Patterns to Document

1. **Ballistic Calculation Pattern**
   - Quadratic formula for projectile arcs
   - Discriminant checking
   - Low vs high arc selection
   - Gravity scaling (sv_gravity * 0.5 for TF2)

2. **NaN Handling**
   - Detection: `x ~= x`
   - Sanitization: Replace with 0
   - Critical for division operations
   - Prevents crash/freeze

3. **2D Horizontal Math**
   - Use `Length2D()` for distance
   - Use `dx = sqrt(diff.x² + diff.y²)`
   - Ignores vertical component
   - Important for yaw calculation

4. **Angle Conversion**
   - Store `M_RADPI = 180 / math.pi`
   - Multiply radians by M_RADPI for degrees
   - Source engine uses degrees
   - Lua math uses radians

### Notes

- **External Credit:**
  - "Pasted from Lnx00's LnxLib" - Common utility functions
  - Community-standard implementations

- **Physics Accuracy:**
  - Uses proper ballistic equations
  - Handles both high and low arc solutions
  - Accounts for gravity and initial velocity
  - Flight time calculation includes vertical component

- **Potential Bug:**
  - In `AngleFov()`: `vDst:Dot(vSrc) / vDst:LengthSqr()`
  - Should probably be: `vDst:Dot(vSrc) / (vDst:Length() * vSrc:Length())`
  - Or normalize both vectors first
  - May work if vectors are already normalized

- **Engine Conventions:**
  - Negative pitch = looking up
  - Yaw wraps at 180°
  - Z-axis points up
  - Matches Source Engine coordinate system

### Recommended Smart Context Updates

1. **Create:** `data/smart_context/patterns/BallisticCalculations.md`
   - Document projectile arc physics
   - Show complete aimbot example
   - Explain gravity scaling
   - Cover flight time prediction

2. **Create:** `data/smart_context/patterns/VectorMath.md`
   - Cross product for orthonormal basis
   - Dot product for angles
   - 2D vs 3D distance
   - Normalization patterns

3. **Create:** `data/smart_context/patterns/NaNHandling.md`
   - Detection method
   - Sanitization approach
   - When to use
   - Why it matters

4. **Update:** `data/smart_context/Vector3/Length2D.md`
   - Add ballistic calculation example
   - Show when to use vs Length()
   - Explain horizontal distance importance

5. **Update:** `data/smart_context/Vector3/Cross.md`
   - Add coordinate system construction
   - Show right-hand rule
   - Explain orthonormal basis

6. **Update:** `data/smart_context/Vector3/Dot.md`
   - Add angle calculation example
   - Show FOV computation
   - Explain cosine relationship

7. **Create:** `data/smart_context/examples/ProjectileAimbot.md`
   - Complete working example
   - Combines multiple patterns
   - Shows real-world usage
   - References all helper functions

### Implementation Priority: CRITICAL

This is the mathematical foundation for all projectile-based aimbots. The ballistic calculations, angle conversions, and vector operations are essential knowledge for anyone working with projectile weapons in TF2. Should be prominently featured with extensive examples.

### Related Scripts to Analyze

- `playersim.lua` - Player position prediction (uses these math functions)
- `projectilesim.lua` - Projectile simulation (validates ballistic solutions)
- `multipoint.lua` - Hitbox targeting (uses angle calculations)
- `main.lua` - Integration of all systems (shows complete usage)