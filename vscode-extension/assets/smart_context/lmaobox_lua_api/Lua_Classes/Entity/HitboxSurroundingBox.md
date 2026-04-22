## Function/Symbol: Entity.HitboxSurroundingBox

> Returns a coarse world-space AABB that loosely wraps the entire entity. **This is NOT the actual game collision box and does not represent per-hitbox precision.**

### Required Context

- Signature: `Entity:HitboxSurroundingBox() -> { [1]: Vector3 mins, [2]: Vector3 maxs } | nil`
- Returns two world-space vectors: `[1]` = mins corner, `[2]` = maxs corner
- The box surrounds the whole model, not individual hitboxes
- The engine uses this for broad-phase culling, not hit detection

### Curated Usage Examples

#### Coarse entity bounds (debug / culling)

```lua
-- Cheap visibility cull: skip entity if its bounding box is fully off-screen.
local function IsEntityPotentiallyVisible(entity)
    assert(entity, "IsEntityPotentiallyVisible: entity missing")
    local bounds = entity:HitboxSurroundingBox()
    if not bounds or not bounds[1] or not bounds[2] then return false end

    local screenMins = client.WorldToScreen(bounds[1])
    local screenMaxs = client.WorldToScreen(bounds[2])
    return screenMins ~= nil or screenMaxs ~= nil
end
```

#### Hit-history visualization (box highlight on damage)

```lua
-- Record the surrounding box at the moment of a hit for a brief flash effect.
-- Using the coarse box is intentional here: we want a visible indicator, not precise hitbox data.
local function RecordHitBounds(entity)
    assert(entity, "RecordHitBounds: entity missing")
    local bounds = entity:HitboxSurroundingBox()
    if not bounds then return nil end
    return { mins = bounds[1], maxs = bounds[2], time = globals.CurTime() }
end
```

### Notes

- **NOT the actual collision box.** TF2 hit detection uses per-hitbox capsule/AABB checks from the studio model; this surrounding box just wraps the whole model loosely.
- **Use for:** debug ESP bounding boxes, broad-phase culling, hit-flash visualizations, anything where approximate size is sufficient.
- **Do NOT use for:** aimpoint selection, trace endpoint, per-hitbox targeting, or anything requiring precision.
- Also see: `Entity:EntitySpaceHitboxSurroundingBox()` — same concept but in entity-local space (useful if you need it untransformed for further manual matrix work).
- When a player is dormant, the returned bounds will be stale. Always guard with `not entity:IsDormant()`.
