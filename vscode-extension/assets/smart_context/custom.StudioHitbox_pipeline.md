## Guide: Studio Model Hitbox Pipeline

> Full workflow from entity to world-space hitbox corners. This is the non-deprecated path for precise per-hitbox geometry in TF2.

### Object Chain

```
Entity
  └─ :GetModel()                         → model handle
       └─ models.GetStudioModel(model)   → StudioModelHeader
            └─ :GetHitboxSet(index)      → StudioHitboxSet
                 └─ :GetHitboxes()       → StudioBBox[]
                      ├─ :GetBone()      → bone index (into SetupBones result)
                      ├─ :GetBBMin()     → Vector3  (LOCAL space mins)
                      ├─ :GetBBMax()     → Vector3  (LOCAL space maxs)
                      ├─ :GetName()      → string   ("head", "pelvis", ...)
                      └─ :GetGroup()     → integer  (HITGROUP_* constant)
```

`Entity:SetupBones(boneMask, currentTime)` returns `Matrix3x4[]` — one matrix per bone, indexed by bone number. Each matrix encodes the bone's world-space position and orientation.

### Matrix Layout

```
mat[row][col]  where row = 1..3, col = 1..4
  mat[1][4], mat[2][4], mat[3][4]  →  bone origin in world space (translation)
  mat[r][1]                        →  X-axis (forward) component for row r
  mat[r][2]                        →  Y-axis (right)   component for row r
  mat[r][3]                        →  Z-axis (up)      component for row r
```

The local-frame mins/maxs from `StudioBBox` must be transformed into world space using this matrix:

```lua
-- World-space corner component for one axis:
-- worldPos = boneOrigin + localX * axisX + localY * axisY + localZ * axisZ
local x11 = mat[1][4] + vecMins.x * mat[1][1]
-- (translation)  + (local X component * bone's X-axis in world, row 1)
```

### Curated Usage Examples

#### Full pipeline: world-space 8-corner boxes for all hitboxes

```lua
local function GetEntityHitboxCorners(entity)
    assert(entity, "GetEntityHitboxCorners: entity missing")
    assert(not entity:IsDormant(), "GetEntityHitboxCorners: entity is dormant, data will be stale")

    local model = entity:GetModel()
    assert(model, "GetEntityHitboxCorners: no model")

    local studiomodel = models.GetStudioModel(model)
    assert(studiomodel, "GetEntityHitboxCorners: no studio model")

    -- m_nHitboxSet determines which hitbox set to use; fall back to 0 if missing.
    local hitboxSetIndex = entity:GetPropInt("m_nHitboxSet") or 0
    local hitboxSet = studiomodel:GetHitboxSet(hitboxSetIndex)
    if not hitboxSet then
        hitboxSet = studiomodel:GetHitboxSet(0)
    end
    assert(hitboxSet, "GetEntityHitboxCorners: no hitbox set")

    local flModelScale = entity:GetPropFloat("m_flModelScale") or 1
    local aBones = entity:SetupBones(0x7ff00, globals.CurTime())
    assert(aBones, "GetEntityHitboxCorners: SetupBones returned nil")

    local result = {}

    for _, hitbox in pairs(hitboxSet:GetHitboxes()) do
        local mat = aBones[hitbox:GetBone()]

        -- CRITICAL: aBones does NOT have an entry at bone index 0.
        -- Some hitboxes legitimately reference bone 0; mat will be nil. Skip them.
        if mat then
            local vecMins = hitbox:GetBBMin() * flModelScale
            local vecMaxs = hitbox:GetBBMax() * flModelScale

            -- Decompose transform into pre-computed row components (avoids per-corner redundancy)
            local x11, x12, x13 = mat[1][4] + vecMins.x * mat[1][1], mat[2][4] + vecMins.x * mat[2][1], mat[3][4] + vecMins.x * mat[3][1]
            local x21, x22, x23 = mat[1][4] + vecMaxs.x * mat[1][1], mat[2][4] + vecMaxs.x * mat[2][1], mat[3][4] + vecMaxs.x * mat[3][1]
            local y11, y12, y13 = vecMins.y * mat[1][2], vecMins.y * mat[2][2], vecMins.y * mat[3][2]
            local y21, y22, y23 = vecMaxs.y * mat[1][2], vecMaxs.y * mat[2][2], vecMaxs.y * mat[3][2]
            local z11, z12, z13 = vecMins.z * mat[1][3], vecMins.z * mat[2][3], vecMins.z * mat[3][3]
            local z21, z22, z23 = vecMaxs.z * mat[1][3], vecMaxs.z * mat[2][3], vecMaxs.z * mat[3][3]

            result[#result + 1] = {
                name = hitbox:GetName(),
                group = hitbox:GetGroup(),
                corners = {
                    Vector3(x11 + y11 + z11, x12 + y12 + z12, x13 + y13 + z13),
                    Vector3(x21 + y11 + z11, x22 + y12 + z12, x23 + y13 + z13),
                    Vector3(x11 + y21 + z11, x12 + y22 + z12, x13 + y23 + z13),
                    Vector3(x21 + y21 + z11, x22 + y22 + z12, x23 + y23 + z13),
                    Vector3(x11 + y11 + z21, x12 + y12 + z22, x13 + y13 + z23),
                    Vector3(x21 + y11 + z21, x22 + y12 + z22, x23 + y13 + z23),
                    Vector3(x11 + y21 + z21, x12 + y22 + z22, x13 + y23 + z23),
                    Vector3(x21 + y21 + z21, x22 + y22 + z22, x23 + y23 + z23),
                }
            }
        end
    end

    return result
end
```

