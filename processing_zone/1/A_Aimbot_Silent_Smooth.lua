--[[
    Custom Aimbot for Lmaobox
    Author: github.com/lnx00
]]

---@alias AimTarget { entity : Entity, pos : Vector3, angles : EulerAngles, factor : number }
---@alias Rotation { yaw : number, pitch : number }
---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.967, "LNXlib version is too old, please update it!")

local Math = lnxLib.Utils.Math
local WPlayer = lnxLib.TF2.WPlayer
local Helpers = lnxLib.TF2.Helpers

local Hitbox = {
    Head = 1,
    Neck = 2,
    Pelvis = 4,
    Body = 5,
    Chest = 7
}

local options = {
    AimKey = KEY_LSHIFT,
    AutoShoot = true,
    Silent = true,
    AimPos = Hitbox.Body,
    AimFov = 27,
    MaxDist = 2000,
    SwitchTimer = 2000,
    IgnoreCloakedSpy = true
}

local currentTarget = nil

-- Returns the best target (lowest fov)
---@param me WPlayer
---@return AimTarget? target
local function GetBestTarget(me)
    local players = entities.FindByClass("CTFPlayer")
    local target = nil
    local lastFov = 180
    local lastDistance = options.MaxDist

    for _, entity in pairs(players) do
        if not entity then goto continue end
        if not entity:IsAlive() then goto continue end
        if entity:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then goto continue end
        -- FOV Check
        local player = WPlayer.FromEntity(entity)
        local aimPos = player:GetHitboxPos(options.AimPos)
        local mePos = me:GetEyePos()
        local dist = vector.Distance( {mePos.x,mePos.y,mePos.z}, {aimPos.x,aimPos.y,aimPos.z} )
        local angles = Math.PositionAngles(mePos, aimPos)
        local fov = Math.AngleFov(angles, engine.GetViewAngles())
        if fov > options.AimFov or dist > options.MaxDist then goto continue end
        -- Visiblity Check
        if not Helpers.VisPos(entity, me:GetEyePos(), aimPos) then goto continue end
        if options.IgnoreCloakedSpy and entity:InCond(4) then goto continue end
        -- Add valid target
        if ((fov * 100) / 180) + ((dist * 100) / options.MaxDist) < ((lastFov * 100) / 180) + ((lastDistance * 100) / options.MaxDist) then
            lastDistance = dist
            lastFov = fov
            target = { entity = entity, pos = aimPos, angles = angles, factor = fov }
        end

        ::continue::
    end

    return target
end
---@param v EulerAngles
---@return EulerAngles
function ClampAngles(v)
    local pitch = math.max(-89.0, math.min(89.0, Math.NormalizeAngle(v.pitch)));
    local yaw = Math.NormalizeAngle(v.yaw);
    return _G.EulerAngles(pitch,yaw,0)
end
---@param x number
---@return number
local function easeInOutQuint(x)
    if x < 0.5 then return 16 * x * x * x * x * x end
    return 1 - ((-2 * x + 2) ^ 5) / 2;
end
---@param old EulerAngles
---@param new EulerAngles
---@param factor number
---@return EulerAngles
function Smooth(old,new, factor)
    -- local diff = {new.yaw - old.yaw, new.pitch - old.pitch}
    -- local rotation = {old.yaw + (diff[1] * factor), old.pitch + (diff[2] * factor)}
    -- local an = _G.EulerAngles(rotation[2],rotation[1],0)
    local delta = ClampAngles(_G.EulerAngles(new.pitch - old.pitch,new.yaw - old.yaw,0))
    local aimPos = ClampAngles(_G.EulerAngles(old.pitch + (delta.pitch * factor), old.yaw + (delta.yaw * factor),0))
    return aimPos
end
local function updateTargetPosition()
    local old = currentTarget
    local player = WPlayer.FromEntity(old.entity)
    local aimPos = player:GetHitboxPos(options.AimPos)
    local mePos = WPlayer.GetLocal():GetEyePos()
    local angles = Math.PositionAngles(mePos, aimPos)
    local fov = Math.AngleFov(angles, engine.GetViewAngles())
    if not Helpers.VisPos(old.entity, mePos, aimPos) then
        currentTarget = nil
        return
    end
    currentTarget = { entity = old.entity, pos = aimPos, angles = angles, factor = fov }
