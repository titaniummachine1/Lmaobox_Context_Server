local function NormalizeVector(vec)
    return vec / vec:Length()
end

local function GetEdgeColor(c1, c2, forward, right, up)
    local dir = c2 - c1
    dir = NormalizeVector(dir)

    local fDot = math.abs(dir:Dot(forward))
    local rDot = math.abs(dir:Dot(right))
    local uDot = math.abs(dir:Dot(up))

    local maxDot = math.max(fDot, rDot, uDot)

    -- Determine which axis the edge aligns with
    if maxDot == fDot then
        return {r = 0, g = 255, b = 0, a = 255} -- Forward: Green
    elseif maxDot == rDot then
        return {r = 255, g = 0, b = 0, a = 255} -- Right: Red
    elseif maxDot == uDot then
        return {r = 0, g = 0, b = 255, a = 255} -- Up: Blue
    end

    -- Fallback (should never happen)
    return {r = 255, g = 255, b = 0, a = 255} -- Yellow
end

local function DrawCornerLine(c1, c2, forward, right, up)
    local screen1 = client.WorldToScreen(c1)
    local screen2 = client.WorldToScreen(c2)
    if screen1 and screen2 then
        local color = GetEdgeColor(c1, c2, forward, right, up)
        draw.Color(color.r, color.g, color.b, color.a)
        draw.Line(screen1[1], screen1[2], screen2[1], screen2[2])
    end
end

-- ComputeHitboxCorners function from previous code (unchanged)
local function ComputeHitboxCorners(forward, right, up, mins, maxs)
    -- Normalize axes
    forward = NormalizeVector(forward)
    right   = NormalizeVector(right)
    up      = NormalizeVector(up)

    local center = (mins + maxs) * 0.5

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

    local localMinX, localMaxX = math.min(minsLocal.x, maxsLocal.x), math.max(minsLocal.x, maxsLocal.x)
    local localMinY, localMaxY = math.min(minsLocal.y, maxsLocal.y), math.max(minsLocal.y, maxsLocal.y)
    local localMinZ, localMaxZ = math.min(minsLocal.z, maxsLocal.z), math.max(minsLocal.z, maxsLocal.z)

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

    local worldCorners = {}
    for i, lc in ipairs(localCorners) do
        worldCorners[i] = center + forward * lc.x + right * lc.y + up * lc.z
    end

    return worldCorners
end

callbacks.Register("Draw", function()
    local player = entities.GetLocalPlayer()
    if not player or not player:IsValid() then return end

    local boneMatrices = player:SetupBones()
    if not boneMatrices then return end

    -- Example: Use the head bone (index 6), adjust if needed
    local headBoneIndex = 6
    local boneMatrix = boneMatrices[headBoneIndex]
    if not boneMatrix then return end

    -- Extract raw axes
    local forward = Vector3(boneMatrix[1][1], boneMatrix[2][1], boneMatrix[3][1])
    local right   = Vector3(boneMatrix[1][2], boneMatrix[2][2], boneMatrix[3][2])
    local up      = Vector3(boneMatrix[1][3], boneMatrix[2][3], boneMatrix[3][3])

    local hitboxes = player:GetHitboxes()
    if not hitboxes then return end

    for i, hitbox in ipairs(hitboxes) do
        local mins = hitbox[1]
        local maxs = hitbox[2]
        local corners = ComputeHitboxCorners(forward, right, up, mins, maxs)

        local edges = {
            {1,2}, {2,4}, {4,3}, {3,1},   -- Face 1
            {5,6}, {6,8}, {8,7}, {7,5},   -- Face 2
            {1,5}, {2,6}, {3,7}, {4,8}    -- Connecting edges
        }

        for _, edge in ipairs(edges) do
            DrawCornerLine(corners[edge[1]], corners[edge[2]], forward, right, up)
        end
    end
end)
