## Function/Symbol: Entity.GetHitboxes

> **@deprecated** — Use the `Entity:SetupBones` + studio model pipeline for anything beyond hitbox center. If you only need center, this API is still the simplest path.

### Required Context

- Signature: `Entity:GetHitboxes(currentTime?: number) -> table | nil`
- Returns: `{ [hitboxIndex] = { [1]: Vector3 mins, [2]: Vector3 maxs } }` — bounds are already in **world space**
- Hitbox index is **not stable across TF2 player classes** — a Scout's head may be a different index than a Heavy's. Scripts commonly probe index `0` first, then fall back to `1` because that covers the head on most classes, but this is a best-effort heuristic, not a guarantee.
- For precise per-hitbox work (corners, bone origins, per-model targeting): use the `SetupBones` studio pipeline (see `custom.StudioHitbox_pipeline.md`).

### Curated Usage Examples

#### Head center via GetHitboxes (deprecated, fast path)

```lua
-- Returns world-space center of the head hitbox, or nil.
-- Works on all classes without needing the studio model chain.
-- Deprecated: prefer SetupBones for anything needing corners or bone origins.
local function GetHeadCenter(entity)
    assert(entity, "GetHeadCenter: entity missing")
    local hitboxes = entity:GetHitboxes(globals.CurTime())
    if not hitboxes then return nil end

    -- Probe index 0 (head on some classes), fall back to 1.
    -- WARNING: neither index is guaranteed on all classes/hitbox sets.
    local headBox = hitboxes[0] or hitboxes[1]
    if not headBox or not headBox[1] or not headBox[2] then return nil end

    return (headBox[1] + headBox[2]) * 0.5
end
```

#### Iterating all hitboxes for center points

```lua
local function GetAllHitboxCenters(entity)
    assert(entity, "GetAllHitboxCenters: entity missing")

    local hitboxes = entity:GetHitboxes(globals.CurTime())
    if not hitboxes then return {} end

    local centers = {}
    for index, hbox in pairs(hitboxes) do
        local isValid = hbox[1] ~= nil and hbox[2] ~= nil
        if isValid then
            centers[index] = (hbox[1] + hbox[2]) * 0.5
        end
    end
    return centers
end
```

### Notes

- **Deprecated** — the engine-preferred method is `Entity:SetupBones`. Use `GetHitboxes` only when you need center quickly and don't need corners, bone matrices, or model-scale awareness.
- The returned mins/maxs are **already world-space** — no matrix transform needed, unlike the studio pipeline.
- Does **not** account for `m_flModelScale` — scaled models may return boxes that do not match the studio pipeline output.
- For world-space 8-corner boxes (precise ESP, lag compensation, multi-point trace), always use `SetupBones` + `StudioBBox:GetBBMin/Max` + matrix transform. See `custom.StudioHitbox_pipeline.md`.
- When a player is dormant, returned boxes are **stale**. Always check `not entity:IsDormant()` before calling on players.
