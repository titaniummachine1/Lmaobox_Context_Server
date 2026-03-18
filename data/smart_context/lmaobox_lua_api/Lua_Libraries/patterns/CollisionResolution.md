## Pattern: Proper Collision Resolution

> Slide along multiple collision planes correctly (not just walls)

### The Problem

Simple collision handling only slides along one plane:

```lua
-- TOO SIMPLE - doesn't handle corners or multiple surfaces
if hit then
    local dot = vel:Dot(normal)
    vel = vel - normal * dot  -- Only handles one plane
end
```

This breaks when hitting:

- Corners (2 planes)
- Edges (3+ planes)
- Complex geometry

### Proper Solution: Multi-Plane Clipping

```lua
local MAX_CLIP_PLANES = 5

---@param velocity Vector3
---@param normal Vector3
---@param overbounce number Usually 1.0
local function ClipVelocity(velocity, normal, overbounce)
    local backoff = velocity:Dot(normal) * overbounce

    velocity.x = velocity.x - normal.x * backoff
    velocity.y = velocity.y - normal.y * backoff
    velocity.z = velocity.z - normal.z * backoff

    -- Zero out tiny components
    if math.abs(velocity.x) < 0.01 then velocity.x = 0 end
    if math.abs(velocity.y) < 0.01 then velocity.y = 0 end
    if math.abs(velocity.z) < 0.01 then velocity.z = 0 end
end
```

### Complete Collision Move

```lua
---@param origin Vector3 Current position (modified in-place)
---@param velocity Vector3 Current velocity (modified in-place)
---@param mins Vector3
---@param maxs Vector3
---@param tickInterval number
---@return Vector3 Final position
local function TryPlayerMove(origin, velocity, mins, maxs, tickInterval)
    local timeLeft = tickInterval
    local planes = {}
    local numPlanes = 0

    -- Try up to 4 movement attempts (handles bumps/slides)
    for bumpCount = 0, 3 do
        if timeLeft <= 0 then break end

        -- Calculate desired end position
        local endPos = origin + velocity * timeLeft

        -- Trace to end position
        local trace = engine.TraceHull(
            origin,
            endPos,
            mins,
            maxs,
            MASK_PLAYERSOLID
        )

        -- Move to wherever we got
        if trace.fraction > 0 then
            origin.x = trace.endpos.x
            origin.y = trace.endpos.y
            origin.z = trace.endpos.z
            numPlanes = 0
        end

        -- Made it all the way
        if trace.fraction == 1 then
            break
        end

        -- Reduce remaining time
        timeLeft = timeLeft - timeLeft * trace.fraction

        -- Store this collision plane
        if trace.plane and numPlanes < MAX_CLIP_PLANES then
            planes[numPlanes] = trace.plane
            numPlanes = numPlanes + 1
        end

        -- Modify velocity to slide along planes
        if trace.plane then
            -- Stop downward movement on ground
            if trace.plane.z > 0.7 and velocity.z < 0 then
                velocity.z = 0
            end

            -- Clip velocity against all planes we've hit
            local i = 0
            while i < numPlanes do
                ClipVelocity(velocity, planes[i], 1.0)

                -- Check if velocity still goes into any plane
                local j = 0
                while j < numPlanes do
                    if j ~= i then
                        local dot = velocity:Dot(planes[j])
                        if dot < 0 then
                            break  -- Still going into a plane
                        end
                    end
                    j = j + 1
                end

                if j == numPlanes then
                    break  -- Velocity is good
                end

                i = i + 1
            end

            -- If going into all planes, stop or slide along crease
            if i == numPlanes then
                if numPlanes >= 2 then
                    -- Slide along crease between two planes
                    local dir = Vector3(
                        planes[0].y * planes[1].z - planes[0].z * planes[1].y,
                        planes[0].z * planes[1].x - planes[0].x * planes[1].z,
                        planes[0].x * planes[1].y - planes[0].y * planes[1].x
                    )

                    local d = dir:Dot(velocity)
                    velocity.x = dir.x * d
                    velocity.y = dir.y * d
                    velocity.z = dir.z * d
                end

                -- Still going into a plane? Stop completely
                local dot = velocity:Dot(planes[0])
                if dot < 0 then
                    velocity.x = 0
                    velocity.y = 0
                    velocity.z = 0
                    break
                end
            end
        else
            break
        end
    end

    return origin
end
```

### How It Works

1. **Multi-Bump Loop**: Try movement up to 4 times
2. **Trace Movement**: See where we can actually go
3. **Store Planes**: Remember all surfaces we hit
4. **Clip Against All**: Remove velocity going into any plane
5. **Crease Handling**: When hitting 2+ planes, slide along the edge
6. **Stop Check**: If still hitting planes, stop all movement

### Integration

```lua
-- In your simulation loop:
for tick = 1, ticks do
    -- ... apply forces, gravity, etc ...

    -- Use proper collision resolution
    newPos = TryPlayerMove(
        newPos,
        newVel,
        mins,
        maxs,
        globals.TickInterval()
    )

    -- newPos and newVel are modified in-place
end
```

### Visual Difference

**Simple (wrong):**

```
Player → Wall
         ↓ (slides down, gets stuck in corner)
```

**Proper (correct):**

```
Player → Wall ┐
              ↓ Floor (slides along corner edge properly)
```

### Notes

- Handles corners, edges, complex geometry correctly
- Matches Source engine collision behavior
- `overbounce` of 1.0 means no bounce (slide only)
- Ground plane check: `z > 0.7` (approximately 45° slope)
- Crease calculation uses cross product of two plane normals
