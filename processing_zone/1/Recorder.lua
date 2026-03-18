--[[ Movement Recorder ]] --
--[[Credits to:lnx for lnxlib,menu and the base of the recorder]]

-- Script identifier for configuration file
local Lua__fileName = "Recorder"

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.965, "lnxLib version is too old, please update it!")

local Fonts = lnxLib.UI.Fonts

---@type boolean, ImMenu
local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")

-- Add a variable to control position accuracy threshold
local positionAccuracyThreshold = 0.1 -- Lower = more accurate position matching

-- Constants for position correction
local PLAYBACK_POSITION_THRESHOLD = 2     -- Maximum allowed distance deviation during playback
local MAX_CORRECTION_VELOCITY = 25.0      -- Only correct position when velocity is below this value
local EMERGENCY_POSITION_THRESHOLD = 50.0 -- Threshold for extreme deviation requiring correction regardless of velocity

-- Constants for view angle tracing
local USE_VIEW_TRACE_CORRECTION = true -- Enable view trace correction for more accurate aiming
local TRACE_DISTANCE = 8192            -- Maximum trace distance for view rays
local VIEW_TRACE_MASK = 0x1B           -- MASK_SHOT (0x13) | CONTENTS_GRATE (0x8)
local TRACE_FRACTION_THRESHOLD = 0.99  -- If we can see this much of the trace, consider it visible

-- Constants for crevice search
local SEARCH_FOV = 60           -- Default horizontal FOV range (total angle to search)
local SEARCH_STEP_SIZE = 0.5    -- How precise the search should be (smaller = more precise)
local SEARCH_MAX_ITERATIONS = 20 -- Maximum number of iterations for the search
local SEARCH_DISTANCE = 8192    -- Maximum trace distance for the search

-- State machine constants
local STATE = {
    IDLE = 0,
    RECORDING = 1,
    PLAYBACK_PREPARE = 2,
    PLAYBACK_ACTIVE = 3
}

-- Constants for minimum and maximum speed
local MAX_SPEED = 450 -- Maximum speed the player can move

-- Settings
local doRepeat = false
local doViewAngles = true
local debugMode = false               -- Enable debug printing

-- Add customizable accuracy thresholds based on velocity
local ACCURACY_THRESHOLD_HIGH_SPEED = 50.0 -- Normal threshold when velocity > 50
local ACCURACY_THRESHOLD_MED_SPEED = 2.0   -- Medium threshold when velocity < 50
local ACCURACY_THRESHOLD_LOW_SPEED = 0.1   -- Precise threshold when velocity < 2

-- Recorder settings for configuration - moved to the top to avoid nil reference
local RecorderSettings = {
    defaultSettings = {
        doRepeat = doRepeat,
        doViewAngles = doViewAngles,
        debugMode = debugMode,
        PLAYBACK_POSITION_THRESHOLD = PLAYBACK_POSITION_THRESHOLD,
        MAX_CORRECTION_VELOCITY = MAX_CORRECTION_VELOCITY,
        EMERGENCY_POSITION_THRESHOLD = EMERGENCY_POSITION_THRESHOLD,
        ACCURACY_THRESHOLD_HIGH_SPEED = ACCURACY_THRESHOLD_HIGH_SPEED,
        ACCURACY_THRESHOLD_MED_SPEED = ACCURACY_THRESHOLD_MED_SPEED,
        ACCURACY_THRESHOLD_LOW_SPEED = ACCURACY_THRESHOLD_LOW_SPEED
    },
    recordings = {}
}

-- Debug print function to show more information
local function DebugPrint(message)
    if debugMode then
        print("[Recorder Debug] " .. message)
    end
end

-- Function to directly execute slot command
local function ExecuteSlotCommand(slot)
    if slot and slot >= 1 and slot <= 5 then
        local slotCmd = "slot" .. slot
        DebugPrint("Executing weapon command: " .. slotCmd)

        -- Direct command without spaces
        client.Command(slotCmd, true)
    end
end

-- Function to compute the move direction
local function ComputeMove(pCmd, a, b)
    local diff = (b - a)
    if diff:Length() == 0 then return Vector3(0, 0, 0) end

    local x = diff.x
    local y = diff.y
    local vSilent = Vector3(x, y, 0)

    local ang = vSilent:Angles()
    local cPitch, cYaw, cRoll = pCmd:GetViewAngles()
    local yaw = math.rad(ang.y - cYaw)
    local pitch = math.rad(ang.x - cPitch)
    local move = Vector3(math.cos(yaw) * MAX_SPEED, -math.sin(yaw) * MAX_SPEED, -math.cos(pitch) * MAX_SPEED)

    return move
end

-- Function to make the player walk to a destination smoothly
local function WalkTo(pCmd, pLocal, pDestination)
    local localPos = pLocal:GetAbsOrigin()
    local distVector = pDestination - localPos
    local dist = distVector:Length()
    local velocity = pLocal:EstimateAbsVelocity():Length()

    -- If distance is greater than 1, proceed with walking
    if dist > 1 then
        local result = ComputeMove(pCmd, localPos, pDestination)
        -- If distance is less than 10, scale down the speed further
        if dist < 10 + velocity then
            local scaleFactor = dist / 100
            pCmd:SetForwardMove(result.x * scaleFactor)
            pCmd:SetSideMove(result.y * scaleFactor)
        else
            pCmd:SetForwardMove(result.x)
            pCmd:SetSideMove(result.y)
        end
    end
end

-- Function to get the player's eye position
local function GetEyePosition(pLocal)
    local origin = pLocal:GetAbsOrigin()
    local viewOffset = pLocal:GetPropVector("localdata", "m_vecViewOffset[0]")
    return origin + viewOffset
end

-- Function to calculate view angles to look at a specific point
local function CalculateViewAngles(eyePos, targetPos)
    local delta = eyePos - targetPos

    -- Calculate pitch and yaw using math.atan
    local pitch = math.atan(delta.z / delta:Length2D()) * (180 / math.pi)
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


-- Module state
local currentState = STATE.IDLE
local currentTick = 0
local currentData = {}
local currentSize = 1
local setuptimer = 128
local weaponSelectionAttempts = 0     -- Track weapon selection attempts
local maxWeaponSelectionAttempts = 10 -- Maximum attempts to select weapon

-- Default values for each field to save memory
local DEFAULT_VALUES = {
    forwardMove = 0,
    sideMove = 0,
    upMove = 0,
    buttons = 0,
    impulse = 0,
    weaponselect = 0,
    weaponsubtype = 0
}

-- Function to store only non-default values to save memory
local function StoreTickData(tickIndex, data)
    -- Create a new table for this tick if it doesn't exist
    if not currentData[tickIndex] then
        currentData[tickIndex] = {}
    end

    -- Only store values that differ from defaults
    if data.viewAngles then
        currentData[tickIndex].viewAngles = data.viewAngles
    end

    if data.traceEndpoint then
        currentData[tickIndex].traceEndpoint = data.traceEndpoint
    end

    if data.position then
        currentData[tickIndex].position = data.position
    end

    if data.forwardMove and data.forwardMove ~= DEFAULT_VALUES.forwardMove then
        currentData[tickIndex].forwardMove = data.forwardMove
    end

    if data.sideMove and data.sideMove ~= DEFAULT_VALUES.sideMove then
        currentData[tickIndex].sideMove = data.sideMove
    end

    if data.upMove and data.upMove ~= DEFAULT_VALUES.upMove then
        currentData[tickIndex].upMove = data.upMove
    end

    if data.buttons and data.buttons ~= DEFAULT_VALUES.buttons then
        currentData[tickIndex].buttons = data.buttons
    end

    if data.impulse and data.impulse ~= DEFAULT_VALUES.impulse then
        currentData[tickIndex].impulse = data.impulse
    end

    if data.weaponselect and data.weaponselect ~= DEFAULT_VALUES.weaponselect then
        currentData[tickIndex].weaponselect = data.weaponselect
    end

    if data.weaponsubtype and data.weaponsubtype ~= DEFAULT_VALUES.weaponsubtype then
        currentData[tickIndex].weaponsubtype = data.weaponsubtype
    end

    if data.weaponSlot then
        currentData[tickIndex].weaponSlot = data.weaponSlot
    end
end

-- Function to get value with fallback to default
local function GetValueOrDefault(tickData, field)
    if tickData and tickData[field] ~= nil then
        return tickData[field]
    end
    return DEFAULT_VALUES[field] or 0 -- Fallback to 0 if no default is defined
end

