## Method: Vector3.Length2D

> Get horizontal distance (ignoring Z component)

### Curated Usage Examples

#### Horizontal distance check

```lua
local me = entities.GetLocalPlayer()
local target = GetSomeTarget()

local myPos = me:GetAbsOrigin()
local targetPos = target:GetAbsOrigin()

local horizontalDist = (targetPos - myPos):Length2D()
print("2D distance: " .. horizontalDist)
```

#### Ground speed check

```lua
local vel = player:EstimateAbsVelocity()
local groundSpeed = vel:Length2D()
print("Ground speed: " .. math.floor(groundSpeed))
```

#### Ballistic calculations (projectile aimbot)

```lua
-- Calculate aim angle for projectile weapon
function CalculateBallisticArc(shootPos, targetPos, speed, gravity)
    local diff = targetPos - shootPos
    local dx = diff:Length2D()  -- Horizontal distance only
    local dy = diff.z           -- Vertical distance
    
    local speed2 = speed * speed
    local discriminant = speed2 * speed2 - gravity * (gravity * dx * dx + 2 * dy * speed2)
    
    if discriminant < 0 then
        return nil  -- No solution
    end
    
    local angle = math.atan((speed2 - math.sqrt(discriminant)) / (gravity * dx))
    local yaw = math.atan(diff.y, diff.x) * (180 / math.pi)
    local pitch = -angle * (180 / math.pi)
    
    return EulerAngles(pitch, yaw, 0)
end
```

#### Travel time estimation

```lua
-- Estimate projectile travel time
function EstimateTravelTime(shootPos, targetPos, projectileSpeed)
    local distance = (targetPos - shootPos):Length2D()
    return distance / projectileSpeed
end

-- Use for target prediction
local travelTime = EstimateTravelTime(eyePos, targetPos, 1100)
local futurePos = targetPos + targetVel * travelTime
```

#### Range checking (2D only)

```lua
-- Check if target is within weapon range (ignoring height)
local MAX_RANGE = 1500

local dist2D = (targetPos - myPos):Length2D()
if dist2D <= MAX_RANGE then
    print("Target in range")
end
```

### When to Use

- **Ballistic calculations**: Horizontal distance for trajectory physics
- **Ground-based movement**: Navigation without height
- **Yaw calculations**: Horizontal angle between points
- **Range checks**: When height doesn't matter (e.g., splash damage radius)

### Length2D vs Length

```lua
local vec = Vector3(3, 4, 5)

local full3D = vec:Length()        -- sqrt(3² + 4² + 5²) = 7.07
local horizontal = vec:Length2D()  -- sqrt(3² + 4²) = 5.0
```

- `Length2D()`: `sqrt(x² + y²)` - Only X and Y components
- `Length()`: `sqrt(x² + y² + z²)` - All three components
- `Length2D()` is faster (one less multiplication and addition)

### Notes

- **Critical for ballistic math**: Always use Length2D for horizontal distance (dx)
- **Vertical component**: Use `diff.z` or `diff:Unpack()` for dy
- **Performance**: Faster than Length() when Z doesn't matter
- **Yaw calculation**: Yaw only depends on X and Y, not Z
- Ignores Z component completely
