local __bundle_require, __bundle_loaded, __bundle_register, __bundle_modules = (function(superRequire)
	local loadingPlaceholder = {[{}] = true}

	local register
	local modules = {}

	local require
	local loaded = {}

	register = function(name, body)
		if not modules[name] then
			modules[name] = body
		end
	end

	require = function(name)
		local loadedModule = loaded[name]

		if loadedModule then
			if loadedModule == loadingPlaceholder then
				return nil
			end
		else
			if not modules[name] then
				if not superRequire then
					local identifier = type(name) == 'string' and '\"' .. name .. '\"' or tostring(name)
					error('Tried to require ' .. identifier .. ', but no such module has been registered')
				else
					return superRequire(name)
				end
			end

			loaded[name] = loadingPlaceholder
			loadedModule = modules[name](require, loaded, register, modules)
			loaded[name] = loadedModule
		end

		return loadedModule
	end

	return require, loaded, register, modules
end)(require)
__bundle_register("__root", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    Projectile_Arc_Visualizer lua
    Autor: Titaniummachine1 - (https://github.com/titaniummachine1/Beta_Luas/blob/main/ProjectileArcVisualize.lua)
    pasted from GoodEveningFellOff - (https://github.com/GoodEveningFellOff/lmaobox-visualize-arc-trajectories)

    fixed issues with readability, fully reworked whole lua in most places where applicable
    simply translated to a readable format.
    might cause Curbit Overflow, idk how to fix it anyways
    just made sure nothing is created every frame to patch it.
]]

--[[ Activate the script Modules ]]
local G = require("Projectile_Visualizer.Globals")
local Common = require("Projectile_Visualizer.Common")
local Config = require("Projectile_Visualizer.Config")

--[[Classes]]--
local aItemDefinitions = require("Projectile_Visualizer.Modules.laDefinitions")
local TrajectoryLine = require("Projectile_Visualizer.Modules.TrajectoryLine")
local ImpactPolygon = require("Projectile_Visualizer.Modules.ImpactPolygon")
local PhysicsEnvironment = require("Projectile_Visualizer.Modules.PhysicsEnvironment")
local PhysicsObjectHandler = require("Projectile_Visualizer.Modules.PhysicsObjectHandler")
local ProjectileInfo = require("Projectile_Visualizer.Modules.ProjectileInfo")

--[[ Initialize Visuals ]]--
local impactPolygon = ImpactPolygon:new(G.Menu)  -- Create a new ImpactPolygon instance with the provided config
local trajectoryLine = TrajectoryLine:new()  -- Create a new TrajectoryLine instance

local g_fTraceInterval = Common.CLAMP(G.Menu.measure_segment_size, 0.5, 8) / 66
local g_fFlagInterval = g_fTraceInterval * 1320

-- Initialize the physics environment
local physicsEnv = PhysicsEnvironment.new()
physicsEnv:SetGravity(Vector3(0, 0, -client.GetConVar("sv_gravity")))
physicsEnv:SetAirDensity(2.0)
physicsEnv:SetSimulationTimestep(globals.TickInterval())

-- Initialize the physics objects
PhysicsObjectHandler:Initialize(physicsEnv)

-- Check if the trajectory should be drawn
local function ShouldDrawTrajectory()
    return not (engine.Con_IsVisible() or engine.IsGameUIVisible())
end

-- Validate the local player
local function IsValidLocalPlayer(pLocal)
    return pLocal and not pLocal:InCond(7) and pLocal:IsAlive()
end

-- Validate the weapon
local function IsValidWeapon(pWeapon)
    return pWeapon and (pWeapon:GetWeaponProjectileType() or 0) >= 2
end

-- Initialize the ProjectileInfo instance once
local projectileInfoInstance = ProjectileInfo:new()

-- Retrieve the projectile information object
local function GetProjectileInformationObject(pLocal, pWeapon)
    -- Get the item definition index from the weapon
    local iItemDefinitionIndex = pWeapon:GetPropInt("m_iItemDefinitionIndex")

    -- Determine the type of item definition from the predefined table
    local iItemDefinitionType = aItemDefinitions[iItemDefinitionIndex] or 0
    if iItemDefinitionType == 0 then return nil end  -- Return nil if the item is not valid

    -- Determine if the player is ducking
    local isDucking = (pLocal:GetPropInt("m_fFlags") & FL_DUCKING) == 2

    -- Update the existing ProjectileInfo instance with new data
    projectileInfoInstance:Update(pLocal, isDucking, iItemDefinitionType, iItemDefinitionIndex, pWeapon:GetWeaponID(), pWeapon)

    -- Retrieve the correct configuration function based on the item type
    local configFunction = ProjectileInfo.projectileConfigurations[iItemDefinitionType]
    if configFunction then
        -- Call the function to get the projectile information
        return configFunction(projectileInfoInstance), iItemDefinitionType
    else
        -- Return nil if no configuration function exists for the item type
        return nil
    end
end

-- Clear the trajectory data for the current tick to start fresh
local function ClearTrajectoryData()
    trajectoryLine:Clear()
end

-- Check if all conditions are met to render the trajectory
local function ShouldRenderTrajectory(pLocal, pWeapon)
    -- Ensures the trajectory should be drawn, the local player is valid, and the weapon is valid
    return ShouldDrawTrajectory() and IsValidLocalPlayer(pLocal) and IsValidWeapon(pWeapon)
end

-- Calculate the start position and the view angle for the projectile's trajectory
local function GetStartPositionAndAngle(pLocal)
    -- The start position is the player's current position plus their view offset
    local vStartPosition = pLocal:GetAbsOrigin() + pLocal:GetPropVector("localdata", "m_vecViewOffset[0]")
    -- The view angle is the direction the player is looking
    local vStartAngle = engine.GetViewAngles()
    return vStartPosition, vStartAngle
end

-- Perform the initial hull trace to determine the starting point of the trajectory
local function PerformInitialTrace(vStartPosition, vStartAngle, vOffset, vCollisionMin, vCollisionMax, pWeapon)
    -- A trace (or raycast) is done from the start position in the direction of the projectile to see where it would first hit
    return Common.TRACE_HULL(
        vStartPosition,
        vStartPosition + (vStartAngle:Forward() * vOffset.x) +
        (vStartAngle:Right() * (vOffset.y * (pWeapon:IsViewModelFlipped() and -1 or 1))) +
        (vStartAngle:Up() * vOffset.z),
        vCollisionMin, vCollisionMax, 100679691
    )
end

-- Adjust the view angle if needed, based on the weapon type and collision results
local function AdjustViewAngleIfNeeded(iItemDefinitionType, fForwardVelocity, vStartPosition, vStartAngle, results)
    -- Certain weapons (like bows or crossbows) might need the angle adjusted for more accurate trajectory prediction
    if iItemDefinitionType == -1 or (iItemDefinitionType >= 7 and iItemDefinitionType < 11) and fForwardVelocity ~= 0 then
        -- Trace a straight line forward to correct the angle
        local res = Common.TRACE_Line(results.startpos, results.startpos + (vStartAngle:Forward() * 2000), 100679691)
        -- Adjust the angle based on where the trace ends
        vStartAngle = (((res.fraction <= 0.1) and (results.startpos + (vStartAngle:Forward() * 2000)) or res.endpos) - vStartPosition):Angles()
    end
    return vStartAngle
end

-- Calculate the velocity vector for the projectile based on the start angle and weapon stats
local function CalculateVelocity(vStartAngle, fForwardVelocity, fUpwardVelocity)
    -- The velocity is a combination of the forward velocity and any upward velocity (like from a grenade arc)
    return (vStartAngle:Forward() * fForwardVelocity) + (vStartAngle:Up() * fUpwardVelocity)
end

-- Handle the trajectory for straight-line projectiles (like rockets)
local function HandleStraightLineTrajectory(results, vStartAngle, vStartPosition)
    -- Perform a line trace to see where a straight-line projectile will go
    local traceResults = Common.TRACE_Line(vStartPosition, vStartPosition + (vStartAngle:Forward() * 10000), 100679691)
    if traceResults.startsolid then return traceResults end  -- Stop if the projectile starts inside a solid object

    -- Calculate how many segments of the line should be drawn
    local iSegments = math.floor((traceResults.endpos - traceResults.startpos):Length() / g_fFlagInterval)
    local vForward = vStartAngle:Forward()

    -- Insert points along the trajectory into the trajectory line
    for i = 1, iSegments do
        trajectoryLine:Insert(vForward * (i * g_fFlagInterval) + vStartPosition)
    end

    -- Insert the final end position
    trajectoryLine:Insert(traceResults.endpos)
    return traceResults
end

-- Handle the trajectory for arc-based projectiles (like grenades)
local function HandleArcTrajectory(results, vStartPosition, vVelocity, vCollisionMin, vCollisionMax, fGravity, fDrag)
    local traceResults = results
    local vPosition = Vector3(0, 0, 0)

    -- Simulate the projectile's movement over time
    for i = 0.01515, 5, g_fTraceInterval do
        -- Calculate the scalar based on whether drag is present or not
        local scalar = (not fDrag) and i or ((1 - math.exp(-fDrag * i)) / fDrag)

        -- Update the position based on the velocity, gravity, and time
        vPosition.x = vVelocity.x * scalar + vStartPosition.x
        vPosition.y = vVelocity.y * scalar + vStartPosition.y
        vPosition.z = (vVelocity.z - fGravity * i) * scalar + vStartPosition.z

        -- Trace the trajectory and check for collisions
        traceResults = vCollisionMax.x ~= 0 and Common.TRACE_HULL(traceResults.endpos, vPosition, vCollisionMin, vCollisionMax, 100679691)
            or Common.TRACE_Line(vStartPosition, vStartPosition + (vStartAngle:Forward() * 10000), 100679691)

        -- Insert the new position into the trajectory line
        trajectoryLine:Insert(traceResults.endpos)

        if traceResults.fraction ~= 1 then break end  -- Stop if the projectile hits something
    end
    return traceResults
end

-- Handle the trajectory for physics-based projectiles (like sticky bombs)
local function HandlePhysicsBasedTrajectory(results, vStartPosition, vStartAngle, vVelocity, vCollisionMin, vCollisionMax, iItemDefinitionType)
    local traceResults = results
    -- Retrieve the physics object associated with the projectile
    local obj = PhysicsObjectHandler(iItemDefinitionType)

    -- Set the initial position and velocity of the physics object
    obj:SetPosition(vStartPosition, vStartAngle, true)
    obj:SetVelocity(vVelocity, Vector3(0, 0, 0))

    -- Simulate the physics object over several iterations to trace its path
    for i = 2, 330 do
        traceResults = Common.TRACE_HULL(traceResults.endpos, obj:GetPosition(), vCollisionMin, vCollisionMax, 100679691)
        trajectoryLine:Insert(traceResults.endpos)

        if traceResults.fraction ~= 1 then break end  -- Stop if the projectile hits something
        PhysicsEnvironment:Simulate(g_fTraceInterval)
    end

    -- Reset the physics simulation clock after use
    PhysicsEnvironment:ResetSimulationClock()
    return traceResults
end

-- Function to draw the impact polygon at the final position of the projectile, if applicable
local function DrawImpactPolygonIfNeeded(traceResults)
    -- Only draw the impact polygon if there is a valid surface plane to draw it on
    if traceResults and traceResults.plane and traceResults.fraction < 1 then
        print("Drawing impact polygon at:", traceResults.endpos)
        impactPolygon:drawImpactPolygon(traceResults.plane, traceResults.endpos)
    else
        print("Impact polygon not drawn, invalid conditions.")
    end
end

-- Main function to trace and simulate the trajectory
local function TraceAndSimulateTrajectory(pLocal, pWeapon)
    ClearTrajectoryData()  -- Clear previous tick's trajectory data

    -- Check if all conditions are met to render the trajectory
    if not ShouldRenderTrajectory(pLocal, pWeapon) then 
        print("Trajectory not rendered: Conditions not met.")
        return 
    end

    -- Retrieve the projectile information and the type of weapon being used
    local projectileInfo, iItemDefinitionType = GetProjectileInformationObject(pLocal, pWeapon)
    if not iItemDefinitionType or not projectileInfo then 
        print("No valid projectile information available.")
        return 
    end

    -- Unpack the projectile information for easier access
    local vOffset, fForwardVelocity, fUpwardVelocity, vCollisionMax, fGravity, fDrag = table.unpack(projectileInfo)
    local vCollisionMin = -vCollisionMax

    -- Calculate the start position and angle for the trajectory
    local vStartPosition, vStartAngle = GetStartPositionAndAngle(pLocal)
    print("Start position:", vStartPosition)

    -- Perform the initial trace to determine where the projectile starts
    local traceResults = PerformInitialTrace(vStartPosition, vStartAngle, vOffset, vCollisionMin, vCollisionMax, pWeapon)
    if traceResults.fraction ~= 1 then 
        print("Initial trace hit something, stopping.")
        return 
    end
    vStartPosition = traceResults.endpos

    -- Adjust the view angle if necessary based on the weapon type
    vStartAngle = AdjustViewAngleIfNeeded(iItemDefinitionType, fForwardVelocity, vStartPosition, vStartAngle, traceResults)

    -- Calculate the projectile's velocity vector
    local vVelocity = CalculateVelocity(vStartAngle, fForwardVelocity, fUpwardVelocity)
    -- Update the flag offset for rendering the trajectory line
    trajectoryLine.flagOffset = vStartAngle:Right() * -G.Menu.flags.size
    -- Insert the initial position into the trajectory line
    trajectoryLine:Insert(vStartPosition)
    print("Initial position inserted into trajectory line:", vStartPosition)

    -- Handle the trajectory based on the type of projectile
    if iItemDefinitionType == -1 then
        traceResults = HandleStraightLineTrajectory(traceResults, vStartAngle, vStartPosition)
    elseif iItemDefinitionType > 3 then
        traceResults = HandleArcTrajectory(traceResults, vStartPosition, vVelocity, vCollisionMin, vCollisionMax, fGravity, fDrag)
    else
        traceResults = HandlePhysicsBasedTrajectory(traceResults, vStartPosition, vStartAngle, vVelocity, vCollisionMin, vCollisionMax, iItemDefinitionType)
    end

    -- If no trajectory points were added, exit early
    if trajectoryLine.size == 0 then 
        print("No trajectory points were added, exiting.")
        return 
    end

    -- Draw the impact polygon at the final position of the trajectory
    DrawImpactPolygonIfNeeded(traceResults)

    -- Render the trajectory line if it has more than one point
    if trajectoryLine.size > 1 then
        print("Rendering trajectory line.")
        trajectoryLine:Render()
    end
end

-- Function to draw the trajectory
local function DrawTrajectory()
    local pLocal = entities.GetLocalPlayer()
    if not pLocal then return end
    local pWeapon = pLocal and pLocal:GetPropEntity("m_hActiveWeapon")
    if not pWeapon then return end

    TraceAndSimulateTrajectory(pLocal, pWeapon)
end

local function CleanupPhysics()
    PhysicsObjectHandler:Destroy()
    physics.DestroyEnvironment(PhysicsEnvironment)
    impactPolygon:destroy()
end

local function OnUnload()
    CleanupPhysics()
    Config.CreateCFG(G.Menu)
end

-- Register the drawing callback for rendering the trajectory
callbacks.Unregister("Draw", G.Lua__fileName .. "_DrawTrajectory")
callbacks.Unregister("Unload", G.Lua__fileName .. "_CleanupPhysicsObjects")

-- Register the drawing callback for rendering the trajectory
callbacks.Register("Draw", G.Lua__fileName .. "_DrawTrajectory", DrawTrajectory)
callbacks.Register("Unload", G.Lua__fileName .. "_CleanupPhysicsObjects", OnUnload)
end)
__bundle_register("Projectile_Visualizer.Modules.ProjectileInfo", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Import the Common module for utility functions
local Common = require("Projectile_Visualizer.Common")

-- Define the ProjectileInfo module
local ProjectileInfo = {}
ProjectileInfo.__index = ProjectileInfo

-- Local function to calculate the current charge time based on when the charge began
-- This is used to modify the projectile's initial velocity based on how long the player has charged the shot
local function GetCurrentChargeTime(pWeapon)
    local fChargeBeginTime = (pWeapon:GetPropFloat("m_flChargeBeginTime") or 0)
    if fChargeBeginTime ~= 0 then
        fChargeBeginTime = globals.CurTime() - fChargeBeginTime
    end
    return fChargeBeginTime
end

-- Constructor for the ProjectileInfo class
function ProjectileInfo:new()
    local self = setmetatable({}, ProjectileInfo)
    -- These properties will be initialized/updated later
    self.pLocal = nil
    self.bDucking = false
    self.iCase = 0
    self.iDefIndex = 0
    self.iWepID = 0
    self.fChargeBeginTime = 0
    return self
end

-- Method to initialize or update the ProjectileInfo instance with new data
function ProjectileInfo:Update(pLocal, bDucking, iCase, iDefIndex, iWepID, pWeapon)
    self.pLocal = pLocal
    self.bDucking = bDucking
    self.iCase = iCase
    self.iDefIndex = iDefIndex
    self.iWepID = iWepID
    self.fChargeBeginTime = GetCurrentChargeTime(pWeapon)
end

-- Method to get the offset for the projectile spawn position based on the weapon type
function ProjectileInfo:GetOffset(index)
    local offsets = {
        Vector3(16, 8, -6),   -- Index 1: Sticky Bomb, Iron Bomber
        Vector3(23.5, -8, -3),-- Index 2: Huntsman, Crossbow
        Vector3(23.5, 12, -3),-- Index 3: Flare Gun, Guillotine
        Vector3(16, 6, -8)    -- Index 4: Syringe Gun
    }
    return offsets[index]
end

-- Method to get the maximum collision size of the projectile based on the weapon type
function ProjectileInfo:GetCollisionMax(index)
    local collisionMaxs = {
        Vector3(0, 0, 0),   -- Index 1: use trace line instead, no hull size
        Vector3(1, 1, 1),   -- Index 2: Small collision size (Huntsman, Crossbow)
        Vector3(3.2, 3.2, 3.2), -- Index 3: Medium collision size (Sticky Bombs, Grenade Launcher)
        Vector3(3, 3, 3)    -- Index 4: Slightly smaller collision (Syringe Gun, Guillotine)
    }
    return collisionMaxs[index]
end

-- Method to get the minimum collision size, which is the negative of the maximum collision size
function ProjectileInfo:GetCollisionMin(index)
    return -self:GetCollisionMax(index)
end

-- Method to retrieve the correct projectile information based on the weapon type
function ProjectileInfo:GetProjectileInformation()
    local caseFunctions = {
        [-1] = function() return self:RocketLauncherInfo() end,
        [1] = function() return self:GetStickyBombInfo(4) end,
        [2] = function() return self:GetStickyBombInfo(1.2) end,
        [3] = function() return self:GetStickyBombInfo(4) end,
        [4] = function() return self:GetIronBomberInfo() end,
        [5] = function() return self:GetGrenadeLauncherInfo() end,
        [6] = function() return self:GetLooseCannonInfo() end,
        [7] = function() return self:GetHuntsmanInfo() end,
        [8] = function() return self:GetFlareGunInfo() end,
        [9] = function() return self:GetCrossbowInfo() end,
        [10] = function() return self:GetSyringeGunInfo() end,
        [11] = function() return self:GetJarateInfo() end,
        [12] = function() return self:GetGuillotineInfo() end,
    }

    local caseFunction = caseFunctions[self.iCase]
    if caseFunction then
        return caseFunction()
    else
        return nil
    end
end

-- Method to retrieve rocket launcher specific information
function ProjectileInfo:RocketLauncherInfo()
    local vOffset = Vector3(23.5, -8, self.bDucking and 8 or -3)
    local vCollisionMax = self:GetCollisionMax(2)
    local fForwardVelocity = 1200

    if self.iWepID == 22 or self.iWepID == 65 then
        vOffset.y, vCollisionMax, fForwardVelocity =
            (self.iDefIndex == 513) and 0 or 12,
            self:GetCollisionMax(1),
            (self.iWepID == 65) and 2000 or (self.iDefIndex == 414) and 1550 or 1100
    elseif self.iWepID == 109 then
        vOffset.y, vOffset.z = 6, -3
    end

    return {vOffset, fForwardVelocity, 0, vCollisionMax, 0}
end

-- Method to retrieve sticky bomb specific information, with charge handling
function ProjectileInfo:GetStickyBombInfo(chargeRate)
    local baseVelocity = 900
    local maxVelocityIncrease = 1500
    local velocity = baseVelocity + Common.CLAMP(self.fChargeBeginTime / chargeRate, 0, 1) * maxVelocityIncrease

    return {
        self:GetOffset(1),
        velocity,
        200,
        self:GetCollisionMax(3),
        0
    }
end

-- Method to retrieve Iron Bomber specific information
function ProjectileInfo:GetIronBomberInfo()
    return {
        self:GetOffset(1),
        1200,
        200,
        self:GetCollisionMax(3),
        400,
        0.45
    }
end

-- Method to retrieve grenade launcher specific information
function ProjectileInfo:GetGrenadeLauncherInfo()
    return {
        self:GetOffset(1),
        (self.iDefIndex == 308) and 1500 or 1200,
        200,
        self:GetCollisionMax(3),
        400,
        (self.iDefIndex == 308) and 0.225 or 0.45
    }
end

-- Method to retrieve Loose Cannon specific information
function ProjectileInfo:GetLooseCannonInfo()
    return {
        self:GetOffset(1),
        1440,
        200,
        self:GetCollisionMax(3),
        560,
        0.5
    }
end

-- Method to retrieve Huntsman specific information, with charge handling
function ProjectileInfo:GetHuntsmanInfo()
    local baseVelocity = 1800
    local maxVelocityIncrease = 800
    local velocity = baseVelocity + Common.CLAMP(self.fChargeBeginTime, 0, 1) * maxVelocityIncrease

    return {
        self:GetOffset(2),
        velocity,
        0,
        self:GetCollisionMax(2),
        200 - Common.CLAMP(self.fChargeBeginTime, 0, 1) * 160
    }
end

-- Method to retrieve Flare Gun specific information
function ProjectileInfo:GetFlareGunInfo()
    return {
        Vector3(23.5, 12, self.bDucking and 8 or -3),
        2000,
        0,
        self:GetCollisionMax(1),
        120
    }
end

-- Method to retrieve Crossbow specific information
function ProjectileInfo:GetCrossbowInfo()
    return {
        self:GetOffset(2),
        2400,
        0,
        self:GetCollisionMax((self.iDefIndex == 997) and 2 or 4),
        80
    }
end

-- Method to retrieve Syringe Gun specific information
function ProjectileInfo:GetSyringeGunInfo()
    return {
        self:GetOffset(4),
        1000,
        0,
        self:GetCollisionMax(2),
        120
    }
end

-- Method to retrieve Jarate specific information
function ProjectileInfo:GetJarateInfo()
    return {
        Vector3(23.5, 8, -3),
        1000,
        200,
        self:GetCollisionMax(4),
        450
    }
end

-- Method to retrieve Guillotine specific information
function ProjectileInfo:GetGuillotineInfo()
    return {
        Vector3(23.5, 8, -3),
        3000,
        300,
        self:GetCollisionMax(3),
        900,
        1.3
    }
end

-- Configuration table mapping item definitions to the corresponding information functions
ProjectileInfo.projectileConfigurations = {
    [-1] = function(self) return self:RocketLauncherInfo() end,
    [1] = function(self) return self:GetProjectileInformation() end,
    [2] = function(self) return self:GetProjectileInformation() end,
    [3] = function(self) return self:GetProjectileInformation() end,
    [4] = function(self) return self:GetProjectileInformation() end,
    [5] = function(self) return self:GetProjectileInformation() end,
    [6] = function(self) return self:GetProjectileInformation() end,
    [7] = function(self) return self:GetProjectileInformation() end,
    [8] = function(self) return self:GetProjectileInformation() end,
    [9] = function(self) return self:GetProjectileInformation() end,
    [10] = function(self) return self:GetProjectileInformation() end,
    [11] = function(self) return self:GetProjectileInformation() end,
    [12] = function(self) return self:GetProjectileInformation() end,
}

return ProjectileInfo

end)
__bundle_register("Projectile_Visualizer.Common", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable: duplicate-set-field, undefined-field
---@class Common
local Common = {}

--[[require modules]]--
local G = require("Projectile_Visualizer.Globals")

pcall(UnloadLib) -- if it fails then forget about it it means it wasnt loaded in first place and were clean

-- Unload the module if it's already loaded
if package.loaded["ImMenu"] then
    package.loaded["ImMenu"] = nil
end

local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 1.0, "LNXlib version is too old, please update it!")

