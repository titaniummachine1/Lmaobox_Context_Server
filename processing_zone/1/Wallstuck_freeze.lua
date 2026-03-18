local font = draw.CreateFont("Tahoma", 16, 800, FONTFLAG_OUTLINE)
local s_width, s_height = draw.GetScreenSize()
local direction1
local center
local closestPosition1
local function IsWallstuck()
    local flags = entities.GetLocalPlayer():GetPropInt("m_fFlags")

    if flags & FL_ONGROUND == 0 and entities.GetLocalPlayer():EstimateAbsVelocity():Length() == 6 then
        return true
    else
        return false
    end
end

local function GetClosestWallPosition(pLocalOrigin)
    center = pLocalOrigin
    local radius = 30 -- radius of the circle
    local segments = 90 -- number of segments to use for the circle
    local closestDistance = math.huge
    local closestPosition = nil

    for i = 1, segments do
        local angle = math.rad(i * (360 / segments))
        local direction = Vector3(math.cos(angle), math.sin(angle), 0)
        if center == nil or direction == nil or radius == nil then return nil end

        local endpos = center + direction * radius
        local trace = engine.TraceLine(pLocalOrigin, endpos, MASK_SHOT_HULL)

        local distance = (trace.endpos - center):Length()

        if distance < closestDistance then
            closestDistance = distance
            closestPosition = trace.endpos
        end
    end

    return closestPosition
end

local function isNaN(x) return x ~= x end
local M_RADPI = 180 / math.pi

-- Calculates the angle between two vectors
---@param source Vector3
---@param dest Vector3
---@return EulerAngles angles
function PositionAngles(source, dest)
    local delta = source - dest

    local pitch = math.atan(delta.z / delta:Length2D()) * M_RADPI
    local yaw = math.atan(delta.y / delta.x) * M_RADPI

    if delta.x >= 0 then
        yaw = yaw + 180
    end

    if isNaN(pitch) then pitch = 0 end
    if isNaN(yaw) then yaw = 0 end

    return EulerAngles(pitch, yaw, 0)
end

local function UserCmd(UserCmd)
    if IsWallstuck() then
        local pLocalOrigin = entities.GetLocalPlayer():GetAbsOrigin()
        center = pLocalOrigin
        local closestPosition = GetClosestWallPosition(pLocalOrigin)
        closestPosition1 = closestPosition
        
        if closestPosition then
            local direction = PositionAngles(pLocalOrigin, closestPosition)
            direction1 = direction
            local angles = EulerAngles(0, direction.yaw - 90, 0)
            --UserCmd:SetViewAngles(angles.pitch, angles.yaw, angles.roll)
            engine.SetViewAngles(EulerAngles(angles.pitch, angles.yaw, angles.roll))
        end
    end
end

local function Drawing()
    draw.SetFont(font)

    if IsWallstuck() then
        local ax, ay = draw.GetTextSize("Wallstuck")

        draw.Color(255, 255, 255, 255)
        draw.Text(math.floor((s_width / 2) - (ax / 2)), math.floor(s_height / 1.8), "Wallstuck")
    end

    --direction

          --draw assumed head pos
          screenPos = client.WorldToScreen(closestPosition1)
          if screenPos ~= nil then
              draw.Line( screenPos[1] + 10, screenPos[2], screenPos[1] - 10, screenPos[2])
              draw.Line( screenPos[1], screenPos[2] - 10, screenPos[1], screenPos[2] + 10)
          end

if direction1 == nil then return end
    draw.Color(255, 0, 0, 255)
    screenPos = client.WorldToScreen(center)
    if screenPos ~= nil then
        local endPoint = center + direction1 + 25
        local screenPos1 = client.WorldToScreen(endPoint)
        if screenPos1 ~= nil then
            draw.Line(screenPos[1], screenPos[2], screenPos1[1], screenPos1[2])
        end
    end
end

callbacks.Register("Draw", "Drawing", Drawing)
callbacks.Register("CreateMove", "UserCmd", UserCmd)
