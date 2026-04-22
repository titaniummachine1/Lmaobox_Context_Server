## Pattern: NaN (Not-a-Number) Handling

> Detect and sanitize NaN values to prevent crashes and invalid calculations

### Context

Mathematical operations like division by zero, `sqrt` of negative numbers, or `acos` of values outside [-1, 1] can produce NaN (Not-a-Number) in Lua. NaN propagates through calculations and can cause crashes, freezes, or silent failures in game engines.

### The Problem

```lua
local result = 0 / 0  -- NaN
local angle = math.acos(2.0)  -- NaN (acos domain is [-1, 1])
local bad = math.sqrt(-1)  -- NaN

-- NaN propagates
local x = result + 5  -- x is NaN
local y = angle * 2  -- y is NaN

-- Can cause engine crashes
cmd.viewangles = Vector3(bad, 0, 0)  -- Crash or freeze!
```

### Detection Method

```lua
local function isNaN(x)
    return x ~= x
end
```

**Why this works:**
- IEEE 754 standard: NaN is the only value that is not equal to itself
- `NaN == NaN` returns `false`
- `NaN ~= NaN` returns `true`

### Sanitization Pattern

```lua
local function isNaN(x)
    return x ~= x
end

-- Sanitize to 0
local pitch = calculatePitch()
if isNaN(pitch) then
    pitch = 0
end

-- Or use fallback value
local angle = calculateAngle()
if isNaN(angle) then
    angle = defaultAngle
end
```

### Complete Example: Angle Calculations

```lua
local function isNaN(x)
    return x ~= x
end

local M_RADPI = 180 / math.pi

function CalculatePitchYaw(source, dest)
    local delta = source - dest
    
    -- These can produce NaN
    local pitch = math.atan(delta.z / delta:Length2D()) * M_RADPI
    local yaw = math.atan(delta.y / delta.x) * M_RADPI
    
    if delta.x >= 0 then
        yaw = yaw + 180
    end
    
    -- Sanitize before use
    if isNaN(pitch) then 
        pitch = 0 
    end
    
    if isNaN(yaw) then 
        yaw = 0 
    end
    
    return pitch, yaw
end
```

### Common NaN Sources

#### 1. Division by Zero

```lua
-- Bad: Can produce NaN
local length = vec:Length()
local normalized = vec / length  -- NaN if length == 0

-- Good: Check first
local length = vec:Length()
if length > 0.0001 then
    local normalized = vec / length
else
    -- Handle zero vector
    normalized = Vector3(1, 0, 0)
end
```

#### 2. Domain Errors

```lua
-- Bad: acos domain is [-1, 1]
local dotProduct = v1:Dot(v2) / (v1:Length() * v2:Length())
local angle = math.acos(dotProduct)  -- NaN if |dotProduct| > 1

-- Good: Clamp to valid range
local dotProduct = v1:Dot(v2) / (v1:Length() * v2:Length())
dotProduct = math.max(-1, math.min(1, dotProduct))
local angle = math.acos(dotProduct)
```

#### 3. Negative Square Roots

```lua
-- Bad: sqrt of negative
local discriminant = speed^4 - g * (g * dx^2 + 2 * dy * speed^2)
local root = math.sqrt(discriminant)  -- NaN if discriminant < 0

-- Good: Check before sqrt
if discriminant < 0 then
    return nil  -- No solution
end
local root = math.sqrt(discriminant)
```

#### 4. FOV Calculation

```lua
local function isNaN(x)
    return x ~= x
end

function CalculateFOV(angleFrom, angleTo)
    local vSrc = angleFrom:Forward()
    local vDst = angleTo:Forward()
    
    local dotProduct = vDst:Dot(vSrc)
    local lengthProduct = vDst:Length() * vSrc:Length()
    
    -- Prevent division by zero and clamp for acos
    if lengthProduct < 0.0001 then
        return 0
    end
    
    local cosAngle = dotProduct / lengthProduct
    cosAngle = math.max(-1, math.min(1, cosAngle))  -- Clamp to [-1, 1]
    
    local fov = math.acos(cosAngle) * (180 / math.pi)
    
    -- Sanitize result
    if isNaN(fov) then
        fov = 0
    end
    
    return fov
end
```

