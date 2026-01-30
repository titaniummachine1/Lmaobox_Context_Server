-- Function to draw a line from a start position to an end position in a given color
local function DrawAxisLine(startPos, endPos, color)
    local screenStart = client.WorldToScreen(startPos)
    local screenEnd = client.WorldToScreen(endPos)

    if screenStart and screenEnd then
        draw.Color(color.r, color.g, color.b, color.a)
        draw.Line(screenStart[1], screenStart[2], screenEnd[1], screenEnd[2])
    end
end

callbacks.Register("Draw", function()
    local player = entities.GetLocalPlayer()
    if not player or not player:IsValid() then return end

    local boneMatrices = player:SetupBones()
    if not boneMatrices then return end

    -- Example: Use bone index 12 (adjust as needed)
    local boneIndex = 70
    local boneMatrix = boneMatrices[boneIndex]
    if not boneMatrix then return end

    -- Extract raw axes and position from the bone matrix (no normalization)
    local forward = Vector3(boneMatrix[1][1], boneMatrix[2][1], boneMatrix[3][1]) * 10
    local right   = Vector3(boneMatrix[1][2], boneMatrix[2][2], boneMatrix[3][2]) * 10
    local up      = Vector3(boneMatrix[1][3], boneMatrix[2][3], boneMatrix[3][3]) * 10
    local pos     = Vector3(boneMatrix[1][4], boneMatrix[2][4], boneMatrix[3][4])

    -- Draw the axes lines directly using the vectors' own lengths
    DrawAxisLine(pos, pos + forward, {r = 0, g = 255, b = 0, a = 255}) -- Forward = Green
    DrawAxisLine(pos, pos + right,   {r = 255, g = 0, b = 0, a = 255}) -- Right = Red
    DrawAxisLine(pos, pos + up,      {r = 0, g = 0, b = 255, a = 255}) -- Up = Blue
end)