#### Bone origin only (no corners needed)

```lua
-- Get bone world position from SetupBones matrix (translation column only).
local function GetBoneOrigin(entity, boneIndex)
    assert(entity, "GetBoneOrigin: entity missing")
    local aBones = entity:SetupBones(0x7ff00, globals.CurTime())
    if not aBones then return nil end
    local mat = aBones[boneIndex]
    if not mat then return nil end  -- bone index 0 may not exist
    return Vector3(mat[1][4], mat[2][4], mat[3][4])
end
```

### Notes

- **Hitbox ID instability:** `StudioBBox:GetName()` and `:GetGroup()` are more reliable than raw index for identifying which hitbox is which. Head is typically in group `HITGROUP_HEAD (1)`. Index-based probing (`hitboxes[0]`, `hitboxes[1]`) is fragile across classes.
- **Bone index 0 is absent from `SetupBones` output.** Always nil-check `aBones[hitbox:GetBone()]`. AdvancedHitboxDraw.lua comments this explicitly.
- **`m_flModelScale`:** Always multiply `GetBBMin()`/`GetBBMax()` by this prop. Default is `1`, but abnormally sized models (e.g. Saxton Hale custom maps) will be wrong without it.
- **boneMask `0x7ff00`** is the standard BONE_USED_BY_HITBOX mask. Using `0` or `255` may produce incorrect or incomplete bone data.
- **`globals.CurTime()`** must be passed as the time argument. Passing `0` is wrong for prediction-corrected positions.
- **Per-frame allocation warning:** `SetupBones` is expensive; avoid calling it multiple times per entity per frame. Cache the result in a local during the callback.
- **`GetHitboxSet` fallback:** If `m_nHitboxSet` returns a set that doesn't exist on the model, try set `0`. Some custom or unusual models only have set `0`.
- **`StudioModelHeader:GetAllHitboxSets()`** returns `StudioHitboxSet[]` — useful for debugging which sets exist on a model.
- **For quick hitbox center only:** `Entity:GetHitboxes()` is simpler (no matrix math) but is deprecated and does not account for `m_flModelScale`. See `Entity/GetHitboxes.md`. If lnxLib is available, `WPlayer:GetHitboxPos(hitboxID)` is the cleanest option.