Common.Lib = Lib
Common.Log = Lib.Utils.Logger.new(G.Lua__fileName)
Common.Notify = Lib.UI.Notify
Common.TF2 = Common.Lib.TF2
Common.Utils = Common.Lib.Utils
Common.Math, Common.Conversion = Common.Utils.Math, Common.Utils.Conversion
Common.WPlayer, Common.PR = Common.TF2.WPlayer, Common.TF2.PlayerResource
Common.Helpers = Common.TF2.Helpers
Common.Prediction = Common.TF2.Prediction

-- Function to normalize a vector
function Common.Normalize(vector)
    return vector / vector:Length()
end

-- Boring shit ahead!
Common.CROSS = (function(a, b, c) return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]); end);
Common.CLAMP = (function(a, b, c) return (a<b) and b or (a>c) and c or a; end);
Common.TRACE_HULL = engine.TraceHull;
Common.TRACE_Line = engine.TraceLine;
Common.WORLD2SCREEN = client.WorldToScreen;
Common.POLYGON = draw.TexturedPolygon;
Common.LINE = draw.Line;
Common.COLOR = draw.Color;

--[[ Callbacks ]]
local function OnUnload() -- Called when the script is unloaded
    pcall(UnloadLib) --unloading lualib
    engine.PlaySound("hl1/fvox/deactivated.wav") --deactivated
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("Unload", G.Lua__fileName .. "_Unload")                                -- unregister the "Unload" callback
--[[ Register callbacks ]]--
callbacks.Register("Unload", G.Lua__fileName .. "_Unload", OnUnload)                         -- Register the "Unload" callback