### Prevention Strategies

#### 1. Guard Clauses

```lua
function SafeDivide(a, b)
    if math.abs(b) < 0.0001 then
        return 0  -- or nil, or default value
    end
    return a / b
end
```

#### 2. Clamping

```lua
function SafeAcos(x)
    x = math.max(-1, math.min(1, x))
    return math.acos(x)
end
```

#### 3. Epsilon Comparisons

```lua
local EPSILON = 0.0001

if math.abs(length) < EPSILON then
    -- Treat as zero
end
```

#### 4. Early Returns

```lua
function CalculateAngle(vec)
    if vec:Length() < 0.0001 then
        return nil  -- Can't calculate angle of zero vector
    end
    
    -- Safe to proceed
    local normalized = vec / vec:Length()
    return math.atan(normalized.y, normalized.x)
end
```

### Testing for NaN

```lua
-- Test various NaN-producing operations
local testCases = {
    0 / 0,
    math.sqrt(-1),
    math.acos(2),
    math.asin(2),
    math.log(-1)
}

for i, val in ipairs(testCases) do
    if isNaN(val) then
        print("Test case " .. i .. " produced NaN")
    end
end
```

### Engine Integration

```lua
function SafeSetViewAngles(pitch, yaw, roll)
    -- Sanitize all components
    if isNaN(pitch) then pitch = 0 end
    if isNaN(yaw) then yaw = 0 end
    if isNaN(roll) then roll = 0 end
    
    -- Additional bounds checking
    pitch = math.max(-89, math.min(89, pitch))
    yaw = yaw % 360
    
    engine.SetViewAngles(EulerAngles(pitch, yaw, roll))
end

function SafeCreateMove(cmd)
    -- Calculate angles
    local pitch, yaw = CalculateAimAngles()
    
    -- Sanitize before applying
    if isNaN(pitch) then pitch = 0 end
    if isNaN(yaw) then yaw = 0 end
    
    cmd.viewangles = Vector3(pitch, yaw, 0)
end
```

### Performance Note

The `isNaN` check is very fast (single comparison). Use liberally on any mathematically-derived values before:
- Setting view angles
- Drawing to screen
- Storing in tables
- Passing to engine functions

### Debugging NaN Issues

```lua
local function debugValue(name, value)
    if isNaN(value) then
        print(string.format("WARNING: %s is NaN!", name))
        print(debug.traceback())  -- Show where NaN originated
    end
end

-- Use in calculations
local pitch = calculatePitch()
debugValue("pitch", pitch)

local yaw = calculateYaw()
debugValue("yaw", yaw)
```

### Complete Pattern Template

```lua
-- Module-level
local function isNaN(x)
    return x ~= x
end

-- In calculation functions
function CalculateSomething(input)
    -- Validate input
    if not input or input:Length() < 0.0001 then
        return nil
    end
    
    -- Perform calculation with guards
    local denominator = getSomeDenominator()
    if math.abs(denominator) < 0.0001 then
        return nil
    end
    
    local result = calculateValue(input, denominator)
    
    -- Sanitize output
    if isNaN(result) then
        return nil  -- or 0, or default
    end
    
    return result
end
```

### Related Patterns

- **Guard Clauses**: Validate inputs before calculations
- **Zero Trust**: Assert all external data
- **Ballistic Calculations**: Common source of NaN values
- **Vector Math**: Normalization and dot products need checks

### Notes

- NaN propagates through all operations (except comparisons)
- Some Lmaobox/Source engine functions crash on NaN input
- Always sanitize before setting view angles or spawning entities
- IEEE 754 defines NaN behavior consistently across platforms
- Lua 5.1+ supports IEEE 754 floating point

### Why NaN ≠ NaN

From IEEE 754 standard:
> "Every NaN shall compare unordered with everything, including itself."

This property allows the `x ~= x` trick and prevents NaN from appearing equal to anything, which would mask bugs.