-- Function to capture current user state
local function CaptureInitialState(pLocal, userCmd)
    local yaw, pitch, roll = userCmd:GetViewAngles()

    -- Get the active weapon and determine slot more accurately
    local activeWeapon = pLocal:GetPropEntity("m_hActiveWeapon")
    local weaponSlot = 1 -- Default to primary

    if activeWeapon then
        -- Check which slot the weapon is in
        local primaryWeapon = pLocal:GetEntityForLoadoutSlot(0)
        local secondaryWeapon = pLocal:GetEntityForLoadoutSlot(1)
        local meleeWeapon = pLocal:GetEntityForLoadoutSlot(2)

        if primaryWeapon and activeWeapon:GetIndex() == primaryWeapon:GetIndex() then
            weaponSlot = 1
        elseif secondaryWeapon and activeWeapon:GetIndex() == secondaryWeapon:GetIndex() then
            weaponSlot = 2
        elseif meleeWeapon and activeWeapon:GetIndex() == meleeWeapon:GetIndex() then
            weaponSlot = 3
        else
            -- Try to determine from weapon class
            local weaponClass = activeWeapon:GetClass()
            if weaponClass:find("Primary") then
                weaponSlot = 1
            elseif weaponClass:find("Secondary") then
                weaponSlot = 2
            elseif weaponClass:find("Melee") then
                weaponSlot = 3
            elseif weaponClass:find("PDA") or weaponClass:find("Builder") then
                weaponSlot = 4
            elseif weaponClass:find("Destruction") then
                weaponSlot = 5
            end

            -- Store the actual weaponselect from userCmd as a backup
            if userCmd.weaponselect and userCmd.weaponselect > 0 and userCmd.weaponselect <= 5 then
                DebugPrint("Using weaponselect from UserCmd: " .. userCmd.weaponselect)
                weaponSlot = userCmd.weaponselect
            end
        end

        DebugPrint("Captured weapon in slot " .. weaponSlot)
    end

    -- Create initial state data with only non-default values
    local initialData = {
        viewAngles = EulerAngles(yaw, pitch, roll),
        position = pLocal:GetAbsOrigin(),
        weaponSlot = weaponSlot
    }

    -- Only add non-default values
    if userCmd.weaponselect and userCmd.weaponselect ~= DEFAULT_VALUES.weaponselect then
        initialData.weaponselect = userCmd.weaponselect
    end

    if userCmd.weaponsubtype and userCmd.weaponsubtype ~= DEFAULT_VALUES.weaponsubtype then
        initialData.weaponsubtype = userCmd.weaponsubtype
    end

    local buttons = userCmd:GetButtons()
    if buttons ~= DEFAULT_VALUES.buttons then
        initialData.buttons = buttons
    end

    if userCmd.impulse and userCmd.impulse ~= DEFAULT_VALUES.impulse then
        initialData.impulse = userCmd.impulse
    end

    -- Store the initial state in the data table
    StoreTickData(0, initialData)

    DebugPrint("Initial state captured, weapon slot: " .. weaponSlot)
    return currentData[0]
end

-- Function to determine if an entity should be ignored in trace checks
local function ShouldIgnoreEntity(entity)
    if entity == nil then
        return false
    end

    -- Get entity class
    local entityClass = entity:GetClass()

    -- Add more entity types to ignore as needed
    local ignoreClasses = {
        "CTFPlayer",
    }

    for _, ignoreClass in ipairs(ignoreClasses) do
        if entityClass == ignoreClass then
            return true
        end
    end

    return false
end

-- Function to perform a trace that ignores players
local function TraceViewRay(eyePos, direction, distance)
    local destination = eyePos + direction * distance
    local trace = engine.TraceLine(eyePos, destination, MASK_SHOT_BRUSHONLY)

    -- Check if we hit a player or dynamic entity we should ignore
    if trace.entity ~= nil and ShouldIgnoreEntity(trace.entity) then
        -- If we hit an entity we should ignore, perform another trace from slightly past that point
        local newStart = trace.endpos + direction * 1 -- Start just past the ignored entity
        local newTrace = engine.TraceLine(newStart, destination, VIEW_TRACE_MASK)

        -- Combine the traces
        newTrace.startpos = eyePos
        return newTrace
    end

    -- Debug info about what we're looking at
    if trace.entity ~= nil and debugMode then
        DebugPrint("Looking at: " .. trace.entity:GetClass() .. ", fraction: " .. trace.fraction)
    end

    return trace
end

-- Function to apply state from a tick
local function ApplyState(userCmd, tickData)
    if not tickData then return false end

    -- Apply view angles with enhanced trace correction
    if tickData.viewAngles then
        if USE_VIEW_TRACE_CORRECTION and tickData.viewTarget then
            local pLocal = entities.GetLocalPlayer()
            if pLocal and pLocal:IsAlive() then
                local eyePos = pLocal:GetAbsOrigin() + pLocal:GetPropVector("localdata", "m_vecViewOffset[0]");

                -- For world targets, check if we can see the target point
                local canSeeTarget = false
                if tickData.isWorldTarget then
                    local direction = (tickData.viewTarget - eyePos):Normalize()
                    local trace = TraceViewRay(eyePos, direction, TRACE_DISTANCE)

                    -- Check if we can see close to the same point
                    local targetDistance = (tickData.viewTarget - eyePos):Length()
                    local traceDistance = (trace.endpos - eyePos):Length()
                    local distanceRatio = traceDistance / targetDistance

                    canSeeTarget = (distanceRatio > TRACE_FRACTION_THRESHOLD)

                    if debugMode and currentTick % 33 == 0 then
                        DebugPrint("Target visibility check: " .. (canSeeTarget and "VISIBLE" or "BLOCKED") ..
                            ", ratio=" .. string.format("%.2f", distanceRatio))
                    end
                end

                -- Calculate and apply view angles
                local correctedViewAngles = CalculateViewAngles(eyePos, tickData.viewTarget)
                userCmd:SetViewAngles(correctedViewAngles:Unpack())
                if doViewAngles then
                    engine.SetViewAngles(correctedViewAngles)
                end

                -- If this is a world target and we can't see it, mark for position correction
                if tickData.isWorldTarget and not canSeeTarget then
                    tickData._needsPositionCorrection = true
                    if debugMode and currentTick % 33 == 0 then
                        DebugPrint("Target blocked, marking for position correction")
                    end
                end

                if debugMode and currentTick % 33 == 0 then
                    DebugPrint("Applied trace-corrected view angles to target")
                end
            else
                -- Fallback to recorded angles if player isn't valid
                userCmd:SetViewAngles(tickData.viewAngles:Unpack())
                if doViewAngles then
                    engine.SetViewAngles(tickData.viewAngles)
                end
            end
        else
            -- Use original recorded angles
            userCmd:SetViewAngles(tickData.viewAngles:Unpack())
            if doViewAngles then
                engine.SetViewAngles(tickData.viewAngles)
            end
        end
    end

    local weaponselect = GetValueOrDefault(tickData, "weaponselect")
    if weaponselect ~= DEFAULT_VALUES.weaponselect then
        DebugPrint("Setting userCmd.weaponselect to " .. weaponselect)
        userCmd.weaponselect = weaponselect
    end

    local weaponsubtype = GetValueOrDefault(tickData, "weaponsubtype")
    if weaponsubtype ~= DEFAULT_VALUES.weaponsubtype then
        DebugPrint("Setting userCmd.weaponsubtype to " .. weaponsubtype)
        userCmd.weaponsubtype = weaponsubtype
    end

    local buttons = GetValueOrDefault(tickData, "buttons")
    if buttons ~= DEFAULT_VALUES.buttons then
        DebugPrint("Setting userCmd buttons to " .. buttons)
        userCmd:SetButtons(buttons)
    else
        userCmd:SetButtons(0) -- Set default buttons if not specified
    end

    local impulse = GetValueOrDefault(tickData, "impulse")
    if impulse ~= DEFAULT_VALUES.impulse then
        DebugPrint("Setting userCmd.impulse to " .. impulse)
        userCmd.impulse = impulse
    else
        userCmd.impulse = 0 -- Set default impulse if not specified
    end

    -- Set movement values with defaults
    userCmd:SetForwardMove(GetValueOrDefault(tickData, "forwardMove"))
    userCmd:SetSideMove(GetValueOrDefault(tickData, "sideMove"))
    userCmd:SetUpMove(GetValueOrDefault(tickData, "upMove"))

    -- Always apply weapon selection with better debugging
    if tickData.weaponSlot then
        DebugPrint("Applying weapon slot " .. tickData.weaponSlot)
        ExecuteSlotCommand(tickData.weaponSlot)
    end

    return true
end

-- Function to start recording
local function StartRecording()
    DebugPrint("Starting recording")
    currentState = STATE.RECORDING
    currentTick = 1 -- Start at 1 since 0 will be the initial state
    currentData = {}
    currentSize = 1
    weaponSelectionAttempts = 0
end

-- Function to stop recording and prepare for playback
local function StopRecording()
    DebugPrint("Stopping recording")
    currentState = STATE.IDLE
    currentTick = 0
    
    -- Automatically prompt to save the recording
    if _G.CountTableEntries(currentData) > 1 then
        print("[Recorder] Recording complete! Use 'recorder_cmd save <name>' to save it")
        -- Display a message on screen for a few seconds
        print("[Recorder] Total ticks recorded: " .. _G.CountTableEntries(currentData))
    end
end