--[[ Play sound when loaded ]]--
engine.PlaySound("hl1/fvox/activated.wav")

return Common

end)
__bundle_register("Projectile_Visualizer.Globals", function(require, _LOADED, __bundle_register, __bundle_modules)
local G = {}

G.Lua__fileName = GetScriptName():match("([^/\\]+)%.lua$")
G.folder_name = string.format([[Lua %s]], G.Lua__fileName)

G.TICK_INTERVAL = globals.TickInterval()-- Tick interval in seconds

G.Default_Menu = {
    Enable = true,
    DuckJump = true,
    SmartJump = true,
    EdgeJump = true,
    Visuals = true,
}

G.Menu = {
	polygon = {
		enabled = true;
		r = 255;
		g = 200;
		b = 155;
		a = 50;

		size = 10;
		segments = 20;
	},

	line = {
		enabled = true;
		r = 255;
		g = 255;
		b = 255;
		a = 255;
	},

	flags = {
		enabled = true;
		r = 255;
		g = 0;
		b = 0;
		a = 255;

		size = 5;
	},

	outline = {
		line_and_flags = true;
		polygon = true;
		r = 0;
		g = 0;
		b = 0;
		a = 155;
	},

	-- 0.5 to 8, determines the size of the segments traced, lower values = worse performance (default 2.5)
	measure_segment_size = 2.5;
}

return G
end)
__bundle_register("Projectile_Visualizer.Modules.PhysicsObjectHandler", function(require, _LOADED, __bundle_register, __bundle_modules)
-- PhysicsObjectHandlerModule.lua

-- Define a handler for managing physics objects
local PhysicsObjectHandler = {}

-- Initialize the object list and the active object index
PhysicsObjectHandler.m_aObjects = {}  -- List to store all the physics objects
PhysicsObjectHandler.m_iActiveObject = 0  -- Index of the currently active object

-- Function to initialize and load physics objects
function PhysicsObjectHandler:Initialize(PhysicsEnvironment)
    -- Avoid reinitializing if objects are already loaded
    if #self.m_aObjects > 0 then return end

    -- Helper function to load a new physics object from a model path
    local function loadObject(path)
        -- Parse the model by name to get its solid and model information
        local solid, model = physics.ParseModelByName(path)

        -- Create a new poly object in the physics environment using the model's parameters
        local newObject = PhysicsEnvironment:CreatePolyObject(
            model,  -- The model of the object
            solid:GetSurfacePropName(),  -- The surface properties of the object
            solid:GetObjectParameters()  -- The physical parameters of the object
        )

        -- Insert the new object into the object list
        table.insert(self.m_aObjects, newObject)
    end

    -- Load the necessary physics objects based on their model paths
    loadObject("models/weapons/w_models/w_stickybomb.mdl")  -- Stickybomb
    loadObject("models/workshop/weapons/c_models/c_kingmaker_sticky/w_kingmaker_stickybomb.mdl")  -- QuickieBomb
    loadObject("models/weapons/w_models/w_stickybomb_d.mdl")  -- ScottishResistance, StickyJumper

    -- Wake the first object to set it as the active object
    if #self.m_aObjects > 0 then
        self.m_aObjects[1]:Wake()  -- Wake up the first physics object to make it active
        self.m_iActiveObject = 1  -- Set the active object index to 1
    end
end

-- Function to destroy all loaded physics objects
function PhysicsObjectHandler:Destroy(PhysicsEnvironment)
    self.m_iActiveObject = 0  -- Reset the active object index

    -- If there are no objects loaded, there's nothing to destroy
    if #self.m_aObjects == 0 then return end

    -- Loop through each loaded object
    for i, obj in pairs(self.m_aObjects) do
        -- Destroy the object within the physics environment
        PhysicsEnvironment:DestroyObject(obj)
        self.m_aObjects[i] = nil  -- Clear the reference to the destroyed object
    end
end

-- Metatable for PhysicsObjectHandler to allow it to be called like a function
setmetatable(PhysicsObjectHandler, {
    __call = function(self, iRequestedObject)
        -- If the requested object is not the currently active one, switch the active object
        if iRequestedObject ~= self.m_iActiveObject then
            self.m_aObjects[self.m_iActiveObject]:Sleep()  -- Put the current active object to sleep
            self.m_aObjects[iRequestedObject]:Wake()  -- Wake up the requested object to make it active
            self.m_iActiveObject = iRequestedObject  -- Update the active object index
        end

        -- Return the currently active object
        return self.m_aObjects[self.m_iActiveObject]
    end
})

-- Return the module table
return PhysicsObjectHandler
end)
__bundle_register("Projectile_Visualizer.Modules.PhysicsEnvironment", function(require, _LOADED, __bundle_register, __bundle_modules)
-- PhysicsEnvironmentModule.lua
-- This is a Lua module for managing the physics environment.

local PhysicsEnvironmentModule = {}
PhysicsEnvironmentModule.__index = PhysicsEnvironmentModule

-- Function to initialize the physics environment
function PhysicsEnvironmentModule:Initialize()
    -- Create the physics environment
    self.environment = physics.CreateEnvironment()

    -- Set the gravity in the physics environment using the server's gravity setting
    self.environment:SetGravity(Vector3(0, 0, -client.GetConVar("sv_gravity")))

    -- Set the air density to simulate air resistance
    self.environment:SetAirDensity(2.0)

    -- Set the simulation timestep to match the game's tick interval
    self.environment:SetSimulationTimestep(globals.TickInterval())
end

-- Function to get the physics environment (useful if you need to interact with it directly)
function PhysicsEnvironmentModule:GetEnvironment()
    return self.environment
end

-- Export the PhysicsEnvironmentModule as a module
return PhysicsEnvironmentModule

end)
__bundle_register("Projectile_Visualizer.Modules.ImpactPolygon", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Define the ImpactPolygon class
local ImpactPolygon = {}
ImpactPolygon.__index = ImpactPolygon

local Common = require("Projectile_Visualizer.Common")

-- Constructor for creating a new instance of ImpactPolygon
function ImpactPolygon:new(config)
    local self = setmetatable({}, ImpactPolygon)  -- Set up inheritance from ImpactPolygon
    self.config = config  -- Store the provided configuration
    -- Create a texture used for drawing the polygon, using RGBA values from the configuration
    self.m_iTexture = draw.CreateTextureRGBA(string.char(
        0xff, 0xff, 0xff, config.polygon.a,
        0xff, 0xff, 0xff, config.polygon.a,
        0xff, 0xff, 0xff, config.polygon.a,
        0xff, 0xff, 0xff, config.polygon.a
    ), 2, 2)
    self.iSegments = config.polygon.segments  -- Number of segments to use for the polygon (circle approximation)
    self.fSegmentAngleOffset = math.pi / self.iSegments  -- Calculate the angle offset for each segment
    self.fSegmentAngle = self.fSegmentAngleOffset * 2  -- The full angle of each segment
    return self  -- Return the new instance
end

-- Method to destroy the polygon texture when no longer needed
function ImpactPolygon:destroy()
    if self.m_iTexture then
        draw.DeleteTexture(self.m_iTexture)  -- Delete the texture to free up resources
        self.m_iTexture = nil  -- Set the texture reference to nil
    end
end

-- Reusable function to calculate positions of the polygon vertices
function ImpactPolygon:calculatePositions(plane, origin, radius)
    local positions = {}  -- Table to store the calculated positions

    -- Handle the case where the plane is almost perfectly horizontal (z-axis aligned)
    if math.abs(plane.z) >= 0.99 then
        for i = 1, self.iSegments do
            local ang = i * self.fSegmentAngle + self.fSegmentAngleOffset  -- Calculate the angle for this segment
            -- Calculate the world position and convert it to screen space
            positions[i] = Common.WORLD2SCREEN(origin + Vector3(radius * math.cos(ang), radius * math.sin(ang), 0))
            if not positions[i] then return nil end  -- Return nil if the position could not be calculated
        end
    else
        -- For non-horizontal planes, calculate the right and up vectors
        local right = Vector3(-plane.y, plane.x, 0)
        local up = Vector3(plane.z * right.y, -plane.z * right.x, (plane.y * right.x) - (plane.x * right.y))
        radius = radius / math.cos(math.asin(plane.z))  -- Adjust the radius based on the plane's tilt

        for i = 1, self.iSegments do
            local ang = i * self.fSegmentAngle + self.fSegmentAngleOffset  -- Calculate the angle for this segment
            -- Calculate the world position using the right and up vectors, then convert it to screen space
            positions[i] = Common.WORLD2SCREEN(origin + (right * (radius * math.cos(ang))) + (up * (radius * math.sin(ang))))
            if not positions[i] then return nil end  -- Return nil if the position could not be calculated
        end
    end

    return positions  -- Return the calculated positions
end

-- Reusable function to draw the outline of the polygon
function ImpactPolygon:drawOutline(positions)
    local last = positions[#positions]  -- Start with the last position in the list
    -- Set the outline color from the configuration
    Common.COLOR(self.config.outline.r, self.config.outline.g, self.config.outline.b, self.config.outline.a)

    -- Loop through each position and draw a line to the next position
    for i = 1, #positions do
        local new = positions[i]
        -- Determine whether to draw the outline horizontally or vertically based on the difference in coordinates
        if math.abs(new[1] - last[1]) > math.abs(new[2] - last[2]) then
            Common.LINE(last[1], last[2] + 1, new[1], new[2] + 1)
            Common.LINE(last[1], last[2] - 1, new[1], new[2] - 1)
        else
            Common.LINE(last[1] + 1, last[2], new[1] + 1, new[2])
            Common.LINE(last[1] - 1, last[2], new[1] - 1, new[2])
        end
        last = new  -- Update the last position for the next iteration
    end
end

-- Reusable function to draw the polygon itself
function ImpactPolygon:drawPolygon(positions)
    -- Ensure that the polygon configuration is available
    if not self.config or not self.config.polygon then
        error("Configuration for polygon drawing is missing or invalid")
        return
    end

    -- Set the color for the polygon fill based on the configuration
    Common.COLOR(self.config.polygon.r, self.config.polygon.g, self.config.polygon.b, 255)

    local cords, reverse_cords = {}, {}  -- Tables to store the polygon coordinates and their reverse order
    local sizeof = #positions  -- Number of positions (vertices) in the polygon
    local sum = 0  -- Sum used to determine the winding order of the polygon

    -- Loop through each position to prepare the coordinates and calculate the winding order
    for i, pos in pairs(positions) do
        local convertedTbl = {pos[1], pos[2], 0, 0}  -- Convert the position to a table format
        cords[i], reverse_cords[sizeof - i + 1] = convertedTbl, convertedTbl  -- Store in both forward and reverse order
        -- Ensure that the positions table is valid before accessing it
        local nextPos = positions[(i % sizeof) + 1]
        if not nextPos then
            error("Invalid position in positions table")
            return
        end
        sum = sum + Common.CROSS(pos, nextPos, positions[1])  -- Calculate the cross product to determine winding order
    end

    -- Draw the polygon using the calculated coordinates
    Common.POLYGON(self.m_iTexture, (sum < 0) and reverse_cords or cords, true)

    -- Draw the final outline around the polygon
    local last = positions[#positions]  -- Start with the last position in the list
    for i = 1, #positions do
        local new = positions[i]
        if not last or not new then
            error("Invalid position detected during final outline drawing")
            return
        end
        Common.LINE(last[1], last[2], new[1], new[2])  -- Draw the line between the last and new positions
        last = new  -- Update the last position for the next iteration
    end
end

-- Main function to draw the impact polygon based on the plane and origin
function ImpactPolygon:drawImpactPolygon(plane, origin)
    if not self.config.polygon.enabled then return end  -- Check if polygon drawing is enabled in the config

    local positions = self:calculatePositions(plane, origin, self.config.polygon.size)  -- Calculate the polygon positions
    if not positions then return end  -- If positions could not be calculated, exit early

    if self.config.outline.polygon then  -- If the outline is enabled in the config, draw the outline
        self:drawOutline(positions)
    end

    self:drawPolygon(positions)  -- Draw the polygon itself
end

-- Metatable to allow the ImpactPolygon instance to be called like a function
setmetatable(ImpactPolygon, {
    __call = function(self, plane, origin)
        self:drawImpactPolygon(plane, origin)  -- Call the drawImpactPolygon method when the instance is invoked
    end
})

return ImpactPolygon
end)
__bundle_register("Projectile_Visualizer.Modules.TrajectoryLine", function(require, _LOADED, __bundle_register, __bundle_modules)
-- TrajectoryLine.lua
-- This is a Lua module for handling the drawing and management of trajectory lines.

local TrajectoryLine = {}
TrajectoryLine.__index = TrajectoryLine

local Common = require("Projectile_Visualizer.Common")

-- Constructor for creating a new instance of TrajectoryLine
function TrajectoryLine:new()
    self = setmetatable({}, TrajectoryLine)  -- Set up inheritance from TrajectoryLine
    self.positions = {}                            -- Stores the positions along the trajectory
    self.size = 0                                  -- Tracks the number of positions
    self.flagOffset = Vector3(0, 0, 0)             -- Offset for rendering flags along the trajectory
    return self                                    -- Return the new instance
end

-- Method to insert a new position into the trajectory
function TrajectoryLine:Insert(vec)
    self.size = self.size + 1          -- Increment the size to keep track of the number of positions
    self.positions[self.size] = vec    -- Store the position vector in the positions table
end

-- Method to clear the trajectory data
function TrajectoryLine:Clear()
    self.positions = {}  -- Reset the positions table to an empty state
    self.size = 0        -- Reset the size counter to zero
end

-- Helper function to calculate the outline offset based on flag size
local function CalculateOutlineOffset(flagSize)
    return {
        inner = (flagSize < 1) and -1 or 0,  -- Offset for inner outline depending on flag size
        outer = (flagSize < 1) and -1 or 1   -- Offset for outer outline depending on flag size
    }
end

-- Function to draw the outline of a line
local function DrawOutline(last, new, outlineColor)
    -- Set the color for the outline
    G.COLOR(outlineColor.r, outlineColor.g, outlineColor.b, outlineColor.a)

    -- Determine the direction to draw the outline based on the difference in coordinates
    if math.abs(last[1] - new[1]) > math.abs(last[2] - new[2]) then
        -- If horizontal difference is greater, draw horizontal outline
        Common.LINE(last[1], last[2] - 1, new[1], new[2] - 1)
        Common.LINE(last[1], last[2] + 1, new[1], new[2] + 1)
    else
        -- If vertical difference is greater, draw vertical outline
        Common.LINE(last[1] - 1, last[2], new[1] - 1, new[2])
        Common.LINE(last[1] + 1, last[2], new[1] + 1, new[2])
    end
end

-- Function to draw a line with an optional outline
local function DrawLineWithOptionalOutline(last, new, lineColor, outlineColor)
    -- Draw the outline if the outline color is specified
    if outlineColor then
        DrawOutline(last, new, outlineColor)
    end
    -- Set the color for the line
    Common.COLOR(lineColor.r, lineColor.g, lineColor.b, lineColor.a)
    -- Draw the line between the last and new positions
    Common.LINE(last[1], last[2], new[1], new[2])
end

-- Method to render the trajectory based on the current configuration
function TrajectoryLine:Render(config)
    local lastScreenPos = nil  -- Variable to keep track of the last screen position
    local outlineOffset = CalculateOutlineOffset(config.flags.size)  -- Calculate the outline offsets

    -- Loop through the positions in reverse order to render the trajectory
    for i = self.size, 1, -1 do
        local worldPos = self.positions[i]              -- Get the current world position
        local screenPos = Common.WORLD2SCREEN(worldPos)        -- Convert the world position to screen coordinates
        local flagScreenPos = Common.WORLD2SCREEN(worldPos + self.flagOffset)  -- Apply the flag offset and convert to screen coordinates

        if lastScreenPos then
            -- Draw the line and flags with optional outlines based on the configuration
            if config.line.enabled then
                DrawLineWithOptionalOutline(lastScreenPos, screenPos, config.line, config.outline.line_and_flags and config.outline, outlineOffset.inner)
            end
            if config.flags.enabled then
                DrawLineWithOptionalOutline(flagScreenPos, screenPos, config.flags, config.outline.flags and config.outline, outlineOffset.outer)
            end
        end

        lastScreenPos = screenPos  -- Update the last screen position for the next iteration
    end
end

-- Utility function to setup and return color configurations
local function SetupColors(config)
    return {
        lineColor = {r = config.line.r, g = config.line.g, b = config.line.b, a = config.line.a},  -- Line color settings
        flagColor = {r = config.flags.r, g = config.flags.g, b = config.flags.b, a = config.flags.a},  -- Flag color settings
        outlineColor = {r = config.outline.r, g = config.outline.g, b = config.outline.b, a = config.outline.a}  -- Outline color settings
    }
end

SetupColors(G.Menu)  -- Set up color configurations for use in drawing

-- Export the TrajectoryLine class as a module
return TrajectoryLine
end)
__bundle_register("Projectile_Visualizer.Modules.laDefinitions", function(require, _LOADED, __bundle_register, __bundle_modules)
local aItemDefinitions = {
    [222]	= 11;		--Mad Milk                                      tf_weapon_jar_milk
    [812]	= 12;		--The Flying Guillotine                         tf_weapon_cleaver
    [833]	= 12;		--The Flying Guillotine (Genuine)               tf_weapon_cleaver
    [1121]	= 11;		--Mutated Milk                                  tf_weapon_jar_milk

    [18]	= -1;		--Rocket Launcher                               tf_weapon_rocketlauncher
    [205]	= -1;		--Rocket Launcher (Renamed/Strange)             tf_weapon_rocketlauncher
    [127]	= -1;		--The Direct Hit                                tf_weapon_rocketlauncher_directhit
    [228]	= -1;		--The Black Box                                 tf_weapon_rocketlauncher
    [237]	= -1;		--Rocket Jumper                                 tf_weapon_rocketlauncher
    [414]	= -1;		--The Liberty Launcher                          tf_weapon_rocketlauncher
    [441]	= -1;		--The Cow Mangler 5000                          tf_weapon_particle_cannon	
    [513]	= -1;		--The Original                                  tf_weapon_rocketlauncher
    [658]	= -1;		--Festive Rocket Launcher                       tf_weapon_rocketlauncher
    [730]	= -1;		--The Beggar's Bazooka                          tf_weapon_rocketlauncher
    [800]	= -1;		--Silver Botkiller Rocket Launcher Mk.I         tf_weapon_rocketlauncher
    [809]	= -1;		--Gold Botkiller Rocket Launcher Mk.I           tf_weapon_rocketlauncher
    [889]	= -1;		--Rust Botkiller Rocket Launcher Mk.I           tf_weapon_rocketlauncher
    [898]	= -1;		--Blood Botkiller Rocket Launcher Mk.I          tf_weapon_rocketlauncher
    [907]	= -1;		--Carbonado Botkiller Rocket Launcher Mk.I      tf_weapon_rocketlauncher
    [916]	= -1;		--Diamond Botkiller Rocket Launcher Mk.I        tf_weapon_rocketlauncher
    [965]	= -1;		--Silver Botkiller Rocket Launcher Mk.II        tf_weapon_rocketlauncher
    [974]	= -1;		--Gold Botkiller Rocket Launcher Mk.II          tf_weapon_rocketlauncher
    [1085]	= -1;		--Festive Black Box                             tf_weapon_rocketlauncher
    [1104]	= -1;		--The Air Strike                                tf_weapon_rocketlauncher_airstrike
    [15006]	= -1;		--Woodland Warrior                              tf_weapon_rocketlauncher
    [15014]	= -1;		--Sand Cannon                                   tf_weapon_rocketlauncher
    [15028]	= -1;		--American Pastoral                             tf_weapon_rocketlauncher
    [15043]	= -1;		--Smalltown Bringdown                           tf_weapon_rocketlauncher
    [15052]	= -1;		--Shell Shocker                                 tf_weapon_rocketlauncher
    [15057]	= -1;		--Aqua Marine                                   tf_weapon_rocketlauncher
    [15081]	= -1;		--Autumn                                        tf_weapon_rocketlauncher
    [15104]	= -1;		--Blue Mew                                      tf_weapon_rocketlauncher
    [15105]	= -1;		--Brain Candy                                   tf_weapon_rocketlauncher
    [15129]	= -1;		--Coffin Nail                                   tf_weapon_rocketlauncher
    [15130]	= -1;		--High Roller's                                 tf_weapon_rocketlauncher
    [15150]	= -1;		--Warhawk                                       tf_weapon_rocketlauncher

    [442]	= -1;		--The Righteous Bison                           tf_weapon_raygun

    [1178]	= -1;		--Dragon's Fury                                 tf_weapon_rocketlauncher_fireball

    [39]	= 8;		--The Flare Gun                                 tf_weapon_flaregun
    [351]	= 8;		--The Detonator                                 tf_weapon_flaregun
    [595]	= 8;		--The Manmelter                                 tf_weapon_flaregun_revenge
    [740]	= 8;		--The Scorch Shot                               tf_weapon_flaregun
    [1180]	= 0;		--Gas Passer                                    tf_weapon_jar_gas

    [19]	= 5;		--Grenade Launcher                              tf_weapon_grenadelauncher
    [206]	= 5;		--Grenade Launcher (Renamed/Strange)            tf_weapon_grenadelauncher
    [308]	= 5;		--The Loch-n-Load                               tf_weapon_grenadelauncher
    [996]	= 6;		--The Loose Cannon                              tf_weapon_cannon
    [1007]	= 5;		--Festive Grenade Launcher                      tf_weapon_grenadelauncher
    [1151]	= 4;		--The Iron Bomber                               tf_weapon_grenadelauncher
    [15077]	= 5;		--Autumn                                        tf_weapon_grenadelauncher
    [15079]	= 5;		--Macabre Web                                   tf_weapon_grenadelauncher
    [15091]	= 5;		--Rainbow                                       tf_weapon_grenadelauncher
    [15092]	= 5;		--Sweet Dreams                                  tf_weapon_grenadelauncher
    [15116]	= 5;		--Coffin Nail                                   tf_weapon_grenadelauncher
    [15117]	= 5;		--Top Shelf                                     tf_weapon_grenadelauncher
    [15142]	= 5;		--Warhawk                                       tf_weapon_grenadelauncher
    [15158]	= 5;		--Butcher Bird                                  tf_weapon_grenadelauncher

    [20]	= 1;		--Stickybomb Launcher                           tf_weapon_pipebomblauncher
    [207]	= 1;		--Stickybomb Launcher (Renamed/Strange)         tf_weapon_pipebomblauncher
    [130]	= 3;		--The Scottish Resistance                       tf_weapon_pipebomblauncher
    [265]	= 3;		--Sticky Jumper                                 tf_weapon_pipebomblauncher
    [661]	= 1;		--Festive Stickybomb Launcher                   tf_weapon_pipebomblauncher
    [797]	= 1;		--Silver Botkiller Stickybomb Launcher Mk.I     tf_weapon_pipebomblauncher
    [806]	= 1;		--Gold Botkiller Stickybomb Launcher Mk.I       tf_weapon_pipebomblauncher
    [886]	= 1;		--Rust Botkiller Stickybomb Launcher Mk.I       tf_weapon_pipebomblauncher
    [895]	= 1;		--Blood Botkiller Stickybomb Launcher Mk.I      tf_weapon_pipebomblauncher
    [904]	= 1;		--Carbonado Botkiller Stickybomb Launcher Mk.I  tf_weapon_pipebomblauncher
    [913]	= 1;		--Diamond Botkiller Stickybomb Launcher Mk.I    tf_weapon_pipebomblauncher
    [962]	= 1;		--Silver Botkiller Stickybomb Launcher Mk.II    tf_weapon_pipebomblauncher
    [971]	= 1;		--Gold Botkiller Stickybomb Launcher Mk.II      tf_weapon_pipebomblauncher
    [1150]	= 2;		--The Quickiebomb Launcher                      tf_weapon_pipebomblauncher
    [15009]	= 1;		--Sudden Flurry                                 tf_weapon_pipebomblauncher
    [15012]	= 1;		--Carpet Bomber                                 tf_weapon_pipebomblauncher
    [15024]	= 1;		--Blasted Bombardier                            tf_weapon_pipebomblauncher
    [15038]	= 1;		--Rooftop Wrangler                              tf_weapon_pipebomblauncher
    [15045]	= 1;		--Liquid Asset                                  tf_weapon_pipebomblauncher
    [15048]	= 1;		--Pink Elephant                                 tf_weapon_pipebomblauncher
    [15082]	= 1;		--Autumn                                        tf_weapon_pipebomblauncher
    [15083]	= 1;		--Pumpkin Patch                                 tf_weapon_pipebomblauncher
    [15084]	= 1;		--Macabre Web                                   tf_weapon_pipebomblauncher
    [15113]	= 1;		--Sweet Dreams                                  tf_weapon_pipebomblauncher
    [15137]	= 1;		--Coffin Nail                                   tf_weapon_pipebomblauncher
    [15138]	= 1;		--Dressed to Kill                               tf_weapon_pipebomblauncher
    [15155]	= 1;		--Blitzkrieg                                    tf_weapon_pipebomblauncher

    [588]	= -1;		--The Pomson 6000                               tf_weapon_drg_pomson
    [997]	= 9;		--The Rescue Ranger                             tf_weapon_shotgun_building_rescue

    [17]	= 10;		--Syringe Gun                                   tf_weapon_syringegun_medic
    [204]	= 10;		--Syringe Gun (Renamed/Strange)                 tf_weapon_syringegun_medic
    [36]	= 10;		--The Blutsauger                                tf_weapon_syringegun_medic
    [305]	= 9;		--Crusader's Crossbow                           tf_weapon_crossbow
    [412]	= 10;		--The Overdose                                  tf_weapon_syringegun_medic
    [1079]	= 9;		--Festive Crusader's Crossbow                   tf_weapon_crossbow

    [56]	= 7;		--The Huntsman                                  tf_weapon_compound_bow
    [1005]	= 7;		--Festive Huntsman                              tf_weapon_compound_bow
    [1092]	= 7;		--The Fortified Compound                        tf_weapon_compound_bow

    [58]	= 11;		--Jarate                                        tf_weapon_jar
    [1083]	= 11;		--Festive Jarate                                tf_weapon_jar
    [1105]	= 11;		--The Self-Aware Beauty Mark                    tf_weapon_jar
};


-- Function to create and return a table of item definitions
-- This table will map item definition indices to their respective categories.
local function CreateItemDefinitions(itemCategoryMappings)
    -- This table will hold the final item definitions.
    -- It will map each item definition index to its corresponding category.
    local itemDefinitionsTable = {}

    -- This variable will store the highest item definition index found in the input table.
    local maxItemDefinitionIndex = 0

    -- Loop through each key-value pair in the input table (itemCategoryMappings).
    -- The key is the item definition index, and the value is the category.
    for itemDefinitionIndex, _ in pairs(itemCategoryMappings) do
        -- Update the maxItemDefinitionIndex if the current itemDefinitionIndex is larger.
        maxItemDefinitionIndex = math.max(maxItemDefinitionIndex, itemDefinitionIndex)
    end

    -- Now that we know the highest item definition index, we can fill our itemDefinitionsTable.
    -- We loop from 1 to maxItemDefinitionIndex to ensure all indices are covered.
    for i = 1, maxItemDefinitionIndex do
        -- If the itemCategoryMappings table has a value for this index, use it.
        -- If not, assign false to this index.
        itemDefinitionsTable[i] = itemCategoryMappings[i] or false
    end

    -- Return the populated itemDefinitionsTable, which maps each item index to its category.
    return itemDefinitionsTable
end

-- We call the CreateItemDefinitions function, passing in our example mappings.
-- This will return a table that maps each item definition index to its corresponding category.
local aItemDefinitions = CreateItemDefinitions(laDefinitions)

return aItemDefinitions
end)
__bundle_register("Projectile_Visualizer.Config", function(require, _LOADED, __bundle_register, __bundle_modules)
local Config = {}

--[[require modules]]--
local G = require("Projectile_Visualizer.Globals")
local Common = require("Projectile_Visualizer.Common")

local Log = Common.Log
local Notify = Common.Notify
Log.Level = 0

--[[ Helper Functions ]]
function Config.GetFilePath()
    local success, fullPath = filesystem.CreateDirectory(G.folder_name)
    return fullPath .. "/config.cfg"
end

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

local function checkAllKeysExist(expectedMenu, loadedMenu)
    for key, value in pairs(expectedMenu) do
        if loadedMenu[key] == nil then
            return false
        end
        if type(value) == "table" then
            local result = checkAllKeysExist(value, loadedMenu[key])
            if not result then
                return false
            end
        end
    end
    return true
end

--[[ Configuration Functions ]]
function Config.CreateCFG(table)
    table = table or G.Default_Menu

    local filepath = Config.GetFilePath()
    local file = io.open(filepath, "w")
    local shortFilePath = filepath:match(".*\\(.*\\.*)$")

    if file then
        local serializedConfig = serializeTable(table)
        file:write(serializedConfig)
        file:close()

        printc(100, 183, 0, 255, "Success Saving Config: Path: " .. shortFilePath)
        Notify.Simple("Success! Saved Config to:", shortFilePath, 5)
    else
        local errorMessage = "Failed to open: " .. shortFilePath
        printc(255, 0, 0, 255, errorMessage)
        Notify.Simple("Error", errorMessage, 5)
    end
end

function Config.LoadCFG()
    local filepath = Config.GetFilePath()
    local file = io.open(filepath, "r")
    local shortFilePath = filepath:match(".*\\(.*\\.*)$")

    if file then
        local content = file:read("*a")
        file:close()
        local chunk, err = load("return " .. content)
        if chunk then
            local loadedMenu = chunk()
            if checkAllKeysExist(G.Default_Menu, loadedMenu) and not input.IsButtonDown(KEY_LSHIFT) then
                printc(100, 183, 0, 255, "Success Loading Config: Path: " .. shortFilePath)
                Notify.Simple("Success! Loaded Config from", shortFilePath, 5)
                G.Menu = loadedMenu
            else
                local warningMessage = input.IsButtonDown(KEY_LSHIFT) and "Creating a new config." or "Config is outdated or invalid. Creating a new config."
                printc(255, 0, 0, 255, warningMessage)
                Notify.Simple("Warning", warningMessage, 5)
                Config.CreateCFG(G.Default_Menu)
                G.Menu = G.Default_Menu
            end
        else
            local errorMessage = "Error executing configuration file: " .. tostring(err)
            printc(255, 0, 0, 255, errorMessage)
            Notify.Simple("Error", errorMessage, 5)
            Config.CreateCFG(G.Default_Menu)
            G.Menu = G.Default_Menu
        end
    else
        local warningMessage = "Config file not found. Creating a new config."
        printc(255, 0, 0, 255, warningMessage)
        Notify.Simple("Warning", warningMessage, 5)
        Config.CreateCFG(G.Default_Menu)
        G.Menu = G.Default_Menu
    end
end

--[[inicialization of lua]]--
Config.LoadCFG()

return Config
end)
return __bundle_require("__root")