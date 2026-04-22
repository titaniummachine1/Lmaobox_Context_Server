local HITGROUP_HEAD = 1
local BONE_USED_BY_ANYTHING = 0x7ff00

local EDGE_PAIRS = {
    { 1, 2 }, { 1, 3 }, { 1, 5 },
    { 2, 4 }, { 2, 6 },
    { 3, 4 }, { 3, 7 },
    { 4, 8 },
    { 5, 6 }, { 5, 7 },
    { 6, 8 },
    { 7, 8 },
}

local function get_head_hitbox_corners(entity)
    if not entity or not entity:IsValid() then return nil end
    if not entity:IsPlayer() or not entity:IsAlive() or entity:IsDormant() then return nil end

    local model = entity:GetModel()
    if not model then return nil end

    local studio_model = models.GetStudioModel(model)
    if not studio_model then return nil end

    local hitbox_set_index = entity:GetPropInt("m_nHitboxSet") or 0
    local hitbox_set = studio_model:GetHitboxSet(hitbox_set_index) or studio_model:GetHitboxSet(0)
    if not hitbox_set then return nil end

    local model_scale = entity:GetPropFloat("m_flModelScale") or 1
    local bones = entity:SetupBones(BONE_USED_BY_ANYTHING, globals.CurTime())
    if not bones then return nil end

    for _, hitbox in pairs(hitbox_set:GetHitboxes()) do
        if hitbox:GetGroup() == HITGROUP_HEAD or hitbox:GetName() == "head" then
            local bone_matrix = bones[hitbox:GetBone()]
            if not bone_matrix then return nil end

            local mins = hitbox:GetBBMin() * model_scale
            local maxs = hitbox:GetBBMax() * model_scale

            local x11 = bone_matrix[1][4] + mins.x * bone_matrix[1][1]
            local x12 = bone_matrix[2][4] + mins.x * bone_matrix[2][1]
            local x13 = bone_matrix[3][4] + mins.x * bone_matrix[3][1]

            local x21 = bone_matrix[1][4] + maxs.x * bone_matrix[1][1]
            local x22 = bone_matrix[2][4] + maxs.x * bone_matrix[2][1]
            local x23 = bone_matrix[3][4] + maxs.x * bone_matrix[3][1]

            local y11 = mins.y * bone_matrix[1][2]
            local y12 = mins.y * bone_matrix[2][2]
            local y13 = mins.y * bone_matrix[3][2]

            local y21 = maxs.y * bone_matrix[1][2]
            local y22 = maxs.y * bone_matrix[2][2]
            local y23 = maxs.y * bone_matrix[3][2]

            local z11 = mins.z * bone_matrix[1][3]
            local z12 = mins.z * bone_matrix[2][3]
            local z13 = mins.z * bone_matrix[3][3]

            local z21 = maxs.z * bone_matrix[1][3]
            local z22 = maxs.z * bone_matrix[2][3]
            local z23 = maxs.z * bone_matrix[3][3]

            return {
                Vector3(x11 + y11 + z11, x12 + y12 + z12, x13 + y13 + z13),
                Vector3(x21 + y11 + z11, x22 + y12 + z12, x23 + y13 + z13),
                Vector3(x11 + y21 + z11, x12 + y22 + z12, x13 + y23 + z13),
                Vector3(x21 + y21 + z11, x22 + y22 + z12, x23 + y23 + z13),
                Vector3(x11 + y11 + z21, x12 + y12 + z22, x13 + y13 + z23),
                Vector3(x21 + y11 + z21, x22 + y12 + z22, x23 + y13 + z23),
                Vector3(x11 + y21 + z21, x12 + y22 + z22, x13 + y23 + z23),
                Vector3(x21 + y21 + z21, x22 + y22 + z22, x23 + y23 + z23),
            }
        end
    end

    return nil
end

local function draw_head_box(entity)
    local corners = get_head_hitbox_corners(entity)
    if not corners then return end

    local screen_points = {}
    for i = 1, 8 do
        local screen = client.WorldToScreen(corners[i])
        if not screen then return end
        screen_points[i] = screen
    end

    draw.Color(255, 80, 80, 255)
    for _, edge in pairs(EDGE_PAIRS) do
        local a = screen_points[edge[1]]
        local b = screen_points[edge[2]]
        draw.Line(a[1], a[2], b[1], b[2])
    end
end

local function on_draw_head_hitbox_corners()
    local me = entities.GetLocalPlayer()
    if not me or not me:IsValid() or not me:IsAlive() then return end

    for _, player in pairs(entities.FindByClass("CTFPlayer")) do
        if player and player:IsValid() and player:IsAlive() and not player:IsDormant() then
            draw_head_box(player)
        end
    end
end

callbacks.Unregister("Draw", "prototype_head_hitbox_corners")
callbacks.Register("Draw", "prototype_head_hitbox_corners", on_draw_head_hitbox_corners)
