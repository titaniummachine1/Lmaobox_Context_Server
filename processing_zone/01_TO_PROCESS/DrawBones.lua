local primaryFont = draw.CreateFont("Tahoma", 16, 800)
local fallbackFont = draw.CreateFont("Arial", 16, 800)

-- Try setting the primary font, fallback if it fails
local function setFont(font)
    local success, err = pcall(draw.SetFont, font)
    if not success then
        print("Failed to set primary font: " .. err)
        draw.SetFont(fallbackFont)
        print("Fallback font set to Arial.")
    end
end

setFont(primaryFont)

local function test()
    draw.Color(255, 255, 255, 255)
    local me = entities.GetLocalPlayer()
    
    -- Ensure 'me' is valid before proceeding
    if not me then
        print("Local player not found.")
        return
    end

    -- Find all players
    local players = {}
    local highestIndex = entities.GetHighestEntityIndex()
    for i = 1, highestIndex do
        local player = entities.GetByIndex(i)
        if player and player:IsPlayer() then
            table.insert(players, player)
        end
    end

    -- Iterate over each player
    for _, player in ipairs(players) do
        local model = player:GetModel()
        if model then
            local studioHdr = models.GetStudioModel(model)
            if studioHdr then
                local myHitBoxSet = player:GetPropInt("m_nHitboxSet")
                local hitboxSet = studioHdr:GetHitboxSet(myHitBoxSet)
                local hitboxes = hitboxSet:GetHitboxes()
                local boneMatrices = player:SetupBones()
                
                for i = 1, #hitboxes do
                    local hitbox = hitboxes[i]
                    local bone = hitbox:GetBone()
                    local boneMatrix = boneMatrices[bone]

                    if boneMatrix then
                        local bonePos = Vector3(boneMatrix[1][4], boneMatrix[2][4], boneMatrix[3][4])
                        local screenPos = client.WorldToScreen(bonePos)

                        if screenPos then
                            draw.Text(screenPos[1], screenPos[2], tostring(i))
                        end
                    end
                end
            end
        end
    end
end

callbacks.Register("Draw", "test", test)