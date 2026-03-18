--[[ BuildBot - Crevice Detection ]] --

-- Load required libraries (adjust as needed for your environment)
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")

-- Constants for crevice detection
local FOV_MAX_DEGREES = 90          -- Total field of view angle (in degrees)
local MIN_ANGLE_PRECISION = 0.01    -- Minimum angle precision for binary search (degrees)
local TRACE_DISTANCE = 1000          -- Maximum trace distance (reduced from 2000 to 1000 for better performance)
local TRACE_MASK = MASK_SHOT_HULL
local CREVICE_DEPTH_THRESHOLD = 50  -- How much further a crevice must allow us to see (units)
local SCAN_RESOLUTION_INITIAL = 30  -- Initial scan resolution in degrees

-- User-friendly LIDAR configuration
local LIDAR_POINTS = 600            -- Number of points to use for LIDAR scan per full scan
local MAX_STORED_POINTS = 10000     -- Maximum number of LIDAR points to store before removing old ones
local scanResolution = FOV_MAX_DEGREES / (LIDAR_POINTS - 1) -- Calculate angle step based on desired points

local DEBUG_MODE = true             -- Set to true to show debug info

-- Status variables

local foundCrevices = {}
local traceHitPositions = {} -- Store hit positions for visualization
local tickCounter = 0        -- Counter for tick-based operations

-- Function to convert world coordinates to screen coordinates
local function WorldToScreen(pos)
    local screen = client.WorldToScreen(pos)
    if screen then
        return math.floor(screen[1]), math.floor(screen[2])
    end
    return nil, nil
end

-- Function to perform a trace that ignores players
local function TraceViewRay(startPos, direction, distance)
    local destination = startPos + direction * distance
    return engine.TraceLine(startPos, destination, TRACE_MASK)
end

-- Function to get the player's eye position
local function GetEyePosition(player)
    local origin = player:GetAbsOrigin()
    local viewOffset = player:GetPropVector("localdata", "m_vecViewOffset[0]")
    return origin + viewOffset
end

-- Function to calculate view angles to look at a specific point
local function CalculateViewAngles(eyePos, targetPos)
    local delta = {
        x = targetPos.x - eyePos.x,
        y = targetPos.y - eyePos.y,
        z = targetPos.z - eyePos.z
    }

    -- Calculate pitch and yaw using math.atan and manual 2D distance
    local dist2D = VectorDistance2D(eyePos, targetPos)
    local pitch = math.atan(delta.z / dist2D) * (180 / math.pi)
    local yaw = math.atan(delta.y / delta.x) * (180 / math.pi)

    -- Adjust yaw based on delta.x
    if delta.x >= 0 then
        yaw = yaw + 180
    end

    -- Handle NaN values
    if pitch ~= pitch then pitch = 0 end
    if yaw ~= yaw then yaw = 0 end

    return EulerAngles(pitch, yaw, 0)
end

-- Function to create a directional vector from angles
local function AngleToDirection(angles)
    local pitch = math.rad(angles.pitch)
    local yaw = math.rad(angles.yaw)

    local x = math.cos(yaw) * math.cos(pitch)
    local y = math.sin(yaw) * math.cos(pitch)
    local z = -math.sin(pitch)

    return Vector3(x, y, z)
end

-- Function to create a directional vector from angles (horizontal only, no pitch)
local function AngleToDirectionHorizontal(yaw)
    local yawRad = math.rad(yaw)
    
    -- Create vector with only horizontal direction (same height)
    local x = math.cos(yawRad)
    local y = math.sin(yawRad)
    local z = 0 -- Zero Z component for horizontal only
    
    return Vector3(x, y, z)
end

-- Function to normalize an angle to -180 to 180 range
local function NormalizeAngle(angle)
    while angle > 180 do angle = angle - 360 end
    while angle < -180 do angle = angle + 360 end
    return angle
end

-- Function to get the length between two Vector3 points
local function VectorDistance(vec1, vec2)
    local dx = vec1.x - vec2.x
    local dy = vec1.y - vec2.y
    local dz = vec1.z - vec2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Function to get the horizontal distance between two Vector3 points (ignoring Z)
