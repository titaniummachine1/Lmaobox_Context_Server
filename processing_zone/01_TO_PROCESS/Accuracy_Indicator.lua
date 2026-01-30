-- Import necessary Lmaobox libraries
local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 1, "LNXlib version is too old, please update it!")
local Fonts = Lib.UI.Fonts
local Input = Lib.Utils.Input
local Math = Lib.Utils.Math
local WPlayer = Lib.TF2.WPlayer

local plocal = nil

-- Table to store player accuracy data
local playerAccuracy = {}

-- Helper function to get the SteamID of a player
local function getSteamID(player)
    local playerInfo = client.GetPlayerInfo(player:GetIndex())
    return playerInfo.SteamID
end

-- Function to initialize player accuracy data
local function initializePlayerAccuracy(player)
    local steamID = getSteamID(player)
    if not playerAccuracy[steamID] then
        playerAccuracy[steamID] = {shots = {}}
    end
end

local accuracy = 0
local dragPosition = { x = 10, y = 200 }
local isDragging = false

-- Function to update and print player accuracy
local function updateAndPrintAccuracy(player)
    local steamID = getSteamID(player)
    local accuracyData = playerAccuracy[steamID]
    local currentTick = globals.TickCount()

    -- Clean up old shots
    local validShots = {}
    for _, shot in ipairs(accuracyData.shots) do
        if currentTick - shot.tick <= 60 * 66 then -- 1 minute
            table.insert(validShots, shot)
        end
    end
    accuracyData.shots = validShots

    -- Calculate accuracy percentage
    local shotsFired = #accuracyData.shots
    local shotsHit = 0
    for _, shot in ipairs(accuracyData.shots) do
        if shot.hit then
            shotsHit = shotsHit + 1
        end
    end

    accuracy = 0
    if shotsFired > 0 then
        accuracy = (shotsHit / shotsFired) * 100
    end
end

local lastAmmoCount = {}
local tick_count = 0

-- Function to detect if the player has fired a shot
local function hasPlayerFired(cmd)
    if not plocal then error("plocal is nil") return end
    local weapon = plocal:GetPropEntity("m_hActiveWeapon")
    if not weapon then return false end

    local weaponIndex = weapon:GetIndex()
    local weaponType = weapon:GetWeaponID()

    -- Get current ammo count
    local ammoCount = weapon:GetPropInt("LocalWeaponData", "m_iClip1")

    if ammoCount == (nil or -1) then --when we dont have any clip
        local ammoTable = plocal:GetPropDataTableInt("localdata", "m_iAmmo")
        ammoCount = (ammoTable and ammoTable[2]) or -1 -- Use primary ammo type for Minigun
    end

    local lastAttackTick = weapon:GetPropFloat("LocalActiveWeaponData", "m_flLastPrimaryAttack")
    if lastAttackTick == nil then
        lastAttackTick = 0
    end

    if not lastAmmoCount[weaponIndex] then
        lastAmmoCount[weaponIndex] = ammoCount
    end

    if ammoCount < lastAmmoCount[weaponIndex] or ((cmd.buttons & IN_ATTACK) ~= 0 and lastAttackTick > tick_count - 1) then
        lastAmmoCount[weaponIndex] = ammoCount
        return true
    end

    lastAmmoCount[weaponIndex] = ammoCount
    return false
end

local function getBestTarget(customFOV)
    local plocal1 = WPlayer.GetLocal()
    if not plocal1 then return end

    local players = entities.FindByClass("CTFPlayer")
    local target = nil
    local lastFov = math.huge

    for _, entity in pairs(players) do
        if not entity then goto continue end
        if not entity:IsAlive() then goto continue end
        if entity:GetTeamNumber() == plocal1:GetTeamNumber() then goto continue end

        local player = WPlayer.FromEntity(entity)
        local aimPos = player:GetHitboxPos(1)
        local angles = Math.PositionAngles(plocal1:GetEyePos(), aimPos)
        local fov = Math.AngleFov(angles, engine.GetViewAngles())
        if fov > (customFOV or 60) then goto continue end

        if fov < lastFov then
            lastFov = fov
            target = { entity = entity, pos = aimPos, angles = angles, factor = fov }
        end

        ::continue::
    end

    return target
end

