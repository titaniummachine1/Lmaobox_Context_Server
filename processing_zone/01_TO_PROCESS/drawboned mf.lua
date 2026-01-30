-- Normalize a vector
local function NormalizeVector(vec)
    return vec / vec:Length()
end

-- Given forward,right,up vectors and world-space mins,maxs, compute all 8 corners.
local function ComputeHitboxCorners(forward, right, up, mins, maxs)
    -- Normalize axes to ensure they're unit vectors
    forward = NormalizeVector(forward)
    right   = NormalizeVector(right)
    up      = NormalizeVector(up)

    local center = (mins + maxs) * 0.5

    -- Project mins and maxs into local space defined by (forward, right, up)
    local minsLocal = {
        x = (mins - center):Dot(forward),
        y = (mins - center):Dot(right),
        z = (mins - center):Dot(up)
    }

    local maxsLocal = {
        x = (maxs - center):Dot(forward),
        y = (maxs - center):Dot(right),
        z = (maxs - center):Dot(up)
    }

    -- Ensure localMin < localMax for each axis
    local localMinX, localMaxX = math.min(minsLocal.x, maxsLocal.x), math.max(minsLocal.x, maxsLocal.x)
    local localMinY, localMaxY = math.min(minsLocal.y, maxsLocal.y), math.max(minsLocal.y, maxsLocal.y)
    local localMinZ, localMaxZ = math.min(minsLocal.z, maxsLocal.z), math.max(minsLocal.z, maxsLocal.z)

    -- Generate all 8 local corners
    local localCorners = {
        {x = localMinX, y = localMinY, z = localMinZ},
        {x = localMinX, y = localMinY, z = localMaxZ},
        {x = localMinX, y = localMaxY, z = localMinZ},
        {x = localMinX, y = localMaxY, z = localMaxZ},
        {x = localMaxX, y = localMinY, z = localMinZ},
        {x = localMaxX, y = localMinY, z = localMaxZ},
        {x = localMaxX, y = localMaxY, z = localMinZ},
        {x = localMaxX, y = localMaxY, z = localMaxZ}
    }

    -- Transform local corners back to world space
    local worldCorners = {}
    for i, lc in ipairs(localCorners) do
        worldCorners[i] = center + forward * lc.x + right * lc.y + up * lc.z
    end

    return worldCorners
end

local function DrawCornerLine(c1, c2, r, g, b, a)
    local s1 = client.WorldToScreen(c1)
    local s2 = client.WorldToScreen(c2)
    if s1 and s2 then
        draw.Color(r, g, b, a)
        draw.Line(s1[1], s1[2], s2[1], s2[2])
    end
end

callbacks.Register("Draw", function()
    local player = entities.GetLocalPlayer()
    if not player or not player:IsValid() then return end

    local boneMatrices = player:SetupBones()
    if not boneMatrices then return end

    -- Example: Using a specific bone index (like headBoneIndex = 6), adjust for your target bone.
    local headBoneIndex = 6
    local boneMatrix = boneMatrices[headBoneIndex]
    if not boneMatrix then return end

    -- Extract the bone axes from the bone matrix
    local forward = Vector3(boneMatrix[1][1], boneMatrix[2][1], boneMatrix[3][1])
    local right   = Vector3(boneMatrix[1][2], boneMatrix[2][2], boneMatrix[3][2])
    local up      = Vector3(boneMatrix[1][3], boneMatrix[2][3], boneMatrix[3][3])

    local hitboxes = player:GetHitboxes()
    if not hitboxes then return end

    for i, hitbox in ipairs(hitboxes) do
        local mins = hitbox[1]
        local maxs = hitbox[2]

        local corners = ComputeHitboxCorners(forward, right, up, mins, maxs)

        -- Define all edges of the box (12 edges)
        local edges = {
            {1,2}, {2,4}, {4,3}, {3,1},   -- Face 1
            {5,6}, {6,8}, {8,7}, {7,5},   -- Face 2
            {1,5}, {2,6}, {3,7}, {4,8}    -- Connecting edges
        }

        -- Draw all edges
        for _, edge in ipairs(edges) do
            DrawCornerLine(corners[edge[1]], corners[edge[2]], 255, 255, 0, 255)
        end
    end
end)