-- Function to start playback
local function StartPlayback()
    if currentData[0] and #currentData > 0 then
        DebugPrint("Starting playback")
        currentState = STATE.PLAYBACK_PREPARE
        currentTick = 0
        weaponSelectionAttempts = 0

        -- Apply initial weapon selection immediately
        if currentData[0].weaponSlot then
            DebugPrint("Starting playback with weapon slot " .. currentData[0].weaponSlot)
            ExecuteSlotCommand(currentData[0].weaponSlot)
            client.SetConVar("hud_fastswitch", 1)
        end
    end
end

-- Function to pause playback
local function PausePlayback()
    if currentState == STATE.PLAYBACK_ACTIVE or currentState == STATE.PLAYBACK_PREPARE then
        DebugPrint("Pausing playback")
        currentState = STATE.IDLE
    end
end

-- Function to reset all recording data
local function Reset()
    DebugPrint("Resetting recorder state")
    currentState = STATE.IDLE
    currentTick = 0
    currentData = {}
    currentSize = 1
    setuptimer = 128
    weaponSelectionAttempts = 0
end

---@param userCmd UserCmd
local function OnCreateMove(userCmd)
    local pLocal = entities.GetLocalPlayer()
    if pLocal == nil or not pLocal:IsAlive() then return end

    -- Handle each state
    if currentState == STATE.RECORDING then
        -- If this is the first tick, capture initial state
        if currentTick == 1 and not currentData[0] then
            CaptureInitialState(pLocal, userCmd)
        end

        local yaw, pitch, roll = userCmd:GetViewAngles()

        -- Calculate trace endpoint for aim correction
        local eyePos = GetEyePosition(pLocal)
        local viewDir = EulerAngles(pitch, yaw, roll):Forward()
        local viewTarget = nil
        local isWorldTarget = false

        if USE_VIEW_TRACE_CORRECTION then
            local trace = TraceViewRay(eyePos, viewDir, TRACE_DISTANCE)

            -- Only store trace endpoint if we hit something meaningful (world/static object)
            if trace.fraction < 1.0 then
                viewTarget = trace.endpos

                -- Check if we hit world or static geometry
                if trace.entity == nil or trace.entity:GetClass() == "CWorld" or
                    trace.entity:GetClass() == "CBaseEntity" then
                    isWorldTarget = true
                end

                if debugMode then
                    DebugPrint("Recording view target: " .. (isWorldTarget and "WORLD" or "ENTITY") ..
                        ", hit=" .. (trace.entity ~= nil and trace.entity:GetClass() or "nothing") ..
                        ", frac=" .. string.format("%.3f", trace.fraction))
                end
            end
        end

        -- Create a data table with current tick values
        local tickData = {
            viewAngles = EulerAngles(yaw, pitch, roll),
            position = pLocal:GetAbsOrigin(),
            viewTarget = viewTarget,
            isWorldTarget = isWorldTarget
        }

        -- Only add non-default values
        local forwardMove = userCmd:GetForwardMove()
        if forwardMove ~= DEFAULT_VALUES.forwardMove then
            tickData.forwardMove = forwardMove
        end

        local sideMove = userCmd:GetSideMove()
        if sideMove ~= DEFAULT_VALUES.sideMove then
            tickData.sideMove = sideMove
        end

        local upMove = userCmd:GetUpMove()
        if upMove ~= DEFAULT_VALUES.upMove then
            tickData.upMove = upMove
        end

        local buttons = userCmd:GetButtons()
        if buttons ~= DEFAULT_VALUES.buttons then
            tickData.buttons = buttons
        end

        if userCmd.impulse and userCmd.impulse ~= DEFAULT_VALUES.impulse then
            tickData.impulse = userCmd.impulse
        end

        if userCmd.weaponselect and userCmd.weaponselect ~= DEFAULT_VALUES.weaponselect then
            tickData.weaponselect = userCmd.weaponselect
        end

        if userCmd.weaponsubtype and userCmd.weaponsubtype ~= DEFAULT_VALUES.weaponsubtype then
            tickData.weaponsubtype = userCmd.weaponsubtype
        end

        -- Store the tick data efficiently
        StoreTickData(currentTick, tickData)

        currentSize = currentSize + 1
        currentTick = currentTick + 1
    elseif currentState == STATE.PLAYBACK_PREPARE then
        -- Apply initial state from tick 0
        local initialData = currentData[0]
        if not initialData then return end

        -- Apply the initial state
        ApplyState(userCmd, initialData)

        -- Continue weapon selection attempts
        if initialData.weaponSlot and weaponSelectionAttempts < maxWeaponSelectionAttempts then
            ExecuteSlotCommand(initialData.weaponSlot)
            weaponSelectionAttempts = weaponSelectionAttempts + 1
            DebugPrint("Weapon selection attempt " .. weaponSelectionAttempts .. " for slot " .. initialData.weaponSlot)
        end

        -- Check if we've reached the starting position
        local initialPosition = initialData.position
        local currentPosition = pLocal:GetAbsOrigin()
        local distance = (currentPosition - initialPosition):Length()
        local velocityLength = pLocal:EstimateAbsVelocity():Length()

        velocityLength = math.max(0.1, math.min(velocityLength, 50))

        -- Debug position information
        if currentTick % 33 == 0 and debugMode then
            DebugPrint("Preparing position - distance: " .. distance .. ", velocity: " .. velocityLength ..
                ", x: " .. string.format("%.2f", currentPosition.x - initialPosition.x) ..
                ", y: " .. string.format("%.2f", currentPosition.y - initialPosition.y) ..
                ", z: " .. string.format("%.2f", currentPosition.z - initialPosition.z))
        end

        -- Walk to the starting position with precision
        WalkTo(userCmd, pLocal, initialPosition)

        -- Check position accuracy and decide if we're close enough
        local positionAccurate = distance <= positionAccuracyThreshold
        local almostStill = velocityLength < 0.5
        local closeEnough = distance <= velocityLength + 5

        -- Start playback if we've reached the required position accuracy
        if positionAccurate or (almostStill and closeEnough) then
            DebugPrint("Starting actual playback - reached starting position with accuracy: " .. distance)
            currentState = STATE.PLAYBACK_ACTIVE
            currentTick = 1 -- Start at tick 1 for actual playback
            setuptimer = 128
            weaponSelectionAttempts = 0

            -- Force weapon selection one more time before playback starts
            if initialData.weaponSlot then
                ExecuteSlotCommand(initialData.weaponSlot)
            end
        else
            -- Timeout logic with progressive relaxation of requirements
            setuptimer = setuptimer - 1

            -- Early start if we're reasonably close but moving very slowly
            if setuptimer < 100 and distance < 10 and velocityLength < 1 then
                DebugPrint("Starting playback - close enough with slow movement")
                currentState = STATE.PLAYBACK_ACTIVE
                currentTick = 1
                setuptimer = 128
                weaponSelectionAttempts = 0

                if initialData.weaponSlot then
                    ExecuteSlotCommand(initialData.weaponSlot)
                end
                -- Timeout reached, force start
            elseif setuptimer < 1 then
                DebugPrint("Starting actual playback - timeout reached, distance: " .. distance)
                currentState = STATE.PLAYBACK_ACTIVE
                currentTick = 1
                setuptimer = 128
                weaponSelectionAttempts = 0

                if initialData.weaponSlot then
                    ExecuteSlotCommand(initialData.weaponSlot)
                end
            end
        end
    elseif currentState == STATE.PLAYBACK_ACTIVE then
        -- Skip if user is providing input
        if userCmd.forwardmove ~= 0 or userCmd.sidemove ~= 0 then return end

        -- Check if we've reached the end of recorded data
        if currentTick >= currentSize - 1 then
            if doRepeat then
                DebugPrint("End of recording reached - repeating")
                currentState = STATE.PLAYBACK_PREPARE
                currentTick = 0
                weaponSelectionAttempts = 0

                -- Apply initial state again
                ApplyState(userCmd, currentData[0])
            else
                DebugPrint("End of recording reached - stopping")
                currentState = STATE.IDLE
                return
            end
        end

        local data = currentData[currentTick]
        if data == nil then return end

        -- Apply all recorded values to the userCmd
        if data.viewAngles then
            if USE_VIEW_TRACE_CORRECTION and data.viewTarget then
                local eyePos = GetEyePosition(pLocal)

                -- For world targets, check if we can see the target point
                local canSeeTarget = false
                if data.isWorldTarget then
                    local direction = (data.viewTarget - eyePos):Normalize()
                    local trace = TraceViewRay(eyePos, direction, TRACE_DISTANCE)

                    -- Check if we can see close to the same point
                    local targetDistance = (data.viewTarget - eyePos):Length()
                    local traceDistance = (trace.endpos - eyePos):Length()
                    local distanceRatio = traceDistance / targetDistance

                    canSeeTarget = (distanceRatio > TRACE_FRACTION_THRESHOLD)

                    if debugMode and currentTick % 33 == 0 then
                        DebugPrint("Playback view check: " .. (canSeeTarget and "VISIBLE" or "BLOCKED") ..
                            ", ratio=" .. string.format("%.2f", distanceRatio))
                    end
                end

                -- Calculate and apply view angles
                local correctedViewAngles = CalculateViewAngles(eyePos, data.viewTarget)
                userCmd:SetViewAngles(correctedViewAngles:Unpack())
                if doViewAngles then
                    engine.SetViewAngles(correctedViewAngles)
                end

                -- If this is a world target and we can't see it, mark for position correction
                data._needsPositionCorrection = (data.isWorldTarget and not canSeeTarget)

                if debugMode and currentTick % 33 == 0 and data._needsPositionCorrection then
                    DebugPrint("Target blocked, needs position correction")
                end
            else
                -- Use original recorded angles
                userCmd:SetViewAngles(data.viewAngles:Unpack())
                if doViewAngles then
                    engine.SetViewAngles(data.viewAngles)
                end
            end
        end

        -- Set movement values with defaults (ensure they're numbers)
        userCmd:SetForwardMove(GetValueOrDefault(data, "forwardMove"))
        userCmd:SetSideMove(GetValueOrDefault(data, "sideMove"))
        userCmd:SetUpMove(GetValueOrDefault(data, "upMove"))

        -- Set buttons with default
        userCmd:SetButtons(GetValueOrDefault(data, "buttons"))

        -- Set additional command properties
        userCmd.impulse = GetValueOrDefault(data, "impulse")
        userCmd.weaponselect = GetValueOrDefault(data, "weaponselect")
        userCmd.weaponsubtype = GetValueOrDefault(data, "weaponsubtype")

        -- If data indicates a weapon switch, execute the slot command too
        if data.weaponselect and data.weaponselect > 0 and data.weaponselect <= 5 then
            ExecuteSlotCommand(data.weaponselect)
        end

        -- Handle position verification with improved correction
        local currentPosition = pLocal:GetAbsOrigin()
        local targetPosition = data.position
        local distance = (currentPosition - targetPosition):Length()
        local velocityLength = pLocal:EstimateAbsVelocity():Length()

        -- Debug position info every 33 ticks if enabled
        if currentTick % 33 == 0 and debugMode then
            DebugPrint("Playback position - distance: " .. string.format("%.2f", distance) ..
                ", velocity: " .. string.format("%.2f", velocityLength))
        end

        -- Determine dynamic accuracy threshold based on velocity
        local accuracyThreshold = ACCURACY_THRESHOLD_HIGH_SPEED
        if velocityLength < 2.0 then
            accuracyThreshold = ACCURACY_THRESHOLD_LOW_SPEED
        elseif velocityLength < 50.0 then
            accuracyThreshold = ACCURACY_THRESHOLD_MED_SPEED
        end

        -- Decide if position correction is needed - only in emergencies or when target not visible
        local emergencyCorrection = distance > EMERGENCY_POSITION_THRESHOLD
        local visibilityCorrection = data._needsPositionCorrection

        -- Only correct if emergency or visibility issues
        if emergencyCorrection or visibilityCorrection then
            local correctionReason = ""

            if visibilityCorrection then
                correctionReason = "Target not visible"
            else
                correctionReason = "Emergency position deviation"
            end

            -- We've deviated too much from recorded path, actively correct position
            if emergencyCorrection then
                DebugPrint("EMERGENCY position correction (" .. correctionReason .. ") - distance: " ..
                    string.format("%.2f", distance) .. ", velocity: " .. string.format("%.2f", velocityLength))
            else
                DebugPrint("Position correction (" ..
                    correctionReason .. ") - distance: " .. string.format("%.2f", distance))
            end

            WalkTo(userCmd, pLocal, targetPosition)

            -- Determine if we should increment tick based on dynamic accuracy threshold
            if distance <= accuracyThreshold or (emergencyCorrection and distance < EMERGENCY_POSITION_THRESHOLD * 0.9) then
                currentTick = currentTick + 1
                if debugMode then
                    DebugPrint("Position accurate enough (threshold: " .. string.format("%.2f", accuracyThreshold) ..
                        "), advancing tick")
                end
            else
                if debugMode and currentTick % 10 == 0 then
                    DebugPrint("Still adjusting position, distance: " .. string.format("%.2f", distance) ..
                        ", threshold: " .. string.format("%.2f", accuracyThreshold))
                end
            end
        else
            -- Normal playback - we're close enough
            currentTick = currentTick + 1
        end
    end
end

local function OnDraw()
    draw.SetFont(Fonts.Verdana)
    draw.Color(255, 255, 255, 255)

    -- Display current state
    if currentState == STATE.RECORDING then
        draw.Text(20, 120, string.format("Recording... (%d)", currentTick))
    elseif currentState == STATE.PLAYBACK_PREPARE then
        draw.Text(20, 120, string.format("Preparing for playback... (%d / %d)", currentTick, currentSize))
    elseif currentState == STATE.PLAYBACK_ACTIVE then
        draw.Text(20, 120, string.format("Playing... (%d / %d)", currentTick, currentSize))
    end

    if not gui.IsMenuOpen() and currentState == STATE.IDLE then return end

    if ImMenu.Begin("Movement Recorder", true) then
        -- Progress bar
        ImMenu.BeginFrame(1)
        ImMenu.PushStyle("ItemSize", { 385, 30 })

        local MaxSize = (currentSize > 0 and currentSize < 1000 and currentState == STATE.RECORDING) and 1000 or
            currentSize
        if currentState == STATE.RECORDING and (currentSize > MaxSize or currentTick > MaxSize) then
            MaxSize = math.max(currentSize, currentTick)
        end

        currentTick = ImMenu.Slider("Tick", currentTick, 0, MaxSize)

        ImMenu.PopStyle()
        ImMenu.EndFrame()

        -- Buttons
        ImMenu.BeginFrame(1)
        ImMenu.PushStyle("ItemSize", { 125, 30 })

        local recordButtonText = (currentState == STATE.RECORDING) and "Stop Recording" or "Start Recording"
        if ImMenu.Button(recordButtonText) then
            if currentState == STATE.RECORDING then
                StopRecording()
            else
                StartRecording()
            end
        end

        local playButtonText
        if #currentData == 0 then
            playButtonText = "No Recording"
        elseif currentState == STATE.PLAYBACK_ACTIVE or currentState == STATE.PLAYBACK_PREPARE then
            playButtonText = "Pause"
        else
            playButtonText = "Play"
        end

        if ImMenu.Button(playButtonText) then
            if currentState == STATE.RECORDING then
                StopRecording()
                StartPlayback()
            elseif currentState == STATE.PLAYBACK_ACTIVE or currentState == STATE.PLAYBACK_PREPARE then
                PausePlayback()
            else
                StartPlayback()
            end
        end

        if ImMenu.Button("Reset") then
            Reset()
        end

        ImMenu.PopStyle()
        ImMenu.EndFrame()
        
        -- Quick save/load buttons
        ImMenu.BeginFrame(1)
        ImMenu.PushStyle("ItemSize", { 125, 30 })
        
        -- Input field for recording name - replace InputText with text display
        if not _G.recorderSaveName then
            _G.recorderSaveName = "recording"
        end
        
        -- Display current name
        ImMenu.Text("Name: " .. _G.recorderSaveName)
        
        -- Add numbered preset names
        for i = 1, 5 do
            local buttonName = "recording" .. i
            if ImMenu.Button(buttonName) then
                _G.recorderSaveName = buttonName
            end
        end
        
        -- Save button
        if ImMenu.Button("Save Recording") then
            if _G.CountTableEntries(currentData) > 0 then
                SaveRecording(_G.recorderSaveName)
            else
                print("[Recorder] No recording data to save")
            end
        end
        
        -- Load button
        if ImMenu.Button("Load Recording") then
            if RecorderSettings.recordings[_G.recorderSaveName] then
                LoadRecording(_G.recorderSaveName)
                print("[Recorder] Loaded recording '" .. _G.recorderSaveName .. "'")
            else
                print("[Recorder] Recording '" .. _G.recorderSaveName .. "' not found")
            end
        end
        
        ImMenu.PopStyle()
        ImMenu.EndFrame()
        
        -- Display saved recordings
        ImMenu.BeginFrame(1)
        ImMenu.Text("Saved Recordings:")
        
        local count = 0
        local recordingsList = {}
        
        -- First collect all recording names
        for name, _ in pairs(RecorderSettings.recordings) do
            table.insert(recordingsList, name)
            count = count + 1
        end
        
        -- Sort them alphabetically for consistent display
        table.sort(recordingsList)
        
        -- Display the recordings with a limit
        for i = 1, math.min(count, 8) do
            local name = recordingsList[i]
            if ImMenu.Button(name) then
                -- Simply set the current name when clicked
                _G.recorderSaveName = name
                print("[Recorder] Selected recording: " .. name)
            end
        end
        
        if count == 0 then
            ImMenu.Text("  No recordings saved")
        elseif count > 8 then
            ImMenu.Text("  ... and " .. (count - 8) .. " more")
        end
        
        ImMenu.EndFrame()

        -- Options
        ImMenu.BeginFrame(1)

        doRepeat = ImMenu.Checkbox("Auto Repeat", doRepeat)
        doViewAngles = ImMenu.Checkbox("Apply View Angles", doViewAngles)
        debugMode = ImMenu.Checkbox("Debug Mode", debugMode)

        ImMenu.EndFrame()


        ImMenu.BeginFrame(1)

        EMERGENCY_POSITION_THRESHOLD = ImMenu.Slider("Emergency Threshold", EMERGENCY_POSITION_THRESHOLD, 10.0,
            200.0, 0.1)
        ImMenu.EndFrame()

        ImMenu.BeginFrame(1)
        ACCURACY_THRESHOLD_HIGH_SPEED = ImMenu.Slider("High Speed Threshold", ACCURACY_THRESHOLD_HIGH_SPEED, 1.0,
            100.0, 0.1)
        ImMenu.EndFrame()

        ImMenu.BeginFrame(1)

        ACCURACY_THRESHOLD_MED_SPEED = ImMenu.Slider("Medium Speed Threshold", ACCURACY_THRESHOLD_MED_SPEED, 0.5,
            10.0, 0.1)

        ImMenu.EndFrame()

        ImMenu.BeginFrame(1)

        ACCURACY_THRESHOLD_LOW_SPEED = ImMenu.Slider("Low Speed Threshold", ACCURACY_THRESHOLD_LOW_SPEED, 0.01, 1.0, 0.01)

        ImMenu.EndFrame()

        -- Add the crevice finder UI to the OnDraw function after the existing options
        ImMenu.BeginFrame(1)
        ImMenu.Text("Crevice Finder Settings:")
        SEARCH_FOV = ImMenu.Slider("Search FOV", SEARCH_FOV, 10.0, 180.0, 1.0)
        SEARCH_STEP_SIZE = ImMenu.Slider("Search Precision", SEARCH_STEP_SIZE, 0.1, 5.0, 0.1)

        if ImMenu.Button("Find Longest Trace") then
            LookAtBestAngle()
        end

        ImMenu.EndFrame()

        ImMenu.End()
    end
end

-- Add encoding/decoding and config functionality right after constants section
local function EncodeRecording(data)
    if not data or type(data) ~= "table" then
        print("[Recorder] Error: Cannot encode nil or non-table data")
        return nil
    end

    local dataCount = CountTableEntries(data)
    if dataCount == 0 then
        print("[Recorder] Error: No recording data to encode")
        return nil
    end

    local encodedString = ""

    -- Add metadata (version, tick count)
    local tickCount = 0
    for k, _ in pairs(data) do
        if type(k) == "number" and k > tickCount then
            tickCount = k
        end
    end

    print("[Recorder] Encoding recording with " .. tickCount .. " ticks")
    encodedString = string.format("REC1:%d:", tickCount)

    -- Encode each tick
    for tick = 0, tickCount do
        if data[tick] then
            local tickData = data[tick]

            -- Start tick data
            encodedString = encodedString .. "T" .. tick .. ":"

            -- Encode view angles if present
            if tickData.viewAngles then
                encodedString = encodedString .. string.format("V%.2f,%.2f,%.2f:",
                    tickData.viewAngles.pitch or 0,
                    tickData.viewAngles.yaw or 0,
                    tickData.viewAngles.roll or 0)
            end

            -- Encode position if present
            if tickData.position then
                encodedString = encodedString .. string.format("P%.2f,%.2f,%.2f:",
                    tickData.position.x or 0,
                    tickData.position.y or 0,
                    tickData.position.z or 0)
            end

            -- Encode buttons, movement, etc. if present
            if tickData.buttons then
                encodedString = encodedString .. "B" .. tickData.buttons .. ":"
            end

            if tickData.forwardMove then
                encodedString = encodedString .. "F" .. tickData.forwardMove .. ":"
            end

            if tickData.sideMove then
                encodedString = encodedString .. "S" .. tickData.sideMove .. ":"
            end

            if tickData.upMove then
                encodedString = encodedString .. "U" .. tickData.upMove .. ":"
            end

            if tickData.weaponSlot then
                encodedString = encodedString .. "W" .. tickData.weaponSlot .. ":"
            end

            if tickData.viewTarget then
                encodedString = encodedString .. string.format("VT%.2f,%.2f,%.2f:",
                    tickData.viewTarget.x or 0,
                    tickData.viewTarget.y or 0,
                    tickData.viewTarget.z or 0)

                if tickData.isWorldTarget ~= nil then
                    encodedString = encodedString .. "WT" .. (tickData.isWorldTarget and "1" or "0") .. ":"
                end
            end
        end
    end

    if #encodedString > 0 then
        return encodedString
    else
        print("[Recorder] Failed to encode recording - no data")
        return nil
    end
end

local function DecodeRecording(encodedString)
    local decodedData = {}

    -- Check for valid format
    if not encodedString:match("^REC1:") then
        print("Invalid recording format")
        return nil
    end

    -- Extract metadata
    local tickCount = tonumber(encodedString:match("REC1:(%d+):"))
    if not tickCount then
        print("Invalid recording format - missing tick count")
        return nil
    end

    -- Extract tick data
    local currentPos = encodedString:find("T0:")
    if not currentPos then
        print("Invalid recording format - missing initial tick")
        return nil
    end

    -- Process each tick
    while currentPos do
        -- Find the tick number
        local tickNum = tonumber(encodedString:match("T(%d+):", currentPos))
        if not tickNum then break end

        -- Initialize tick data
        decodedData[tickNum] = {}

        -- Find next tick or end of string
        local nextTickPos = encodedString:find("T" .. (tickNum + 1) .. ":", currentPos + 2)
        local endPos = nextTickPos or (#encodedString + 1)

        -- Get the tick data section
        local tickSection = encodedString:sub(currentPos, endPos - 1)

        -- Extract view angles
        local pitch, yaw, roll = tickSection:match("V([%d.-]+),([%d.-]+),([%d.-]+):")
        if pitch and yaw and roll then
            decodedData[tickNum].viewAngles = EulerAngles(
                tonumber(pitch),
                tonumber(yaw),
                tonumber(roll)
            )
        end

        -- Extract position
        local px, py, pz = tickSection:match("P([%d.-]+),([%d.-]+),([%d.-]+):")
        if px and py and pz then
            decodedData[tickNum].position = Vector3(
                tonumber(px),
                tonumber(py),
                tonumber(pz)
            )
        end

        -- Extract buttons
        local buttons = tickSection:match("B(%d+):")
        if buttons then
            decodedData[tickNum].buttons = tonumber(buttons)
        end

        -- Extract movement values
        local forwardMove = tickSection:match("F([%d.-]+):")
        if forwardMove then
            decodedData[tickNum].forwardMove = tonumber(forwardMove)
        end

        local sideMove = tickSection:match("S([%d.-]+):")
        if sideMove then
            decodedData[tickNum].sideMove = tonumber(sideMove)
        end

        local upMove = tickSection:match("U([%d.-]+):")
        if upMove then
            decodedData[tickNum].upMove = tonumber(upMove)
        end

        -- Extract weapon slot
        local weaponSlot = tickSection:match("W(%d+):")
        if weaponSlot then
            decodedData[tickNum].weaponSlot = tonumber(weaponSlot)
        end

        -- Extract view target
        local vtx, vty, vtz = tickSection:match("VT([%d.-]+),([%d.-]+),([%d.-]+):")
        if vtx and vty and vtz then
            decodedData[tickNum].viewTarget = Vector3(
                tonumber(vtx),
                tonumber(vty),
                tonumber(vtz)
            )

            -- Extract world target flag
            local isWorldTarget = tickSection:match("WT(%d):")
            if isWorldTarget then
                decodedData[tickNum].isWorldTarget = (isWorldTarget == "1")
            end
        end

        -- Move to next tick
        currentPos = nextTickPos
    end

    return decodedData
end

-- Helper function to count table entries (replacement for table.Count)
-- Make this global so it's accessible everywhere
_G.CountTableEntries = function(tbl)
    if not tbl then return 0 end
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

local function CountTableEntries(tbl)
    return _G.CountTableEntries(tbl)
end

-- Config system for saving and loading recordings
local function CreateCFG(folder_name, table)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.cfg")
    local file = io.open(filepath, "w")

    if file then
        local function serializeTable(tbl, level)
            level = level or 0
            local result = string.rep("    ", level) .. "{\n"
            for key, value in pairs(tbl) do
                result = result .. string.rep("    ", level + 1)
                if type(key) == "string" then
                    result = result .. '["' .. key .. '"] = '
                else
                    result = result .. "[" .. key .. "] = "
                end
                if type(value) == "table" then
                    result = result .. serializeTable(value, level + 1) .. ",\n"
                elseif type(value) == "string" then
                    result = result .. '"' .. value .. '",\n'
                else
                    result = result .. tostring(value) .. ",\n"
                end
            end
            result = result .. string.rep("    ", level) .. "}"
            return result
        end

        local serializedConfig = serializeTable(table)
        file:write(serializedConfig)
        file:close()
        print("[Recorder] Saved Config to " .. tostring(fullPath))
        return true
    end
    return false
end

local function LoadCFG(folder_name)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.cfg")
    print("[Recorder] Attempting to load config from: " .. filepath)

    local file = io.open(filepath, "r")
    if not file then
        print("[Recorder] Config file not found: " .. filepath)
        return nil
    end

    local content = file:read("*a")
    file:close()

    if not content or content == "" then
        print("[Recorder] Config file is empty: " .. filepath)
        return nil
    end

    -- Debug output of config file size
    print("[Recorder] Config file loaded, size: " .. #content .. " bytes")

    -- Output beginning and end of config to debug
    if #content > 200 then
        print("[Recorder] Config starts with: " .. content:sub(1, 100) .. "...")
        print("[Recorder] Config ends with: ..." .. content:sub(-100))
    else
        print("[Recorder] Config content: " .. content)
    end

    local chunk, err = load("return " .. content)
    if chunk then
        local success, result = pcall(chunk)
        if success and result then
            print("[Recorder] Successfully loaded config from " .. tostring(fullPath))

            -- Verify the structure of the loaded config
            if type(result) == "table" then
                print("[Recorder] Config is valid, contains " .. CountTableEntries(result) .. " root entries")

                -- Check if recordings exist
                if result.recordings and type(result.recordings) == "table" then
                    local recordingCount = CountTableEntries(result.recordings)
                    print("[Recorder] Config contains " .. recordingCount .. " recordings")
                else
                    print("[Recorder] Config does not contain any recordings")
                end
            else
                print("[Recorder] Warning: Config is not a table!")
            end

            return result
        else
            print("[Recorder] Error executing config chunk: " .. tostring(result))
            return nil
        end
    else
        print("[Recorder] Error loading configuration: " .. tostring(err))
        return nil
    end
end

-- Save settings function
local function SaveSettings()
    -- Update current settings
    RecorderSettings.defaultSettings = {
        doRepeat = doRepeat,
        doViewAngles = doViewAngles,
        debugMode = debugMode,
        PLAYBACK_POSITION_THRESHOLD = PLAYBACK_POSITION_THRESHOLD,
        MAX_CORRECTION_VELOCITY = MAX_CORRECTION_VELOCITY,
        EMERGENCY_POSITION_THRESHOLD = EMERGENCY_POSITION_THRESHOLD,
        ACCURACY_THRESHOLD_HIGH_SPEED = ACCURACY_THRESHOLD_HIGH_SPEED,
        ACCURACY_THRESHOLD_MED_SPEED = ACCURACY_THRESHOLD_MED_SPEED,
        ACCURACY_THRESHOLD_LOW_SPEED = ACCURACY_THRESHOLD_LOW_SPEED
    }

    -- Save recordings to a separate file for easy manual editing
    local success, fullPath = filesystem.CreateDirectory(string.format([[Lua %s]], Lua__fileName))
    local recordingsFilePath = tostring(fullPath .. "/recordings.txt")
    local recordingsFile = io.open(recordingsFilePath, "w")

    if recordingsFile then
        -- Write a header explaining the format
        recordingsFile:write("-- Movement Recorder Saved Recordings\n")
        recordingsFile:write("-- Format: RecordingName=EncodedString\n")
        recordingsFile:write("-- You can manually edit this file to add or modify recordings\n")
        recordingsFile:write("-- To load a recording in-game, use: playRecord \"EncodedString\"\n\n")

        -- Write each recording on a separate line for easy copying
        for name, encodedString in pairs(RecorderSettings.recordings) do
            recordingsFile:write(string.format("%s=%s\n", name, encodedString))
        end

        recordingsFile:close()
        print("[Recorder] Saved recordings to " .. recordingsFilePath)
    end

    -- Save settings to the main config
    return CreateCFG(string.format([[Lua %s]], Lua__fileName), RecorderSettings)
end

-- Function to load settings
local function LoadSettings()
    print("[Recorder] LoadSettings called - initializing configuration...")
    -- Try to load the main config
    local settings = LoadCFG(string.format([[Lua %s]], Lua__fileName))
    if settings then
        -- Apply loaded settings
        if settings.defaultSettings then
            doRepeat = settings.defaultSettings.doRepeat ~= nil and settings.defaultSettings.doRepeat or doRepeat
            doViewAngles = settings.defaultSettings.doViewAngles ~= nil and settings.defaultSettings.doViewAngles or
                doViewAngles
            debugMode = settings.defaultSettings.debugMode ~= nil and settings.defaultSettings.debugMode or debugMode
            PLAYBACK_POSITION_THRESHOLD = settings.defaultSettings.PLAYBACK_POSITION_THRESHOLD or
                PLAYBACK_POSITION_THRESHOLD
            MAX_CORRECTION_VELOCITY = settings.defaultSettings.MAX_CORRECTION_VELOCITY or MAX_CORRECTION_VELOCITY
            EMERGENCY_POSITION_THRESHOLD = settings.defaultSettings.EMERGENCY_POSITION_THRESHOLD or
                EMERGENCY_POSITION_THRESHOLD
            ACCURACY_THRESHOLD_HIGH_SPEED = settings.defaultSettings.ACCURACY_THRESHOLD_HIGH_SPEED or
                ACCURACY_THRESHOLD_HIGH_SPEED
            ACCURACY_THRESHOLD_MED_SPEED = settings.defaultSettings.ACCURACY_THRESHOLD_MED_SPEED or
                ACCURACY_THRESHOLD_MED_SPEED
            ACCURACY_THRESHOLD_LOW_SPEED = settings.defaultSettings.ACCURACY_THRESHOLD_LOW_SPEED or
                ACCURACY_THRESHOLD_LOW_SPEED
        end

        -- Store recordings
        if settings.recordings and type(settings.recordings) == "table" then
            print("[Recorder] Found " .. (_G.CountTableEntries(settings.recordings) or 0) .. " recordings in config")
            RecorderSettings.recordings = settings.recordings

            -- List all recording names
            print("[Recorder] Listing all loaded recordings:")
            for name, encodedString in pairs(settings.recordings) do
                print(" - " .. name .. " (" .. #encodedString .. " bytes)")
                
                -- Verify it's a proper binary recording
                if not encodedString:match("^REC1:") then
                    print("   * WARNING: Recording not properly encoded (missing REC1 header)")
                end
            end
        else
            print("[Recorder] No recordings found in config")
        end
    end

    -- Try to load recordings from the dedicated file
    local success, fullPath = filesystem.CreateDirectory(string.format([[Lua %s]], Lua__fileName))
    local recordingsFilePath = tostring(fullPath .. "/recordings.txt")
    local recordingsFile = io.open(recordingsFilePath, "r")

    local recordingsLoaded = 0

    if recordingsFile then
        print("[Recorder] Loading recordings from " .. recordingsFilePath)
        local content = recordingsFile:read("*a")
        recordingsFile:close()

        -- Parse each line to extract recordings
        for line in content:gmatch("[^\r\n]+") do
            -- Skip comment lines
            if not line:match("^%-%-") then
                local name, encodedString = line:match("(.-)=(.+)")
                if name and encodedString then
                    -- Verify the recording format
                    if not encodedString:match("^REC1:") then
                        print("[Recorder] Warning: Recording '" .. name .. "' not properly encoded (missing REC1 header)")
                    end
                    
                    local decodedData = DecodeRecording(encodedString)
                    if decodedData then
                        RecorderSettings.recordings[name] = encodedString
                        recordingsLoaded = recordingsLoaded + 1
                        print("[Recorder] Loaded recording: " .. name .. " (" .. #encodedString .. " bytes)")
                    else
                        print("[Recorder] Error: Failed to decode recording '" .. name .. "' from recordings.txt")
                    end
                end
            end
        end
    else
        print("[Recorder] No recordings.txt file found - this will be created when you save recordings")
    end

    print("[Recorder] Total recordings loaded: " .. (_G.CountTableEntries(RecorderSettings.recordings) or 0))
    
    -- Force initialization if there are no recordings
    if _G.CountTableEntries(RecorderSettings.recordings) == 0 then
        RecorderSettings.recordings = RecorderSettings.recordings or {}
    end

    return true
end

-- Functions to save and load recordings
local function SaveRecording(name)
    if not currentData or (type(currentData) == "table" and CountTableEntries(currentData) == 0) then
        print("[Recorder] No recording data to save")
        return nil
    end
    
    print("[Recorder] Preparing to save recording '" .. name .. "'...")
    print("[Recorder] Recording data has " .. CountTableEntries(currentData) .. " ticks")
    
    -- Debug print first tick
    if currentData[0] and debugMode then
        print("[Recorder] First tick data:")
        for k, v in pairs(currentData[0]) do
            print("  " .. k .. ": " .. tostring(v))
        end
    end

    -- Encode current recording to a binary string
    local encodedData = EncodeRecording(currentData)
    if not encodedData then
        print("[Recorder] Error encoding recording data")
        return nil
    end

    -- Verify the data starts with the proper header
    if not encodedData:match("^REC1:") then
        print("[Recorder] Warning: Encoded data doesn't have proper format, fixing...")
        -- Force proper format if missing
        local tickCount = 0
        for k, _ in pairs(currentData) do
            if type(k) == "number" and k > tickCount then
                tickCount = k
            end
        end
        encodedData = "REC1:" .. tickCount .. ":" .. encodedData
    end

    print("[Recorder] Encoded recording to binary string (" .. #encodedData .. " bytes)")

    -- Save to RecorderSettings
    RecorderSettings.recordings[name] = encodedData

    -- Save to the config files
    local success = SaveSettings()

    if success then
        print("[Recorder] Recording saved as '" .. name .. "'")
        print("[Recorder] Recording has been saved to config and recordings.txt")
    else
        print("[Recorder] Warning: Failed to save configuration")
    end

    return encodedData
end

local function LoadRecording(nameOrData)
    if not nameOrData then
        print("[Recorder] Error: No recording name or data provided")
        return false
    end

    print("[Recorder] Attempting to load recording: " ..
        (type(nameOrData) == "string" and #nameOrData > 30
            and nameOrData:sub(1, 30) .. "..."
            or tostring(nameOrData)))

    -- Check if it's a stored recording name
    if type(nameOrData) == "string" and #nameOrData < 100 and RecorderSettings.recordings[nameOrData] then
        print("[Recorder] Found recording by name: " .. nameOrData)
        local encodedData = RecorderSettings.recordings[nameOrData]

        if not encodedData or encodedData == "" then
            print("[Recorder] Error: Recording '" .. nameOrData .. "' exists but is empty")
            return false
        end

        -- Make sure it starts with the correct format marker
        if not encodedData:match("^REC1:") then
            print("[Recorder] Error: Recording '" .. nameOrData .. "' is not properly encoded (missing REC1 header)")
            return false
        end

        local decodedData = DecodeRecording(encodedData)

        if decodedData then
            -- Check if we have valid data
            local hasData = false
            local tickCount = 0
            for k, v in pairs(decodedData) do
                if type(k) == "number" then
                    hasData = true
                    if k > tickCount then
                        tickCount = k
                    end
                end
            end

            if not hasData then
                print("[Recorder] Error: Decoded recording has no valid tick data")
                return false
            end

            currentData = decodedData
            -- Calculate size by finding the highest tick number
            currentSize = tickCount + 1 -- Add 1 because it's 0-indexed
            print("[Recorder] Successfully loaded recording '" .. nameOrData .. "' with " .. currentSize .. " ticks")
            return true
        else
            print("[Recorder] Error: Failed to decode recording '" .. nameOrData .. "'")
        end
    else
        -- Try to decode it as direct data
        if type(nameOrData) == "string" and nameOrData:match("^REC1:") then
            print("[Recorder] Attempting to decode string as recording data")
            local decodedData = DecodeRecording(nameOrData)

            if decodedData then
                -- Check if we have valid data
                local hasData = false
                local tickCount = 0
                for k, v in pairs(decodedData) do
                    if type(k) == "number" then
                        hasData = true
                        if k > tickCount then
                            tickCount = k
                        end
                    end
                end

                if not hasData then
                    print("[Recorder] Error: Decoded recording has no valid tick data")
                    return false
                end

                currentData = decodedData
                -- Calculate size accurately
                currentSize = tickCount + 1 -- Add 1 because it's 0-indexed
                print("[Recorder] Successfully loaded recording from string with " .. currentSize .. " ticks")
                return true
            else
                print("[Recorder] Error: Failed to decode recording string")
            end
        else
            print("[Recorder] Error: Input is not a valid recording name or data")
        end
    end

    print("[Recorder] Failed to load recording")
    return false
end

-- Function to export a recording to a file
local function ExportRecording(name, customFilePath)
    if not RecorderSettings.recordings[name] then
        print("[Recorder] Recording '" .. name .. "' not found")
        return false
    end

    local filePath = customFilePath
    if not filePath then
        local success, fullPath = filesystem.CreateDirectory(string.format([[Lua %s/exports]], Lua__fileName))
        filePath = tostring(fullPath .. "/" .. name .. ".rec")
    end

    local file = io.open(filePath, "w")
    if file then
        file:write(RecorderSettings.recordings[name])
        file:close()
        print("[Recorder] Exported recording to " .. filePath)
        return true
    else
        print("[Recorder] Failed to export recording")
        return false
    end
end

-- Function to import a recording from a file
local function ImportRecordingFromFile(filePath, name)
    local file = io.open(filePath, "r")
    if not file then
        print("[Recorder] Failed to open file: " .. filePath)
        return false
    end

    local content = file:read("*a")
    file:close()

    if not content or content == "" then
        print("[Recorder] File is empty: " .. filePath)
        return false
    end

    if LoadRecording(content) then
        if name then
            SaveRecording(name)
        end
        return true
    else
        print("[Recorder] Failed to import recording from file: invalid format")
        return false
    end
end

-- Function to fix broken recordings
local function FixRecordings()
    local fixedCount = 0
    local corruptCount = 0
    
    print("[Recorder] Checking recordings...")
    for name, data in pairs(RecorderSettings.recordings) do
        print("[Recorder] Checking recording '" .. name .. "'...")
        
        if not data:match("^REC1:") then
            print("[Recorder] Invalid format for recording '" .. name .. "', removing")
            RecorderSettings.recordings[name] = nil
            corruptCount = corruptCount + 1
            goto continue
        end
        
        local test = DecodeRecording(data)
        if not test then
            print("[Recorder] Failed to decode recording '" .. name .. "', removing")
            RecorderSettings.recordings[name] = nil
            corruptCount = corruptCount + 1
        else
            -- Check if we have valid data
            local hasData = false
            for k, v in pairs(test) do
                if type(k) == "number" then
                    hasData = true
                    break
                end
            end
            
            if not hasData then
                print("[Recorder] Recording '" .. name .. "' has no tick data, removing")
                RecorderSettings.recordings[name] = nil
                corruptCount = corruptCount + 1
            else
                print("[Recorder] Recording '" .. name .. "' is valid (" .. #data .. " bytes)")
                fixedCount = fixedCount + 1
            end
        end
        
        ::continue::
    end
    
    -- Save changes
    SaveSettings()
    
    print("[Recorder] Fix complete: " .. fixedCount .. " valid recordings, " .. corruptCount .. " corrupt recordings removed")
    return fixedCount, corruptCount
end

-- Command handler for console commands
local function CommandHandler(cmd)
    local args = {}
    for arg in cmd:gmatch("%S+") do
        table.insert(args, arg)
    end

    if #args < 1 then
        print("[Recorder] Usage: recorder_cmd <save|load|play|delete|list|export|import|fix> [name] [file]")
        return
    end

    local operation = args[1]:lower()

    if operation == "save" and #args >= 2 then
        SaveRecording(args[2])
    elseif operation == "load" and #args >= 2 then
        LoadRecording(args[2])
    elseif operation == "play" and #args >= 2 then
        if LoadRecording(args[2]) then
            StartPlayback()
        end
    elseif operation == "delete" and #args >= 2 then
        if RecorderSettings.recordings[args[2]] then
            RecorderSettings.recordings[args[2]] = nil
            SaveSettings()
            print("[Recorder] Deleted recording '" .. args[2] .. "'")
        else
            print("[Recorder] Recording '" .. args[2] .. "' not found")
        end
    elseif operation == "list" then
        print("[Recorder] Available recordings:")
        local count = 0
        for name, _ in pairs(RecorderSettings.recordings) do
            print("  - " .. name)
            count = count + 1
        end
        if count == 0 then
            print("  No recordings saved")
        end
    elseif operation == "copy" and #args >= 2 then
        if RecorderSettings.recordings[args[2]] then
            gui.SetClipboardText(RecorderSettings.recordings[args[2]])
            print("[Recorder] Recording string copied to clipboard")
        else
            print("[Recorder] Recording '" .. args[2] .. "' not found")
        end
    elseif operation == "export" and #args >= 2 then
        -- Export with optional custom path
        if #args >= 3 then
            ExportRecording(args[2], args[3])
        else
            ExportRecording(args[2])
        end
    elseif operation == "import" and #args >= 3 then
        -- Import from file with a name
        ImportRecordingFromFile(args[3], args[2])
    elseif operation == "fix" then
        -- Fix broken recordings
        local fixed, corrupt = FixRecordings()
        print("[Recorder] Fixed " .. fixed .. " recordings, removed " .. corrupt .. " corrupt recordings")
    else
        print("[Recorder] Unknown command or missing arguments")
    end
end

-- Print information about console commands
print("=== Movement Recorder Commands ===")
print("recorder_cmd save <name> - Save current recording")
print("recorder_cmd load <name> - Load saved recording")
print("recorder_cmd play <name> - Load and play recording")
print("recorder_cmd delete <name> - Delete saved recording")
print("recorder_cmd copy <name> - Copy recording string to clipboard")
print("recorder_cmd export <name> [file] - Export recording to a file")
print("recorder_cmd import <name> <file> - Import recording from a file")
print("recorder_cmd list - List all saved recordings")
print("playRecord \"<recording_string>\" - Load and play from string")
print("=================================")
print("[Recorder] Recordings are saved to Lua Recorder/recordings.txt for manual editing")

-- Load saved settings on script initialization
LoadSettings()
print("[Recorder] Ready to use!")

-- Register command handlers for both recorder_cmd and playRecord command
callbacks.Register("SendStringCmd", "LNX.Recorder.Commands", function(cmd)
    local command = cmd:Get()

    -- Handle recorder_cmd
    if command:match("^recorder_cmd%s+") then
        local cmdArgs = command:gsub("^recorder_cmd%s+", "")
        CommandHandler(cmdArgs)
        cmd:Set("")
        return
    end

    -- Handle playRecord command
    if command:match("^playRecord%s+") then
        local recordingStr = command:match('^playRecord%s+"(.+)"')
        if recordingStr then
            if LoadRecording(recordingStr) then
                StartPlayback()
            end
            cmd:Set("")
            return
        end
    end
end)

-- Auto save settings when script is unloaded
callbacks.Register("Unload", "LNX.Recorder.Unload", function()
    print("[Recorder] Saving settings before unload...")
    SaveSettings()
end)

-- Save settings when menu values change - instead of IsAnyItemChanged which doesn't exist
local lastMenuState = {
    doRepeat = doRepeat,
    doViewAngles = doViewAngles,
    debugMode = debugMode,
    EMERGENCY_POSITION_THRESHOLD = EMERGENCY_POSITION_THRESHOLD,
    ACCURACY_THRESHOLD_HIGH_SPEED = ACCURACY_THRESHOLD_HIGH_SPEED,
    ACCURACY_THRESHOLD_MED_SPEED = ACCURACY_THRESHOLD_MED_SPEED,
    ACCURACY_THRESHOLD_LOW_SPEED = ACCURACY_THRESHOLD_LOW_SPEED,
    SEARCH_FOV = SEARCH_FOV,  -- Add the new search settings
    SEARCH_STEP_SIZE = SEARCH_STEP_SIZE
}

callbacks.Register("Draw", "LNX.Recorder.SaveOnChange", function()
    -- Check for changes in menu settings
    if currentState ~= STATE.RECORDING then
        local changed = false

        if doRepeat ~= lastMenuState.doRepeat or
            doViewAngles ~= lastMenuState.doViewAngles or
            debugMode ~= lastMenuState.debugMode or
            EMERGENCY_POSITION_THRESHOLD ~= lastMenuState.EMERGENCY_POSITION_THRESHOLD or
            ACCURACY_THRESHOLD_HIGH_SPEED ~= lastMenuState.ACCURACY_THRESHOLD_HIGH_SPEED or
            ACCURACY_THRESHOLD_MED_SPEED ~= lastMenuState.ACCURACY_THRESHOLD_MED_SPEED or
            SEARCH_FOV ~= lastMenuState.SEARCH_FOV or
            SEARCH_STEP_SIZE ~= lastMenuState.SEARCH_STEP_SIZE or
            ACCURACY_THRESHOLD_LOW_SPEED ~= lastMenuState.ACCURACY_THRESHOLD_LOW_SPEED then
            changed = true

            -- Update the last menu state
            lastMenuState = {
                doRepeat = doRepeat,
                doViewAngles = doViewAngles,
                debugMode = debugMode,
                EMERGENCY_POSITION_THRESHOLD = EMERGENCY_POSITION_THRESHOLD,
                ACCURACY_THRESHOLD_HIGH_SPEED = ACCURACY_THRESHOLD_HIGH_SPEED,
                ACCURACY_THRESHOLD_MED_SPEED = ACCURACY_THRESHOLD_MED_SPEED,
                ACCURACY_THRESHOLD_LOW_SPEED = ACCURACY_THRESHOLD_LOW_SPEED,
                SEARCH_FOV = SEARCH_FOV,
                SEARCH_STEP_SIZE = SEARCH_STEP_SIZE
            }
        end

        if changed then
            SaveSettings()
        end
    end
end)

-- Ensure callback registrations happen at the end of the file
callbacks.Unregister("CreateMove", "LNX.Recorder.CreateMove")
callbacks.Register("CreateMove", "LNX.Recorder.CreateMove", OnCreateMove)

callbacks.Unregister("Draw", "LNX.Recorder.Draw")
callbacks.Register("Draw", "LNX.Recorder.Draw", OnDraw)

-- Function to find the angle with the longest trace line
local function FindLongestTraceAngle(startYaw, fov)
    local pLocal = entities.GetLocalPlayer()
    if not pLocal or not pLocal:IsAlive() then return startYaw, 0 end
    
    local eyePos = GetEyePosition(pLocal)
    local leftAngle = startYaw - (fov / 2)
    local rightAngle = startYaw + (fov / 2)
    local bestYaw = startYaw
    local bestLength = 0
    
    -- Debug info
    if debugMode then
        DebugPrint("Starting crevice search with FOV " .. fov .. ", from " .. leftAngle .. " to " .. rightAngle)
    end
    
    -- First pass: sweep through the FOV range to find promising angles
    local steps = fov / SEARCH_STEP_SIZE
    for i = 0, steps do
        local currentYaw = leftAngle + (i * SEARCH_STEP_SIZE)
        local direction = EulerAngles(0, currentYaw, 0):Forward()
        local trace = TraceViewRay(eyePos, direction, SEARCH_DISTANCE)
        local traceLength = (trace.endpos - eyePos):Length()
        
        if traceLength > bestLength then
            bestLength = traceLength
            bestYaw = currentYaw
        end
    end
    
    -- Recursive binary-like refinement to find the best angle with higher precision
    local function RefineSearch(leftYaw, rightYaw, iteration)
        if iteration >= SEARCH_MAX_ITERATIONS or (rightYaw - leftYaw) < 0.05 then
            return bestYaw, bestLength
        end
        
        -- Test middle points of both halves
        local midLeft = leftYaw + (rightYaw - leftYaw) * 0.25
        local midRight = leftYaw + (rightYaw - leftYaw) * 0.75
        
        local directionLeft = EulerAngles(0, midLeft, 0):Forward()
        local traceLeft = TraceViewRay(eyePos, directionLeft, SEARCH_DISTANCE)
        local lengthLeft = (traceLeft.endpos - eyePos):Length()
        
        local directionRight = EulerAngles(0, midRight, 0):Forward()
        local traceRight = TraceViewRay(eyePos, directionRight, SEARCH_DISTANCE)
        local lengthRight = (traceRight.endpos - eyePos):Length()
        
        if lengthLeft > bestLength or lengthRight > bestLength then
            if lengthLeft > lengthRight then
                bestLength = lengthLeft
                bestYaw = midLeft
                return RefineSearch(leftYaw, midRight, iteration + 1)
            else
                bestLength = lengthRight
                bestYaw = midRight
                return RefineSearch(midLeft, rightYaw, iteration + 1)
            end
        end
        
        -- If we didn't find a better angle, narrow the search area
        if lengthLeft > lengthRight then
            return RefineSearch(leftYaw, midRight, iteration + 1)
        else
            return RefineSearch(midLeft, rightYaw, iteration + 1)
        end
    end
    
    -- Refine our search around the best angle we found
    local refinedLeftYaw = math.max(leftAngle, bestYaw - 5)
    local refinedRightYaw = math.min(rightAngle, bestYaw + 5)
    bestYaw, bestLength = RefineSearch(refinedLeftYaw, refinedRightYaw, 0)
    
    if debugMode then
        DebugPrint("Crevice search complete. Best angle: " .. bestYaw .. " with length " .. bestLength)
    end
    
    return bestYaw, bestLength
end

-- Function to look at the best angle
local function LookAtBestAngle()
    local pLocal = entities.GetLocalPlayer()
    if not pLocal or not pLocal:IsAlive() then return end
    
    local _, yaw, _ = engine.GetViewAngles()
    local bestYaw, bestLength = FindLongestTraceAngle(yaw, SEARCH_FOV)
    
    if bestLength > 0 then
        local currentPitch, _, currentRoll = engine.GetViewAngles()
        local newAngles = EulerAngles(currentPitch, bestYaw, currentRoll)
        engine.SetViewAngles(newAngles)
        print("[Recorder] Looking at best angle: " .. bestYaw .. " (trace length: " .. math.floor(bestLength) .. " units)")
    else
        print("[Recorder] Failed to find a good angle")
    end
end