local function VectorDistance2D(vec1, vec2)
    local dx = vec1.x - vec2.x
    local dy = vec1.y - vec2.y
    return math.sqrt(dx * dx + dy * dy)
end

-- Primary scan function that performs the initial sweep
local function PerformInitialScan(player)
    if not player or not player:IsAlive() then return {} end

    local eyePos = GetEyePosition(player)
    local currentViewAngles = engine.GetViewAngles()
    local baseYaw = currentViewAngles.yaw
    local basePitch = currentViewAngles.pitch

    local potentialCrevices = {}
    local prevDistance = 0

    -- Initial scan at regular intervals
    for angleOffset = -FOV_MAX_DEGREES / 2, FOV_MAX_DEGREES / 2, SCAN_RESOLUTION_INITIAL do
        local scanYaw = NormalizeAngle(baseYaw + angleOffset)
        local scanAngles = EulerAngles(basePitch, scanYaw, 0)
        local direction = AngleToDirection(scanAngles)

        local trace = TraceViewRay(eyePos, direction, TRACE_DISTANCE)
        local distance = VectorDistance(eyePos, trace.endpos)

        -- Print trace info if in debug mode
        if DEBUG_MODE and angleOffset % 20 == 0 then
            print(string.format("Scan at %d degrees: distance = %.2f", angleOffset, distance))
        end

        -- Look for significant positive changes in distance from previous angle
        if prevDistance > 0 and distance > prevDistance + CREVICE_DEPTH_THRESHOLD then
            table.insert(potentialCrevices, {
                startAngle = baseYaw + angleOffset - SCAN_RESOLUTION_INITIAL,
                endAngle = baseYaw + angleOffset,
                distance = distance,
                startDistance = prevDistance
            })

            if DEBUG_MODE then
                print(string.format("Potential crevice found at %.1f-%.1f degrees: %.1f -> %.1f",
                    angleOffset - SCAN_RESOLUTION_INITIAL, angleOffset, prevDistance, distance))
            end
            -- Look for significant negative changes (end of a crevice)
        elseif prevDistance > 0 and prevDistance > distance + CREVICE_DEPTH_THRESHOLD then
            -- Find if we have an open crevice to close
            for i, crevice in ipairs(potentialCrevices) do
                if not crevice.endAngle and crevice.startAngle < baseYaw + angleOffset - SCAN_RESOLUTION_INITIAL then
                    potentialCrevices[i].endAngle = baseYaw + angleOffset - SCAN_RESOLUTION_INITIAL

                    if DEBUG_MODE then
                        print(string.format("Crevice end found at %.1f degrees", angleOffset - SCAN_RESOLUTION_INITIAL))
                    end
                    break
                end
            end
        end

        prevDistance = distance
    end

    -- Filter out low-quality findings and close any open crevices
    local filteredCrevices = {}
    for _, crevice in ipairs(potentialCrevices) do
        if not crevice.endAngle then
            crevice.endAngle = baseYaw + FOV_MAX_DEGREES / 2
        end

        -- Only save crevices that are significant enough
        if crevice.distance > crevice.startDistance + CREVICE_DEPTH_THRESHOLD * 1.5 then
            table.insert(filteredCrevices, crevice)
        end
    end

    return filteredCrevices
end

-- Binary search function to refine a potential crevice
local function RefineCrevice(player, crevice)
    if not player or not player:IsAlive() then return crevice end

    local eyePos = GetEyePosition(player)
    local basePitch = engine.GetViewAngles().pitch

    -- Start with broad range
    local leftAngle = crevice.startAngle
    local rightAngle = crevice.endAngle

    -- Perform binary search to find the exact left edge
    while math.abs(rightAngle - leftAngle) > MIN_ANGLE_PRECISION do
        local midAngle = (leftAngle + rightAngle) / 2
        local scanAngles = EulerAngles(basePitch, midAngle, 0)
        local direction = AngleToDirection(scanAngles)

        local trace = TraceViewRay(eyePos, direction, TRACE_DISTANCE)
        local distance = VectorDistance(eyePos, trace.endpos)

        if DEBUG_MODE then
            print(string.format("Binary search at %.2f: distance = %.2f", midAngle, distance))
        end

        -- If we're in the crevice (longer distance)
        if distance > crevice.startDistance + CREVICE_DEPTH_THRESHOLD * 0.8 then
            rightAngle = midAngle -- Move left
        else
            leftAngle = midAngle  -- Move right
        end
    end

    -- The ideal angle is right at the edge of the crevice
    local optimalAngle = (leftAngle + rightAngle) / 2

    -- Final verification
    local verifyAngles = EulerAngles(basePitch, optimalAngle, 0)
    local direction = AngleToDirection(verifyAngles)
    local trace = TraceViewRay(eyePos, direction, TRACE_DISTANCE)
    local finalDistance = VectorDistance(eyePos, trace.endpos)

    -- Update crevice data
    crevice.refinedAngle = optimalAngle
    crevice.refinedDistance = finalDistance

    if DEBUG_MODE then
        print(string.format("Refined crevice angle to %.2f degrees - can see %.2f units",
            optimalAngle, finalDistance))
    end

    return crevice
