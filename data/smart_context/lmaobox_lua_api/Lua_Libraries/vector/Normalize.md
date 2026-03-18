# vector.Normalize() - Performance & Safety Patterns

## Recommended Approaches (Ranked by Use Case)

### **Fastest Method** (For hot loops, CreateMove)

```lua
return vector.Divide(vec, vec:Length())
```

- Direct library call
- No intermediate variable allocation
- Best for per-frame operations

### **Best Immutable Method** (Most readable & safe)

```lua
local function normalize_vector(vec)
    return vec / vec:Length()
end
```

- Zero-length safe when wrapped with check (see below)
- Cleaner syntax, returns new vector
- Preferred for non-critical paths

### **Manual Implementation** (When library unavailable)

```lua
local function Normalize(vec)
    local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
    return Vector3(vec.x / length, vec.y / length, vec.z / length)
end
```

- Pure Lua, no dependencies
- **WARNING**: Fails silently if `length == 0`

## Safe Normalization Pattern (Recommended)

```lua
local function normalize_safe(direction)
    local direction_length = direction:Length()

    -- CRITICAL: Check for zero-length vector
    if direction_length == 0 then
        return nil  -- or return default direction like Vector3(1, 0, 0)
    end

    return direction / direction_length
end
```

## Common Use Cases from Processing Zone

```lua
-- Building perpendicular vector from normalized direction
local normalized_direction = normalize_safe(target_direction)
if normalized_direction then
    local perpendicular = Vector3(
        normalized_direction.y,
        -normalized_direction.x,
        0
    ) * radius
end

-- Angle + velocity combination
local time_to_target = direction:Length() / projectile_speed
local normalized = direction / direction:Length()
local vel = angles:Forward() * normalized:Length()
```

## Performance Note

- `vector:Length()` is O(sqrt(x² + y² + z²)) — call once and cache
- Use `direction:LengthSqr()` for distance **comparisons only** (avoids sqrt)
- Example: `if (pos1 - pos2):LengthSqr() < 10000 then` instead of `< 100`
