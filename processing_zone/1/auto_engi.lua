config = {
    scriptName = "Engineer Auto-Fix Buildings",
    verbose = true
}

-- Utility functions
local function printVerbose(message)
    if config.verbose then
        print(message)
    end
end

local function getDistance(entity1, entity2)
    local pos1 = entity1:GetAbsOrigin()
    local pos2 = entity2:GetAbsOrigin()
    return (pos1 - pos2):Length()
end

local function positionAngles(source, dest)
    local M_RADPI = 180 / math.pi
    local delta = source - dest
    local pitch = math.atan(delta.z / math.sqrt(delta.x^2 + delta.y^2)) * M_RADPI
    local yaw = math.atan(delta.y, delta.x) * M_RADPI
    return {pitch = pitch, yaw = yaw, roll = 0}
end

local function repairBuilding(cmd, building, Me)
    local distance = getDistance(Me, building)
    if distance <= 105 then -- Melee range
        local weapon = Me:GetPropEntity("m_hActiveWeapon")
        if weapon:GetClass() ~= "CWeaponWrench" then
            client.Command("slot3", true) -- Switch to wrench
        end
        local angles = positionAngles(Me:GetAbsOrigin(), building:GetAbsOrigin())
        cmd:SetViewAngles(angles.pitch, angles.yaw, 0)
        cmd:SetButtons(bit.bor(cmd:GetButtons(), 1)) -- Attack
    end
end

-- Core logic
local function onCreateMove(cmd)
    local Me = entities.GetLocalPlayer()
    if not Me then return end

    local friend_team = Me:GetTeamNumber()
    local entities = entities.FindByClass("CObject*") -- Find all engineer buildings
    local buildingsAtReach = {}

    for i, entity in ipairs(entities) do
        if entity:GetTeamNumber() == friend_team and getDistance(Me, entity) <= 105 then
            table.insert(buildingsAtReach, entity)
        end
    end

    local lowestHealth = math.huge
    local buildingToRepair = nil

    for _, building in ipairs(buildingsAtReach) do
        local health = building:GetHealth()
        if health < lowestHealth then
            lowestHealth = health
            buildingToRepair = building
        end
    end

    if buildingToRepair then
        repairBuilding(cmd, buildingToRepair, Me)
    end
end

-- Hook
callbacks.Unregister("CreateMove", config.scriptName)
callbacks.Register("CreateMove", config.scriptName, onCreateMove)