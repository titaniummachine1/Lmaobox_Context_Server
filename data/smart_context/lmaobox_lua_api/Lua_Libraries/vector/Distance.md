# vector.Distance() & Length Calculation Patterns

## 3D Distance (Standard)

```lua
local dist = vector.Distance(pos_a, pos_b)
-- or equivalently:
local dist = (pos_a - pos_b):Length()
```

## 2D Distance (Horizontal Only)

```lua
-- Ignore Z-axis (height), useful for checking player proximity on ground
local horizontal_dist = direction:Length2D()

-- Manual 2D (if :Length2D() unavailable):
local dx = player1.x - player2.x
local dy = player1.y - player2.y
local dist_2d = math.sqrt(dx * dx + dy * dy)
```

## Performance: Distance Comparisons

**WRONG (expensive)**:

```lua
if (player:GetAbsOrigin() - me:GetAbsOrigin()):Length() < 100 then
end
```

**CORRECT (no sqrt)**:

```lua
if (player:GetAbsOrigin() - me:GetAbsOrigin()):LengthSqr() < 10000 then
    -- 100² = 10000
end
```

This avoids the sqrt calculation — huge optimization for per-frame checks.

## Real-World Patterns from Aimbot Scripts

```lua
-- Check if targets within range
local distance_to_target = (target_position - my_position):Length()
if distance_to_target > max_range then
    return nil
end

-- Find closest entity
local closest_dist = math.huge
local closest_entity = nil
for _, ent in ipairs(nearby_entities) do
    local dist = (ent:GetAbsOrigin() - local_player:GetAbsOrigin()):Length()
    if dist < closest_dist then
        closest_dist = dist
        closest_entity = ent
    end
end

-- Path clearance checking
local dist_to_target = (trace_endpos - destination):Length()
if dist_to_target > clearance_threshold then
    -- Path blocked
end
```

## Common Pitfalls

| ❌                                          | **Don't**                                                  | ✅                       | **Do**                     |
| ------------------------------------------- | ---------------------------------------------------------- | ------------------------ | -------------------------- |
| Use `:Distance()` method                    | Vector has no `:Distance()` method; use `(a - b):Length()` | Use subtraction + Length | `dist = (a - b):Length()`  |
| Compare distances directly in hot loop      | `if dist < 100` calculates sqrt each frame                 | Use LengthSqr            | `if distSqr < 10000`       |
| Forget zero-length check before normalizing | Division by zero crash                                     | Check first              | `if vec:Length() > 0 then` |

    end
    return best, bestDist

end

```

### Notes

- Equivalent to `(b - a):Length()`; vector.Distance can be simpler
```