end

-- Function to detect all crevices from current position
local function DetectCrevices()
    local player = entities.GetLocalPlayer()
    if not player or not player:IsAlive() then
        print("Player not valid for crevice detection")
        return {}
    end

    print("Starting crevice detection scan...")

    -- Perform initial scan
    local potentialCrevices = PerformInitialScan(player)

    if #potentialCrevices == 0 then
        print("No crevices found in the current view")
        return {}
    end

    print(string.format("Found %d potential crevices, refining...", #potentialCrevices))

    -- Refine each crevice with binary search
    local refinedCrevices = {}
    for i, crevice in ipairs(potentialCrevices) do
        local refined = RefineCrevice(player, crevice)
        table.insert(refinedCrevices, refined)
    end

    -- Sort by distance (furthest first)
    table.sort(refinedCrevices, function(a, b) return a.refinedDistance > b.refinedDistance end)

    return refinedCrevices
end

-- Function to look at the best crevice
local function LookAtBestCrevice(crevices)
    if #crevices == 0 then return false end

    local player = entities.GetLocalPlayer()
    if not player or not player:IsAlive() then return false end

    -- Get the crevice that lets us see furthest
    local bestCrevice = crevices[1]

    -- Look at it
    local basePitch = engine.GetViewAngles().pitch
    local bestAngles = EulerAngles(basePitch, bestCrevice.refinedAngle, 0)

    if DEBUG_MODE then
        print(string.format("Looking at best crevice: %.2f degrees (%.2f units visible)",
            bestCrevice.refinedAngle, bestCrevice.refinedDistance))
    end

    engine.SetViewAngles(bestAngles)
    return true
end

-- Real-time LIDAR scan function - true 3D cone implementation
local function PerformLidarScan()
    local player = entities.GetLocalPlayer()
    if not player or not player:IsAlive() then return end

    local eyePos = GetEyePosition(player)
    local currentViewAngles = engine.GetViewAngles()
    
    -- Generate random points in a full 3D cone
    local pointsPerScan = 15 -- How many points to add per tick
    for i = 1, pointsPerScan do
        -- Create random angle deviation within FOV
        local randomYawOffset = (math.random() * FOV_MAX_DEGREES) - (FOV_MAX_DEGREES / 2)
        local randomPitchOffset = (math.random() * FOV_MAX_DEGREES) - (FOV_MAX_DEGREES / 2)
        
        -- Apply random offsets to current view angles
        local scanYaw = NormalizeAngle(currentViewAngles.yaw + randomYawOffset)
        local scanPitch = NormalizeAngle(currentViewAngles.pitch + randomPitchOffset)
        
        -- Create full 3D direction vector
        local scanAngles = EulerAngles(scanPitch, scanYaw, 0)
        local direction = AngleToDirection(scanAngles)

        -- Perform trace
        local trace = TraceViewRay(eyePos, direction, TRACE_DISTANCE)
        local distance = VectorDistance(eyePos, trace.endpos)
        local hitPos = trace.endpos

        -- Store the hit position for visualization
        table.insert(traceHitPositions, {
            pos = hitPos,
            distance = distance,
            age = 0
        })
    end

    -- Remove oldest points when limit is exceeded
    if #traceHitPositions > MAX_STORED_POINTS then
        -- Just remove from the beginning of the table (oldest points)
        local newPositions = {}
        for i = (#traceHitPositions - MAX_STORED_POINTS + 1), #traceHitPositions do
            table.insert(newPositions, traceHitPositions[i])
        end
        traceHitPositions = newPositions
    end
end

-- Main callback for CreateMove - modified to run continuously
local function OnCreateMove(cmd)
    -- Increment tick counter
    tickCounter = tickCounter + 1
    
    -- Remove timer and run in real-time
    local player = entities.GetLocalPlayer()
    if not player or not player:IsAlive() then return end

    local eyePos = GetEyePosition(player)
    local viewAngles = engine.GetViewAngles()
    
    -- Get full 3D forward vector using player's actual view angles
    local forward = AngleToDirection(viewAngles)

    -- Perform continuous LIDAR scanning every tick
    PerformLidarScan()

    -- Only run crevice detection when close to a wall
    if tickCounter % 30 == 0 then -- Run less frequently
        local trace = TraceViewRay(eyePos, forward, TRACE_DISTANCE)
        local distance = VectorDistance(eyePos, trace.endpos)

        if distance < 300 then -- Only scan if we're close to a wall
            foundCrevices = DetectCrevices()

            -- Look at the best crevice if available
            if #foundCrevices > 0 and tickCounter % 50 == 0 then
                LookAtBestCrevice(foundCrevices)
            end
        else
            -- Clear crevices if we're not near a wall
            if #foundCrevices > 0 and DEBUG_MODE then
                print("No wall nearby, clearing crevice data")
            end
            foundCrevices = {}
        end
    end
end

-- Modified Drawing visualization with true LIDAR view in world space
local function DrawCreviceVisualization()
    if not DEBUG_MODE then return end

    -- Add info text for LIDAR
    draw.Color(255, 255, 255, 255)
    draw.Text(20, 80, string.format("LIDAR Points: %d/%d", #traceHitPositions, MAX_STORED_POINTS))
    draw.Text(20, 100, string.format("FOV: %.1f°", FOV_MAX_DEGREES))

    -- Skip radar elements and draw points directly in world space
    for i, hit in ipairs(traceHitPositions) do
        -- Convert world position to screen position
        local screenX, screenY = WorldToScreen(hit.pos)
        
        -- Only draw if point is on screen
        if screenX and screenY then
            -- Color based on distance with slight fade based on age
            local distanceFactor = math.min(hit.distance / TRACE_DISTANCE, 1.0)
            local r = math.floor(255 * (1 - distanceFactor))
            local g = math.floor(255 * distanceFactor)
            local b = math.floor(50 + 100 * distanceFactor)
            -- Fixed alpha calculation to ensure integer value
            local alpha = 255
            
            -- Size based on distance (smaller if further away)
            local size = math.max(1, math.floor(3 * (1 - distanceFactor * 0.7)))
            
            -- Draw dot representing hit position (using circles instead of rectangles)
            draw.ColoredCircle(screenX, screenY, size, r, g, b, alpha)
        end
    end
    
    -- Draw crevice info if available
    if #foundCrevices > 0 then
        draw.Color(0, 255, 0, 255)
        draw.Text(20, 20, string.format("Found %d crevices", #foundCrevices))
        draw.Text(20, 40, string.format("Best crevice at %.1f° (%.1f units)",
            NormalizeAngle(foundCrevices[1].refinedAngle - engine.GetViewAngles().yaw),
            foundCrevices[1].refinedDistance))
    end
end

-- Draw callback for visualization
local function OnDraw()
    DrawCreviceVisualization()
end

-- Initialize the bot
local function Initialize()
    print("BuildBot initialized - crevice detection ready")
    print(string.format("FOV: ±%.1f degrees, Precision: %.2f degrees", FOV_MAX_DEGREES / 2, MIN_ANGLE_PRECISION))

    -- Register callbacks
    callbacks.Register("CreateMove", "BuildBot.CreviceDetection", OnCreateMove)
    callbacks.Register("Draw", "BuildBot.Visualization", OnDraw)

    -- Perform initial detection
    foundCrevices = DetectCrevices()
    if #foundCrevices > 0 then
        print(string.format("Initial scan found %d crevices", #foundCrevices))
        LookAtBestCrevice(foundCrevices)
    end
end

-- Execute initialization when script is loaded
Initialize()
