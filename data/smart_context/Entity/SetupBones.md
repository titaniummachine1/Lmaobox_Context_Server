## Function/Symbol: Entity.SetupBones

> Setup entity bones for hitbox calculations

### Required Context

- Parameters: boneMask (optional, default 0x7FF00), currentTime (optional, default 0)
- Returns: table of Matrix3x4 (bone transforms, up to 128 entries)
- Use with: models.GetStudioModel to get hitboxes

### Curated Usage Examples

#### Get all hitboxes with SetupBones

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

            -- Transform to world space (8 corners of hitbox AABB)
            local x11 = mat[1][4] + vecMins.x * mat[1][1]
            local x12 = mat[2][4] + vecMins.x * mat[2][1]
            local x13 = mat[3][4] + vecMins.x * mat[3][1]

            local x21 = mat[1][4] + vecMaxs.x * mat[1][1]
            local x22 = mat[2][4] + vecMaxs.x * mat[2][1]
            local x23 = mat[3][4] + vecMaxs.x * mat[3][1]

            local y11 = vecMins.y * mat[1][2]
            local y12 = vecMins.y * mat[2][2]
            local y13 = vecMins.y * mat[3][2]

            local y21 = vecMaxs.y * mat[1][2]
            local y22 = vecMaxs.y * mat[2][2]
            local y23 = vecMaxs.y * mat[3][2]

            local z11 = vecMins.z * mat[1][3]
            local z12 = vecMins.z * mat[2][3]
            local z13 = vecMins.z * mat[3][3]

            local z21 = vecMaxs.z * mat[1][3]
            local z22 = vecMaxs.z * mat[2][3]
            local z23 = vecMaxs.z * mat[3][3]

            table.insert(hitboxes, {
                Vector3(x11 + y11 + z11, x12 + y12 + z12, x13 + y13 + z13),
                Vector3(x21 + y11 + z11, x22 + y12 + z12, x23 + y13 + z13),
                Vector3(x11 + y21 + z11, x12 + y22 + z12, x13 + y23 + z13),
                Vector3(x21 + y21 + z11, x22 + y22 + z12, x23 + y23 + z13),
                Vector3(x11 + y11 + z21, x12 + y12 + z22, x13 + y13 + z23),
                Vector3(x21 + y11 + z21, x22 + y12 + z22, x23 + y13 + z23),
                Vector3(x11 + y21 + z21, x12 + y22 + z22, x13 + y23 + z23),
                Vector3(x21 + y21 + z21, x22 + y22 + z22, x23 + y23 + z23),
            })
        end
    end

    return hitboxes
end
```

#### Draw hitboxes

```lua
local function DrawHitboxes(entity)
    local hitboxes = GetEntityHitboxes(entity)

    draw.Color(255, 0, 255, 255)
    for _, verts in pairs(hitboxes) do
        if #verts == 8 then
            local p = {}
            for i = 1, 8 do
                p[i] = client.WorldToScreen(verts[i])
            end

            if p[1] and p[2] and p[3] and p[4] and p[5] and p[6] and p[7] and p[8] then
                draw.Line(p[1][1], p[1][2], p[2][1], p[2][2])
                draw.Line(p[1][1], p[1][2], p[3][1], p[3][2])
                draw.Line(p[1][1], p[1][2], p[5][1], p[5][2])
                draw.Line(p[2][1], p[2][2], p[4][1], p[4][2])
                draw.Line(p[2][1], p[2][2], p[6][1], p[6][2])
                draw.Line(p[3][1], p[3][2], p[4][1], p[4][2])
                draw.Line(p[3][1], p[3][2], p[7][1], p[7][2])
                draw.Line(p[4][1], p[4][2], p[8][1], p[8][2])
                draw.Line(p[5][1], p[5][2], p[6][1], p[6][2])
                draw.Line(p[5][1], p[5][2], p[7][1], p[7][2])
                draw.Line(p[6][1], p[6][2], p[8][1], p[8][2])
                draw.Line(p[7][1], p[7][2], p[8][1], p[8][2])
            end
        end
    end
end
```

### Notes

- boneMask 0x7ff00 is full setup; adjust if you need partial
- Matrix3x4 format: [row][col], position is [1-3][4]
- Use with models.GetStudioModel to access hitbox data
- Transform mins/maxs by bone matrix to get world-space corners

