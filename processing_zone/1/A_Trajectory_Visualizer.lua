--[[
    Trajectory Visualizer for TF2
    Author: github.com/titaniummachine1
]]

if UnloadLib then UnloadLib() end

local lnxLib = require("lnxLib")
assert(lnxLib.GetVersion() >= 0.987, "lnxLib version is too old, please update it!")

local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer, WWeapon = lnxLib.TF2.WPlayer, lnxLib.TF2.WWeapon
local Helpers = lnxLib.TF2.Helpers
local Prediction = lnxLib.TF2.Prediction
local Fonts = lnxLib.UI.Fonts

local options = {
    maxPredictionTicks = 6,
    debugInfo = true
}

local function getProjectilePath(me, weapon)
    local projInfo = weapon:GetProjectileInfo()
    if not projInfo then return nil end

    local speed = projInfo[1]
    local shootPos = me:GetEyePos()

    local path = {}
    for i = 0, options.maxPredictionTicks do
        local solution = Math.SolveProjectile(shootPos, pos, projInfo[1], projInfo[2])
        if not solution then goto continue end

        -- The prediction is valid
        table.insert(path, solution.pos)

        -- TODO: FOV Check
        ::continue::
    end

    -- We didn't find a valid prediction
    if #path == 0 then return nil end

    return path
end

local function getTarget(me, weapon)
    if not me then return nil end

    if weapon:IsShootingWeapon() then
        local projType = weapon:GetWeaponProjectileType()
        if projType == 1 then
            -- Hitscan weapon
        else
            -- Projectile weapon
            return getProjectilePath(me, weapon)
        end
    end

    return nil
end

local function onDraw()
    if not options.debugInfo then return end

    draw.SetFont(Fonts.Verdana)
    draw.Color(255, 255, 255, 255)

    local me = WPlayer.GetLocal()
    if not me or not me:IsAlive() then return end

    local weapon = me:GetActiveWeapon()
    if not weapon then return end

    local path = getTarget(me, weapon)
    if path then
        local startScreenPos = client.WorldToScreen(path[1])
        local endScreenPos = client.WorldToScreen(path[options.maxPredictionTicks])

        if startScreenPos and endScreenPos then
            draw.Line(startScreenPos[1], startScreenPos[2], endScreenPos[1], endScreenPos[2])
        end
    end
end

callbacks.Unregister("Draw", "TrajectoryVisualizer.Draw")
callbacks.Register("Draw", "TrajectoryVisualizer.Draw", onDraw)