-- Callback function for player hurt
local function onPlayerHurt(event)
    if event:GetName() == 'player_hurt' then
        local attacker = entities.GetByUserID(event:GetInt("attacker"))
        local victim = entities.GetByUserID(event:GetInt("userid"))
        if attacker and attacker == plocal then
            local steamID = getSteamID(attacker)
            initializePlayerAccuracy(attacker)
            local accuracyData = playerAccuracy[steamID]

            -- Find the most recent shot and mark it as a hit
            for i = #accuracyData.shots, 1, -1 do
                if not accuracyData.shots[i].hit then
                    accuracyData.shots[i].hit = true
                    break
                end
            end

            updateAndPrintAccuracy(attacker)
        end
    end
end

-- Callback function for create move
local function createMove(cmd)
    plocal = entities.GetLocalPlayer()
    if not plocal or not plocal:IsAlive() then return end

    tick_count = globals.TickCount()

    if hasPlayerFired(cmd) then
        local bestTarget = getBestTarget(60)
        if bestTarget then
            local steamID = getSteamID(plocal)
            initializePlayerAccuracy(plocal)
            local accuracyData = playerAccuracy[steamID]

            -- Add a new shot entry
            table.insert(accuracyData.shots, {tick = tick_count, hit = false})
        end
    end
end

local dragPosition = { x = 10, y = 200 }
local isDragging = false
local accuracyTitle = "Accuracy"

-- Drawing function
local function doDraw()
    -- Dragging logic
    if input.IsButtonDown(MOUSE_LEFT) and Input.MouseInBounds(dragPosition.x, dragPosition.y, dragPosition.x + 150, dragPosition.y + 25) then
        isDragging = true
    end

    if not input.IsButtonDown(MOUSE_LEFT) then
        isDragging = false
    end

    if isDragging then
        local mouse2d = input.GetMousePos()
        dragPosition.x = math.floor(mouse2d[1] - 75)
        dragPosition.y = math.floor(mouse2d[2] - 12.5)
    end

    -- Drawing the background if the console or game UI is visible
    draw.SetFont(Fonts.Verdana)
    local textWidth, textHeight = draw.GetTextSize(accuracyTitle)
    local boxWidth = math.floor(textWidth + 80)
    local boxHeight = math.floor(textHeight + 10)

    if engine.Con_IsVisible() or engine.IsGameUIVisible() then
        draw.Color(0, 0, 0, 150)
        draw.FilledRect(dragPosition.x - 5, dragPosition.y - 5, dragPosition.x + boxWidth + 5, dragPosition.y + boxHeight + 5)
    end

    -- Draw the background
    draw.Color(0, 0, 0, 150)
    draw.FilledRect(dragPosition.x, dragPosition.y, dragPosition.x + boxWidth, dragPosition.y + boxHeight)

    -- Draw the outline
    draw.Color(255, 255, 255, 255)
    draw.OutlinedRect(dragPosition.x, dragPosition.y, dragPosition.x + boxWidth, dragPosition.y + boxHeight)

    -- Update accuracy value
    local steamID = getSteamID(plocal)
    if playerAccuracy[steamID] then
        local accuracyData = playerAccuracy[steamID]
        local shotsFired = #accuracyData.shots
        local shotsHit = 0
        for _, shot in ipairs(accuracyData.shots) do
            if shot.hit then
                shotsHit = shotsHit + 1
            end
        end
        if shotsFired > 0 then
            accuracy = (shotsHit / shotsFired) * 100
        else
            accuracy = 0
        end
    end

    -- Draw the accuracy text
    draw.Color(255, 255, 255, 255)
    draw.Text(math.floor(dragPosition.x + 5), math.floor(dragPosition.y + 5), accuracyTitle)
    draw.Text(math.floor(dragPosition.x + 5 + textWidth + 10), math.floor(dragPosition.y + 5), string.format("%.2f", accuracy) .. "%")
end

-- Register callback functions
callbacks.Unregister("CreateMove", "AccuracyTracker.CreateMove")
callbacks.Unregister("FireGameEvent", "AccuracyTracker.FireGameEvent")
callbacks.Unregister("Draw", "AccuracyTracker.Draw")

callbacks.Register("CreateMove", "AccuracyTracker.CreateMove", createMove)
callbacks.Register("FireGameEvent", "AccuracyTracker.FireGameEvent", onPlayerHurt)
callbacks.Register("Draw", "AccuracyTracker.Draw", doDraw)

client.ChatPrintf("Accuracy tracker loaded!")