end
local currentRotation = nil
local lastTarget = 0
local lastMS = os.clock()
local lastSwitch = os.clock()
local DisabledRotation = false
local hasTargetBefore = false
---@param userCmd UserCmd
local function OnCreateMove(userCmd)
    if currentRotation == nil then
        local pitch, yaw, roll = userCmd:GetViewAngles()
        currentRotation = _G.EulerAngles(pitch,yaw,roll)
    end
    if not input.IsButtonDown(options.AimKey) then
        lastTarget = 0
        currentTarget = nil
        if (hasTargetBefore) then
            lastMS = os.clock()
            hasTargetBefore = false
        end
        if (DisabledRotation) then
            lastMS = os.clock()
            local pitch, yaw, roll = userCmd:GetViewAngles()
            currentRotation = _G.EulerAngles(pitch,yaw,roll)
            hasTargetBefore = false
            return
        end
        onRotateBack(userCmd)
    return end
    local me = WPlayer.GetLocal()
    if not me then return end
    if not currentTarget then
        lastSwitch = os.clock()
        currentTarget = GetBestTarget(me)
    else
        if not currentTarget.entity then
            lastSwitch = os.clock()
            currentTarget = GetBestTarget(me)
        else
            -- Get the best target
            if not currentTarget.entity:IsAlive() or os.clock() - lastSwitch >= options.SwitchTimer / 1000 then
                lastSwitch = os.clock()
                currentTarget = GetBestTarget(me)
            end
        end
    end
    if currentTarget then
        updateTargetPosition()
        if not currentTarget then
            lastSwitch = os.clock()
            currentTarget = GetBestTarget(me)
        end
    end
    if not currentTarget then
        lastTarget = 0
        if (hasTargetBefore) then
            lastMS = os.clock()
            hasTargetBefore = false
        end
        if (DisabledRotation) then
            lastMS = os.clock()
            local pitch, yaw, roll = userCmd:GetViewAngles()
            currentRotation = _G.EulerAngles(pitch,yaw,roll)
            hasTargetBefore = false
        return end
        onRotateBack(userCmd)
    return end
    
    DisabledRotation = false
    hasTargetBefore = true
    if (not lastTarget == currentTarget.entity:GetIndex()) or lastTarget == 0 then
        lastTarget = currentTarget.entity:GetIndex()
        lastMS = os.clock()
    end
    local cTime = os.clock()
    local sec = cTime - lastMS
    local performe = 0.3
    local yawab = Math.NormalizeAngle(currentTarget.angles.yaw - currentRotation.yaw)
    local pitchab = Math.NormalizeAngle(currentTarget.angles.pitch - currentRotation.pitch)
    local diffToTarget = math.sqrt(yawab^2 + pitchab^2)
    if diffToTarget > 7  and diffToTarget <= 30 then
        performe = 0.5
    elseif diffToTarget > 30 and diffToTarget <= 90 then
        performe = 0.75
    elseif diffToTarget > 90 then
        performe = 1
    end
    local sec2 = sec / performe
    local factor = easeInOutQuint(math.min(sec2, 1))
    local rot = Smooth(currentRotation,currentTarget.angles,factor)
    -- Aim at the target
    if (cTime - lastMS > performe * 1.5) then
        lastMS = os.clock()
    end
    --userCmd:SetViewAngles(rot:Unpack())
    engine.SetViewAngles(rot)
    currentRotation = rot
    if not options.Silent then
        engine.SetViewAngles(rot)
    end
    -- Auto Shoot
    if options.AutoShoot then
        yawab = Math.NormalizeAngle(currentTarget.angles.yaw - currentRotation.yaw)
        pitchab = Math.NormalizeAngle(currentTarget.angles.pitch - currentRotation.pitch)
        diffToTarget = math.sqrt(yawab^2 + pitchab^2)
        if (diffToTarget <= 0.2) then
            userCmd.buttons = userCmd.buttons | IN_ATTACK
        end
    end
end

local function OnDraw()
    if not currentTarget then return end

    local me = WPlayer.GetLocal()
    if not me then return end
end
---@param userCmd UserCmd
function onRotateBack(userCmd)
    local cTime = os.clock()
    local sec = cTime - lastMS
    local performe = 0.15
    local p,y,r = userCmd:GetViewAngles()
    local yawab = Math.NormalizeAngle(y - currentRotation.yaw)
    local pitchab = Math.NormalizeAngle(p - currentRotation.pitch)
    local diffToTarget = math.sqrt(yawab^2 + pitchab^2)
    if diffToTarget > 7  and diffToTarget <= 30 then
        performe = 0.4
    elseif diffToTarget > 30 then
        performe = 0.65
    end
    local sec2 = sec / performe
    local factor = easeInOutQuint(math.min(sec2, 1))
    local rot = Smooth(currentRotation,_G.EulerAngles(p,y,r),factor)
    -- Aim at the target
    userCmd:SetViewAngles(rot:Unpack())
    currentRotation = rot
    if not options.Silent then
        engine.SetViewAngles(rot)
    end
    yawab = Math.NormalizeAngle(y - currentRotation.yaw)
    pitchab = Math.NormalizeAngle(p - currentRotation.pitch)
    diffToTarget = math.sqrt(yawab^2 + pitchab^2)
    if (diffToTarget <= 0.5) then
        DisabledRotation = true
    end
end

callbacks.Unregister("CreateMove", "LNX.AimbotSmooth.CreateMove")
callbacks.Register("CreateMove", "LNX.AimbotSmooth.CreateMove", OnCreateMove)

callbacks.Unregister("Draw", "LNX.AimbotSmooth.Draw")
callbacks.Register("Draw", "LNX.AimbotSmooth.Draw", OnDraw)