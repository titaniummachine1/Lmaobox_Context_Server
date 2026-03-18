local function extractTransformFromMatrix(boneMatrix)
    local rotMat = {
        {boneMatrix[1][1], boneMatrix[1][2], boneMatrix[1][3]},
        {boneMatrix[2][1], boneMatrix[2][2], boneMatrix[2][3]},
        {boneMatrix[3][1], boneMatrix[3][2], boneMatrix[3][3]}
    }
    local position = Vector3(boneMatrix[1][4], boneMatrix[2][4], boneMatrix[3][4])
    local forward = Vector3(rotMat[1][3], rotMat[2][3], rotMat[3][3])

    return {position = position, forward = forward, rotMat = rotMat}
end

local function rotatePoint(point, rotMat)
    local x = point.x * rotMat[1][1] + point.y * rotMat[1][2] + point.z * rotMat[1][3]
    local y = point.x * rotMat[2][1] + point.y * rotMat[2][2] + point.z * rotMat[2][3]
    local z = point.x * rotMat[3][1] + point.y * rotMat[3][2] + point.z * rotMat[3][3]
    return Vector3(x, y, z)
end

local function calculateOtherCorners(min, max, rotMat)
    local size = max - min
    local corners = {
        min,  -- Keep min corner as is
        Vector3(max.x, min.y, min.z),
        Vector3(min.x, max.y, min.z),
        Vector3(max.x, max.y, min.z),
        Vector3(min.x, min.y, max.z),
        Vector3(max.x, min.y, max.z),
        Vector3(min.x, max.y, max.z),
        max   -- Keep max corner as is
    }

    for i, corner in ipairs(corners) do
        if corner ~= min and corner ~= max then
            local localCorner = corner - min
            corners[i] = rotatePoint(localCorner, rotMat) + min
        end
    end

    return corners
end

local function getAllRotatedHitboxCorners(entity)
    local bones = entity:SetupBones()
    local hitboxes = entity:GetHitboxes()
    local hitboxTable = {}

    for hitboxIndex, hitbox in ipairs(hitboxes) do
        local boneData = bones[hitboxIndex] or bones[#bones]
        local transform = extractTransformFromMatrix(boneData)

        if hitbox[1] and hitbox[2] then
            local corners = calculateOtherCorners(hitbox[1], hitbox[2], transform.rotMat)
            hitboxTable[hitboxIndex] = {
                min = hitbox[1],
                max = hitbox[2],
                position = transform.position,
                forward = transform.forward,
                corners = corners
            }
        end
    end

    return hitboxTable
end

local function drawHitbox(corners)
    local edges = {
        {1, 2}, {2, 4}, {4, 3}, {3, 1},  -- Bottom face
        {5, 6}, {6, 8}, {8, 7}, {7, 5},  -- Top face
        {1, 5}, {2, 6}, {3, 7}, {4, 8}   -- Connecting edges
    }

    for _, edge in ipairs(edges) do
        local start = corners[edge[1]]
        local finish = corners[edge[2]]
        local startScreen = client.WorldToScreen(start)
        local finishScreen = client.WorldToScreen(finish)

        if startScreen and finishScreen then
            draw.Line(startScreen[1], startScreen[2], finishScreen[1], finishScreen[2])
        end
    end
end

local function doDraw()
    draw.Color(255, 255, 255, 255)
    local pLocal = entities.GetLocalPlayer()
    if not pLocal then return end

    local hitboxData = getAllRotatedHitboxCorners(pLocal)
    local lineLength = 10

    for _, hitbox in ipairs(hitboxData) do
        local forward = hitbox.forward
        local hitboxPos = hitbox.position

        drawHitbox(hitbox.corners)

        local endPoint = Vector3(
            hitboxPos.x + forward.x * lineLength,
            hitboxPos.y + forward.y * lineLength,
            hitboxPos.z + forward.z * lineLength
        )

        local screenStart, screenEnd = client.WorldToScreen(hitboxPos), client.WorldToScreen(endPoint)

        if screenStart and screenEnd then
            draw.Color(0, 255, 255, 255)
            draw.Line(screenStart[1], screenStart[2], screenEnd[1], screenEnd[2])
        end
    end
end

callbacks.Unregister("Draw", "AMVisuals_Draw")
callbacks.Register("Draw", "AMVisuals_Draw", doDraw)

print("Optimized hitbox drawing script loaded and registered.")
