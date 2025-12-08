## Pattern: Binary Search for Splash/Visibility

> Find closest visible point along a line

### Required Context

- Functions: engine.TraceLine, CanDamageFrom (custom)
- Pattern: Iterative binary search between visible/invisible points

### Curated Usage Examples

#### Binary search for closest splash point

```lua
local function BinarySearchClosestVisible(visiblePt, targetPt, viewPos, iterations)
    iterations = iterations or 8

    local low, high = 0, 1
    local best = visiblePt

    for i = 1, iterations do
        local mid = (low + high) * 0.5
        local testPos = visiblePt + (targetPt - visiblePt) * mid

        -- Check if still visible from player
        local trace = engine.TraceLine(viewPos, testPos, MASK_SHOT_HULL)

        if trace.fraction > 0.99 then
            -- Still visible, move closer to target
            best = testPos
            low = mid
        else
            -- Not visible, move back
            high = mid
        end
    end

    return best
end

-- Usage
local me = entities.GetLocalPlayer()
local eye = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
local targetCenter = target:GetAbsOrigin()
local targetSurface = GetClosestSurfacePoint(targetCenter) -- your surface finder

local closest = BinarySearchClosestVisible(eye, targetSurface, eye, 8)
print("Closest visible point: " .. tostring(closest))
```

#### Search along plane

```lua
local function BinarySearchOnPlane(hub, planeNormal, targetPt, viewPos, maxDist)
    -- Project direction onto plane
    local rawDir = targetPt - hub
    local projDir = rawDir - planeNormal * rawDir:Dot(planeNormal)
    local dir = projDir / projDir:Length()

    local low, high = 0, math.min(projDir:Length(), maxDist)
    local best = hub

    for i = 1, 8 do
        local mid = (low + high) * 0.5
        local testPos = hub + dir * mid

        local trace = engine.TraceLine(viewPos, testPos, MASK_SHOT_HULL)

        if trace.fraction > 0.99 then
            best = testPos
            low = mid
        else
            high = mid
        end
    end

    return best
end
```

### Notes

- 8 iterations gives ~0.4% precision (1/256)
- Use for finding edges of visibility / splash damage zones
- Combine with plane normal checks for surface-constrained search

