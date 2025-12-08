## Function/Symbol: models.GetStudioModel

> Get StudioModelHeader for a model (access hitboxes, bones)

### Required Context

- Parameters: model (string - model path)
- Returns: StudioModelHeader
- Use with: Entity:SetupBones for hitbox transforms

### Curated Usage Examples

#### Get hitboxes from entity

```lua
local function GetEntityHitboxes(entity)
    local model = entity:GetModel()
    if not model then return {} end

    local studiomodel = models.GetStudioModel(model)
    if not studiomodel then return {} end

    local hitboxSet = entity:GetPropInt("m_nHitboxSet") or 0
    local setHitboxes = studiomodel:GetHitboxSet(hitboxSet)
    if not setHitboxes then return {} end

    local flModelScale = entity:GetPropFloat("m_flModelScale") or 1
    local bones = entity:SetupBones(0x7ff00, globals.CurTime())
    if not bones then return {} end

    local hitboxes = {}
    local hitboxList = setHitboxes:GetHitboxes()

    for _, hitbox in pairs(hitboxList) do
        local mat = bones[hitbox:GetBone()]
        if mat then
            local vecMins = hitbox:GetBBMin() * flModelScale
            local vecMaxs = hitbox:GetBBMax() * flModelScale

            -- Transform mins/maxs to world space (8 corners)
            local corners = {}
            -- ... matrix math to get world positions
            table.insert(hitboxes, corners)
        end
    end

    return hitboxes
end
```

### Notes

- Required for custom hitbox calculations
- Use with SetupBones to transform to world space
- See `custom.SetupBones` for full hitbox transform example

