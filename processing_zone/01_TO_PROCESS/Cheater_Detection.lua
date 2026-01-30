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
    Cheater Detection for Lmaobox Recode
    Author: titaniummachine1 (https://github.com/titaniummachine1)
    Credits:
    LNX (github.com/lnx00) for base script
    Muqa for visuals and design assistance
    Alchemist for testing and party callout
]]

-- Check and disable anonymous mode if enabled (disrupts player detection)
if gui.GetValue("ANONYMOUSE MODE") == 1 then
	gui.SetValue("ANONYMOUSE MODE", 0)
	-- Send warning to local chat
	client.ChatPrintf(
		"\x04[CD]\x01 Anonymous mode disabled - it makes all players appear as bots and breaks detection!"
	)
end

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local Config = require("Cheater_Detection.Utils.Config") -- Load config early
local FastPlayers = require("Cheater_Detection.Utils.FastPlayers")
local Evidence = require("Cheater_Detection.Core.Evidence_system")
local Database = require("Cheater_Detection.Database.Database")
local PlayerState = require("Cheater_Detection.Utils.PlayerState")
local TickProfiler = require("Cheater_Detection.Utils.TickProfiler")
local EventManager = require("Cheater_Detection.Utils.EventManager")

--[[ UI components ]]
require("Cheater_Detection.Misc.Visuals.Menu") --[[ Imported by: Main.lua ]]

--[[ Misc features ]]
require("Cheater_Detection.Misc.ChatPrefix") --[[ Imported by: Main.lua ]]
require("Cheater_Detection.Misc.JoinNotifications") --[[ Imported by: Main.lua ]]
require("Cheater_Detection.Utils.Commands") --[[ Imported by: Main.lua ]]
require("Cheater_Detection.Database.SteamHistory") --[[ Imported by: Main.lua ]]
require("Cheater_Detection.Misc.Vote_Revel") --[[ Imported by: Main.lua ]]
require("Cheater_Detection.Misc.Auto_Vote") --[[ Imported by: Main.lua ]]

--[[ Detection modules ]]
local AntiAim = require("Cheater_Detection.Detection Methods.anti_aim")
local Bhop = require("Cheater_Detection.Detection Methods.bhop")
local DuckSpeed = require("Cheater_Detection.Detection Methods.Duck_Speed")
local FakeLag = require("Cheater_Detection.Detection Methods.fake_lag")
local WarpDT = require("Cheater_Detection.Detection Methods.warp_dt")
local ManualPriority = require("Cheater_Detection.Detection Methods.manual_priority")
local SilentAimbot = require("Cheater_Detection.Detection Methods.silent_aimbot")

--[[ Variables ]]
local WPlayer, PR = Common.WPlayer, Common.PlayerResource

--[[ Update the player data every tick ]]
--
local function OnCreateMove(cmd)
	local DebugMode = G.Menu.Advanced and G.Menu.Advanced.debug
	TickProfiler.SetEnabled(DebugMode)
	TickProfiler.BeginSection("CreateMove")

	local function profilerEnd()
		TickProfiler.EndSection("CreateMove")
	end

	-- Use FastPlayers for optimized player fetching (required directly)
	TickProfiler.BeginSection("FetchPlayers")
	local pLocal = FastPlayers.GetLocal() -- Get cached local player (still store in G for now)
	G.pLocal = pLocal -- Store for Evidence system to identify local player
	local allPlayers = FastPlayers.GetAll(not G.Menu.Advanced.debug) -- Exclude local unless debug mode
	TickProfiler.EndSection("FetchPlayers")

	if not pLocal then -- Need local player to proceed
		profilerEnd()
		return
	end

	-- Check connection state and store in G
	TickProfiler.BeginSection("CheckConnection")
	local ConnectionState = Common.CheckConnectionState()
	TickProfiler.EndSection("CheckConnection")

	--if not stable connection then dont do any checks
	if not ConnectionState.stable then
		profilerEnd()
		return
	end

	-- Apply evidence decay (once per second)
	TickProfiler.BeginSection("EvidenceDecay")
	Evidence.ApplyDecay()
	TickProfiler.EndSection("EvidenceDecay")

	-- No periodic trimming - on-demand caching only
	-- PlayerState persists until player disconnect event (player_disconnect)

	-- Iterate over the cached list of players
	for _, Player in ipairs(allPlayers) do
		local steamID = Player:GetSteamID64()

		-- Skip if already confirmed cheater (optimization - database or marked)
		TickProfiler.BeginSection("CheckCheaterStatus")
		local isMarked = Evidence.IsMarkedCheater(steamID)
		TickProfiler.EndSection("CheckCheaterStatus")

		if isMarked then
			goto continue
		end

		-- Push history ONLY for non-dormant players (can't detect dormant anyway)
		-- This saves ~16KB/tick by skipping useless record building
		TickProfiler.BeginSection("HistoryPush")
		if not Player:IsDormant() then
			Common.pushHistory(Player)
		end
		TickProfiler.EndSection("HistoryPush")

		-- Perform detection checks
		TickProfiler.BeginSection("Detections")

		TickProfiler.BeginSection("Detection_AntiAim")
		AntiAim.Check(Player)
		TickProfiler.EndSection("Detection_AntiAim")

		TickProfiler.BeginSection("Detection_DuckSpeed")
		DuckSpeed.Check(Player)
		TickProfiler.EndSection("Detection_DuckSpeed")

		TickProfiler.BeginSection("Detection_Bhop")
		Bhop.Check(Player)
		TickProfiler.EndSection("Detection_Bhop")

		TickProfiler.BeginSection("Detection_FakeLag")
		FakeLag.Check(Player)
		TickProfiler.EndSection("Detection_FakeLag")

		TickProfiler.BeginSection("Detection_WarpDT")
		WarpDT.Check(Player)
		TickProfiler.EndSection("Detection_WarpDT")

		TickProfiler.BeginSection("Detection_ManualPriority")
		ManualPriority.Check(Player)
		TickProfiler.EndSection("Detection_ManualPriority")

		TickProfiler.BeginSection("Detection_SilentAimbot")
		SilentAimbot.Check(Player)
		TickProfiler.EndSection("Detection_SilentAimbot")

		TickProfiler.EndSection("Detections")

		::continue::
	end

	-- Garbage Collection Monitoring (no manual tuning)
	TickProfiler.BeginSection("GarbageCollection")
	local memBefore = collectgarbage("count")

	-- Let Lua's automatic GC handle collection
	-- Manual tuning was causing saw-tooth pattern and unpredictable spikes

	local memAfter = collectgarbage("count")
	TickProfiler.EndSection("GarbageCollection")

	profilerEnd()
end

--[[ Map Change Handler ]]
local function OnMapChange()
	-- Force save database on map change
	-- Save database on map change if dirty
	Database.SaveDatabase()

	-- Reload database on new map
	Database.LoadDatabase(false, true)

	if G.Menu.Advanced.debug then
		print("[CD] Map changed - Database saved and reloaded")
	end
end

--[[ Event Handlers ]]

-- Handler: Player disconnect cleanup
local function onPlayerDisconnect(event)
	local networkID = event:GetString("networkid")
	local steamID = Common.FromSteamid3To64(networkID)
	if steamID then
		Evidence.OnPlayerLeave(steamID)
	end
end

-- Handler: Auto-save on local player death
local function onPlayerDeath(event)
	local localPlayer = entities.GetLocalPlayer()
	local victimUserID = event:GetInt("userid")
	local victim = entities.GetByUserID(victimUserID)

	if localPlayer and victim and localPlayer == victim then
		Database.SaveDatabase()
	end
end

-- Handler: Auto-save on round end
local function onRoundEnd(event)
	Database.SaveDatabase()
end

-- Handler: Auto-save on game over
local function onGameOver(event)
	Database.SaveDatabase()
end

-- Handler: Silent aimbot shot detection
local function onPlayerHurt(event)
	local shooterUserID = event:GetInt("attacker")
	local victimUserID = event:GetInt("userid")
	local shooter = entities.GetByUserID(shooterUserID)
	local victim = entities.GetByUserID(victimUserID)

	if shooter and victim then
		SilentAimbot.OnPlayerHurt(shooter, victim)
	end
end

--[[ Event Registration - Centralized via EventManager ]]

-- Main detection loop
EventManager.Register("CreateMove", "Main_Detection", OnCreateMove)

-- Map change events (save and reload database)
EventManager.Register("FireGameEvent", "Main_MapChange_NewMap", OnMapChange, "game_newmap")
EventManager.Register("FireGameEvent", "Main_MapChange_RoundStart", OnMapChange, "teamplay_round_start")
EventManager.Register("FireGameEvent", "Main_MapChange_CSRoundStart", OnMapChange, "cs_round_start")

-- Player lifecycle
EventManager.Register("FireGameEvent", "Main_PlayerDisconnect", onPlayerDisconnect, "player_disconnect")

-- Auto-save triggers (non-intrusive moments)
EventManager.Register("FireGameEvent", "Main_PlayerDeath", onPlayerDeath, "player_death")
EventManager.Register("FireGameEvent", "Main_RoundWin", onRoundEnd, "teamplay_round_win")
EventManager.Register("FireGameEvent", "Main_RoundStalemate", onRoundEnd, "teamplay_round_stalemate")
EventManager.Register("FireGameEvent", "Main_GameOver", onGameOver, "teamplay_game_over")
EventManager.Register("FireGameEvent", "Main_TFGameOver", onGameOver, "tf_game_over")
EventManager.Register("FireGameEvent", "Main_PlayerHurt", onPlayerHurt, "player_hurt")
EventManager.Register("FireGameEvent", "Main_ArenaRoundStart", onRoundEnd, "arena_round_start")

end)
__bundle_register("Cheater_Detection.Detection Methods.silent_aimbot", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Silent Aimbot Detection (Viewangle Extrapolation) ]]

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local Evidence = require("Cheater_Detection.Core.Evidence_system")
local Quaternion = require("Cheater_Detection.Utils.Quaternion")

--[[ Module Declaration ]]
local SilentAimbot = {}

--[[ Configuration ]]
local DETECTION_NAME = "silent_aimbot"
local EVIDENCE_WEIGHT_BASE = 15 -- Moderate-high weight for confirmed detections
local EVIDENCE_WEIGHT_IMPOSSIBLE = 50 -- Max weight for 90°+ impossible shots

local CONFIG = {
	MIN_FLICK_DELTA = 0.7, -- Minimum flick to trigger check
	PERFECT_AIM_TOLERANCE = 0.2, -- How close to perfect aim
	TRAJECTORY_MAINTAINED = 1.0, -- Max delta for maintained trajectory
	TRAJECTORY_BROKEN = 5.0, -- Min delta for broken trajectory
	IMPOSSIBLE_FLICK = 90.0, -- Instant catch for shooting behind
	MAX_HISTORY_SIZE = 5, -- Track 5 ticks per player
	POS_HISTORY_SIZE = 2, -- Track 2 ticks of positions
	EXTRAPOLATE_TICKS = 2, -- Predict 2 ticks ahead
}

--[[ Per-Player State ]]
local playerAngleHistory = {} -- [idx] = {{pitch, yaw, roll, tick, shotFired}, ...}
local playerPosHistory = {} -- [idx] = {{headPos, bodyPos, tick}, ...}
local lastShot = { shooter = nil, victim = nil, tick = 0 }

--[[ Helper Functions ]]

-- Calculate FoV between two angles
local function angleFoV(from, to)
	local dx = math.sin(math.rad(to.yaw)) * math.cos(math.rad(to.pitch))
		- math.sin(math.rad(from.yaw)) * math.cos(math.rad(from.pitch))
	local dy = math.cos(math.rad(to.yaw)) * math.cos(math.rad(to.pitch))
		- math.cos(math.rad(from.yaw)) * math.cos(math.rad(from.pitch))
	local dz = math.sin(math.rad(to.pitch)) - math.sin(math.rad(from.pitch))

	return math.deg(math.acos(math.max(-1, math.min(1, 1 - (dx * dx + dy * dy + dz * dz) / 2))))
end

-- Calculate angle to position
local function angleToPosition(fromPos, toPos)
	local delta = toPos - fromPos
	local hyp = math.sqrt(delta.x * delta.x + delta.y * delta.y)
	local yaw = math.deg(math.atan(delta.y, delta.x))
	local pitch = math.deg(math.atan(-delta.z, hyp))
	return { pitch = pitch, yaw = yaw, roll = 0 }
end

-- Add angle to history
local function addAngleHistory(idx, angles, tick, shotFired)
	if not playerAngleHistory[idx] then
		playerAngleHistory[idx] = {}
	end

	table.insert(playerAngleHistory[idx], {
		pitch = angles.pitch,
		yaw = angles.yaw,
		roll = angles.roll or 0,
		tick = tick,
		shotFired = shotFired or false,
	})

	while #playerAngleHistory[idx] > CONFIG.MAX_HISTORY_SIZE do
		table.remove(playerAngleHistory[idx], 1)
	end
end

-- Add position to history
local function addPosHistory(idx, headPos, bodyPos, tick)
	if not playerPosHistory[idx] then
		playerPosHistory[idx] = {}
	end

	table.insert(playerPosHistory[idx], {
		headPos = headPos,
		bodyPos = bodyPos,
		tick = tick,
	})

	while #playerPosHistory[idx] > CONFIG.POS_HISTORY_SIZE do
		table.remove(playerPosHistory[idx], 1)
	end
end

-- Check for silent aimbot using angle extrapolation
local function checkSilentAimbot(shooterIdx, victimIdx, currentAngles)
	local history = playerAngleHistory[shooterIdx]
	if not history or #history < 3 then
		return false, 0, nil -- Not enough history
	end

	local victimPosHistory = playerPosHistory[victimIdx]
	if not victimPosHistory or #victimPosHistory == 0 then
		return false, 0, nil -- No victim position data
	end

	-- Get victim position (head preferred)
	local victimPos = victimPosHistory[#victimPosHistory].headPos or victimPosHistory[#victimPosHistory].bodyPos
	if not victimPos then
		return false, 0, nil
	end

	-- Find the tick when shot was fired
	local shotIdx = nil
	for i = #history, 1, -1 do
		if history[i].shotFired then
			shotIdx = i
			break
		end
	end

	if not shotIdx or shotIdx < 2 then
		return false, 0, nil -- No shot found or not enough pre-shot history
	end

	-- Use quaternion extrapolation to predict where they SHOULD be looking
	local predicted = Quaternion.extrapolateAngle(history, CONFIG.EXTRAPOLATE_TICKS)
	if not predicted then
		return false, 0, nil
	end

	-- Calculate angle to victim
	local shooterPos = playerPosHistory[shooterIdx]
		and playerPosHistory[shooterIdx][#playerPosHistory[shooterIdx]]
		and playerPosHistory[shooterIdx][#playerPosHistory[shooterIdx]].headPos
	if not shooterPos then
		return false, 0, nil
	end

	local angleToVictim = angleToPosition(shooterPos, victimPos)

	-- Check how close their view was to victim when they shot
	local shotAngles = history[shotIdx]
	local fovToVictim = angleFoV(shotAngles, angleToVictim)

	-- Check deviation from predicted trajectory
	local fovFromPredicted = angleFoV(shotAngles, predicted)

	-- Detection logic:
	-- 1. IMPOSSIBLE: Shot at target behind them (90°+ from predicted trajectory)
	if fovFromPredicted >= CONFIG.IMPOSSIBLE_FLICK then
		return true, 1.0, "Impossible flick (shot behind)"
	end

	-- 2. SILENT AIM: Perfect aim but trajectory was broken
	if fovToVictim < CONFIG.PERFECT_AIM_TOLERANCE and fovFromPredicted > CONFIG.TRAJECTORY_BROKEN then
		local confidence = math.min(1.0, fovFromPredicted / CONFIG.IMPOSSIBLE_FLICK)
		return true,
			confidence,
			string.format("Silent aim (%.1f° snap, %.1f° from predicted)", fovToVictim, fovFromPredicted)
	end

	-- 3. FLICK CHECK: Big flick to target that instantly returns
	local postShotIdx = shotIdx + 1
	if postShotIdx <= #history then
		local postShotAngles = history[postShotIdx]
		local postFov = angleFoV(shotAngles, postShotAngles)

		-- Shot was accurate AND instantly returned to trajectory
		if fovToVictim < CONFIG.PERFECT_AIM_TOLERANCE and postFov > CONFIG.MIN_FLICK_DELTA then
			local confidence = math.min(1.0, postFov / CONFIG.TRAJECTORY_BROKEN)
			return true,
				confidence * 0.7,
				string.format("Snap-back (%.1f° accuracy, %.1f° return)", fovToVictim, postFov)
		end
	end

	return false, 0, nil
end

function SilentAimbot.Check(player)
	-- Skip if detection disabled
	if not G.Menu.Advanced or not G.Menu.Advanced.SilentAimbot then
		return false
	end

	-- Validate player
	if not Common.IsValidPlayer(player, true, false) then
		return false
	end

	local steamID = Common.GetSteamID64(player)
	if not Common.IsSteamID64(steamID) then
		return false
	end
	steamID = tostring(steamID)

	if Evidence.IsMarkedCheater(steamID) then
		return false
	end

	local playerIdx = player:GetIndex()
	local currentTick = globals.TickCount()
	local eyeAngles = player:GetEyeAngles()
	local headPos = player:GetHitboxPos(1)
	local bodyPos = player:GetAbsOrigin()

	-- Update position history
	addPosHistory(playerIdx, headPos, bodyPos, currentTick)

	-- Check if last tick was a shot
	local isAimbot, confidence, reason = false, 0, nil
	if lastShot.shooter == playerIdx and lastShot.tick == (currentTick - 1) then
		if G.Menu.Advanced.debug then
			print(
				string.format("[SilentAim] Checking player %s (idx %d) who shot last tick", player:GetName(), playerIdx)
			)
		end
		isAimbot, confidence, reason = checkSilentAimbot(playerIdx, lastShot.victim, eyeAngles)
	end

	-- Add current angle to history
	addAngleHistory(playerIdx, eyeAngles, currentTick, false)

	-- Add evidence if detected
	if isAimbot then
		local weight = (confidence >= 1.0) and EVIDENCE_WEIGHT_IMPOSSIBLE or EVIDENCE_WEIGHT_BASE
		Evidence.AddEvidence(steamID, DETECTION_NAME, weight * confidence)

		if G.Menu.Advanced.debug then
			print(string.format("[SilentAim] %s - %s (confidence: %.0f%%)", player:GetName(), reason, confidence * 100))
		end

		return true
	end

	return false
end

-- Event handler for player_hurt (called from Main.lua event handler)
function SilentAimbot.OnPlayerHurt(shooterEntity, victimEntity)
	if not shooterEntity or not victimEntity then
		return
	end

	local shooterIdx = shooterEntity:GetIndex()
	local victimIdx = victimEntity:GetIndex()

	lastShot.shooter = shooterIdx
	lastShot.victim = victimIdx
	lastShot.tick = globals.TickCount()

	if G and G.Menu and G.Menu.Advanced and G.Menu.Advanced.debug then
		print(
			string.format(
				"[SilentAim] OnPlayerHurt: shooter idx=%d, victim idx=%d, tick=%d",
				shooterIdx,
				victimIdx,
				lastShot.tick
			)
		)
	end

	-- Flag the last tick in history as a shot
	if playerAngleHistory[shooterIdx] and #playerAngleHistory[shooterIdx] > 0 then
		playerAngleHistory[shooterIdx][#playerAngleHistory[shooterIdx]].shotFired = true
		if G and G.Menu and G.Menu.Advanced and G.Menu.Advanced.debug then
			print(
				string.format(
					"[SilentAim] Flagged tick %d as shot for idx %d (history size: %d)",
					playerAngleHistory[shooterIdx][#playerAngleHistory[shooterIdx]].tick,
					shooterIdx,
					#playerAngleHistory[shooterIdx]
				)
			)
		end
	end
end

return SilentAimbot

end)
__bundle_register("Cheater_Detection.Utils.Quaternion", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    Quaternion Math Utilities
    For angle extrapolation and aimbot detection
]]

local Quaternion = {}

-- ============================================================================
-- Core Quaternion Functions
-- ============================================================================

-- Create a new quaternion
function Quaternion.new(w, x, y, z)
	return { w = w or 1, x = x or 0, y = y or 0, z = z or 0 }
end

-- Convert Euler angles (pitch, yaw, roll) to Quaternion
-- Angles are in degrees
-- NOTE: Negates pitch to match Source engine conventions
function Quaternion.fromEuler(pitch, yaw, roll)
	local p = math.rad(-pitch) * 0.5 -- Negate for Source engine
	local y = math.rad(yaw) * 0.5
	local r = math.rad(roll) * 0.5

	local cy = math.cos(y)
	local sy = math.sin(y)
	local cp = math.cos(p)
	local sp = math.sin(p)
	local cr = math.cos(r)
	local sr = math.sin(r)

	return Quaternion.new(
		cr * cp * cy + sr * sp * sy, -- w
		sr * cp * cy - cr * sp * sy, -- x
		cr * sp * cy + sr * cp * sy, -- y
		cr * cp * sy - sr * sp * cy -- z
	)
end

-- Convert Quaternion to Euler angles (pitch, yaw, roll)
-- Returns angles in degrees
-- NOTE: Negates pitch to match Source engine conventions
function Quaternion.toEuler(q)
	local len = math.sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z)
	if len < 0.0001 then
		return 0, 0, 0
	end

	local w, x, y, z = q.w / len, q.x / len, q.y / len, q.z / len

	-- Roll
	local sinr_cosp = 2 * (w * x + y * z)
	local cosr_cosp = 1 - 2 * (x * x + y * y)
	local roll = math.atan(sinr_cosp, cosr_cosp)

	-- Pitch
	local sinp = 2 * (w * y - z * x)
	local pitch
	if math.abs(sinp) >= 1 then
		pitch = math.pi / 2 * (sinp < 0 and -1 or 1)
	else
		pitch = math.asin(sinp)
	end

	-- Yaw
	local siny_cosp = 2 * (w * z + x * y)
	local cosy_cosp = 1 - 2 * (y * y + z * z)
	local yaw = math.atan(siny_cosp, cosy_cosp)

	return -math.deg(pitch), math.deg(yaw), math.deg(roll) -- Negate pitch
end

-- Normalize a quaternion
function Quaternion.normalize(q)
	local len = math.sqrt(q.w * q.w + q.x * q.x + q.y * q.y + q.z * q.z)
	if len < 0.0001 then
		return Quaternion.new(1, 0, 0, 0)
	end
	return Quaternion.new(q.w / len, q.x / len, q.y / len, q.z / len)
end

-- Multiply two quaternions
function Quaternion.multiply(q1, q2)
	return Quaternion.new(
		q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z,
		q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
		q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
		q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w
	)
end

-- Spherical Linear Interpolation (SLERP)
function Quaternion.slerp(q1, q2, t)
	local dot = q1.w * q2.w + q1.x * q2.x + q1.y * q2.y + q1.z * q2.z

	-- Take shorter path
	local q2_copy = { w = q2.w, x = q2.x, y = q2.y, z = q2.z }
	if dot < 0 then
		q2_copy.w = -q2_copy.w
		q2_copy.x = -q2_copy.x
		q2_copy.y = -q2_copy.y
		q2_copy.z = -q2_copy.z
		dot = -dot
	end

	-- Use linear interpolation for very close quaternions
	if dot > 0.9995 then
		return Quaternion.normalize(
			Quaternion.new(
				q1.w + t * (q2_copy.w - q1.w),
				q1.x + t * (q2_copy.x - q1.x),
				q1.y + t * (q2_copy.y - q1.y),
				q1.z + t * (q2_copy.z - q1.z)
			)
		)
	end

	dot = math.max(-1, math.min(1, dot))
	local theta = math.acos(dot)
	local sinTheta = math.sin(theta)
	local w1 = math.sin((1 - t) * theta) / sinTheta
	local w2 = math.sin(t * theta) / sinTheta

	return Quaternion.new(
		q1.w * w1 + q2_copy.w * w2,
		q1.x * w1 + q2_copy.x * w2,
		q1.y * w1 + q2_copy.y * w2,
		q1.z * w1 + q2_copy.z * w2
	)
end

-- ============================================================================
-- Helper Functions
-- ============================================================================

-- Calculate quaternion delta (rotation from q1 to q2)
local function quaternionDelta(q1, q2)
	local conj_q1 = { w = q1.w, x = -q1.x, y = -q1.y, z = -q1.z }
	return Quaternion.multiply(q2, conj_q1)
end

-- ============================================================================
-- Angle Extrapolation
-- ============================================================================

-- Extrapolate angles based on history
-- angleHistory: array of {pitch, yaw, roll} tables (at least 3 required)
-- ticksAhead: how many ticks to predict (default 1)
-- Returns: predicted {pitch, yaw, roll} or nil
function Quaternion.extrapolateAngle(angleHistory, ticksAhead)
	ticksAhead = ticksAhead or 1

	if #angleHistory < 3 then
		return nil -- Need at least 3 points
	end

	-- Convert last 3 Euler angles to quaternions
	local q3 = Quaternion.fromEuler(
		angleHistory[#angleHistory].pitch,
		angleHistory[#angleHistory].yaw,
		angleHistory[#angleHistory].roll or 0
	)
	local q2 = Quaternion.fromEuler(
		angleHistory[#angleHistory - 1].pitch,
		angleHistory[#angleHistory - 1].yaw,
		angleHistory[#angleHistory - 1].roll or 0
	)
	local q1 = Quaternion.fromEuler(
		angleHistory[#angleHistory - 2].pitch,
		angleHistory[#angleHistory - 2].yaw,
		angleHistory[#angleHistory - 2].roll or 0
	)

	-- Calculate velocity quaternions
	local vel1 = quaternionDelta(q1, q2)
	local vel2 = quaternionDelta(q2, q3)

	-- Average velocities for smoother prediction
	local avgVel = Quaternion.slerp(vel1, vel2, 0.5)

	-- Extrapolate tick by tick
	local result = q3
	for i = 1, ticksAhead do
		result = Quaternion.multiply(avgVel, result)
		result = Quaternion.normalize(result)
	end

	-- Convert back to Euler
	local pitch, yaw, roll = Quaternion.toEuler(result)
	return { pitch = pitch, yaw = yaw, roll = roll }
end

return Quaternion

end)
__bundle_register("Cheater_Detection.Core.Evidence_system", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Evidence System - Weight-based cheater detection with context-aware decay ]]
--
-- Categories:
--   Aim: Context-aware decay (looking at enemies, damage dealt, distance)
--   Exploit: Time-based decay (doubletap, recharge, fakelag, anti-aim)
--   Movement: Time-based decay (bhop, strafe, duck speed)

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local FastPlayers = require("Cheater_Detection.Utils.FastPlayers")
local PlayerState = require("Cheater_Detection.Utils.PlayerState")
local Database = require("Cheater_Detection.Database.Database")
local Logger = require("Cheater_Detection.Utils.Logger")

--[[ Module Declaration ]]
local Evidence = {}

--[[ Configuration ]]
Evidence.Config = {
	-- Decay rates per second
	DecayRates = {
		Aim = {
			default = 1.0, -- Base decay per second
			lookingAtEnemy = 2.0, -- Extra decay when looking at enemy
			hurtingEnemy = 3.0, -- Extra decay when dealing damage
			closeAim = 1.5, -- Extra decay when aiming close to enemy
		},
		Exploit = {
			default = 0.5, -- Slow decay for exploits
		},
		Movement = {
			default = 0.8, -- Medium decay for movement
		},
	},

	-- Thresholds
	MarkAsCheatThreshold = 100, -- Total weight to mark as cheater
	MinWeightFloor = 0, -- Cannot decay below this

	-- Category mappings (only implemented detections)
	Categories = {
		-- Aim detection methods
		Aim = {
			"silent_aimbot",
		},
		-- Exploit detection methods
		Exploit = {
			"warp_dt",
			"fake_lag",
			"anti_aim",
			"manual_priority",
		},
		-- Movement detection methods
		Movement = {
			"bhop",
			"Duck_Speed",
		},
	},
}

--[[ Private Variables ]]
local TICKS_PER_SECOND = 66 -- TF2 tickrate
local DECAY_BATCHES_PER_CYCLE = 6
local DECAY_INTERVAL_TICKS = math.max(1, math.floor(TICKS_PER_SECOND / DECAY_BATCHES_PER_CYCLE))
local DECAY_SECONDS_PER_BATCH = 1 / DECAY_BATCHES_PER_CYCLE
local lastDecayTick = 0 -- Simple tick-based rate limiting

local decayQueue = {}
local decayQueueIndex = {}
local decayCursor = 1
local decayQueueDirty = true

local DetectionToggles = {
	anti_aim = "AntyAim",
	bhop = "Bhop",
	fake_lag = "Choke", -- Choke = Fake Lag in config
	warp_dt = "Warp",
	Duck_Speed = "DuckSpeed",
	silent_aimbot = "SilentAimbot",
	manual_priority = "AutoFlagPriorityTen",
}

local function clearArray(tbl)
	for i = #tbl, 1, -1 do
		tbl[i] = nil
	end
end

local function clearMap(tbl)
	for key in pairs(tbl) do
		tbl[key] = nil
	end
end

local function isDetectionEnabled(detectionName)
	local menu = G.Menu and G.Menu.Advanced
	if not menu then
		return true
	end
	local key = DetectionToggles[detectionName]
	if not key then
		return true
	end
	local flag = menu[key]
	return flag ~= false
end

local function refreshDecayQueue()
	clearArray(decayQueue)
	clearMap(decayQueueIndex)
	decayCursor = 1
	decayQueueDirty = false

	if not PlayerState or not PlayerState.GetTable then
		return
	end

	for steamID, state in pairs(PlayerState.GetTable()) do
		if state and state.Evidence and state.Evidence.Reasons and next(state.Evidence.Reasons) ~= nil then
			decayQueue[#decayQueue + 1] = steamID
			decayQueueIndex[steamID] = true
		end
	end
end

local function markDecayQueueDirty()
	decayQueueDirty = true
end

local function ensureDecayQueue()
	if decayQueueDirty then
		refreshDecayQueue()
	end
end

local function enqueueForDecay(steamID)
	if not steamID then
		return
	end

	steamID = tostring(steamID)
	if decayQueueIndex[steamID] then
		return
	end

	decayQueue[#decayQueue + 1] = steamID
	decayQueueIndex[steamID] = true
end

local function removeFromDecayQueue(steamID)
	if not steamID then
		return
	end
	steamID = tostring(steamID)
	if not decayQueueIndex[steamID] then
		return
	end
	decayQueueIndex[steamID] = nil
	markDecayQueueDirty()
end

--[[ Helper Functions ]]

-- Get category for a detection method
local function getCategory(detectionName)
	for category, methods in pairs(Evidence.Config.Categories) do
		for _, method in ipairs(methods) do
			if method == detectionName then
				return category
			end
		end
	end
	return "Movement" -- Default fallback
end

local function getOrCreateEvidence(steamID)
	if not PlayerState then
		return nil, nil
	end
	local state = PlayerState.GetOrCreate(steamID)
	if not state then
		return nil, nil
	end
	state.Evidence = state.Evidence
		or {
			TotalScore = 0,
			LastUpdateTick = globals.TickCount(),
			Reasons = {},
			MarkedAsCheater = false,
		}
	return state.Evidence, state
end

local function initPlayerEvidence(steamID)
	return getOrCreateEvidence(steamID)
end

local function recalcTotalScore(evidence)
	local total = 0
	for _, reason in pairs(evidence.Reasons) do
		total = total + reason.Weight
	end
	evidence.TotalScore = total
	evidence.LastUpdateTick = globals.TickCount()
end

local function applyReasonOptions(reason, opts)
	if not reason or not opts then
		return
	end
	if opts.manualDecay ~= nil then
		reason.ManualDecay = opts.manualDecay == true
	end
	if opts.decayRate then
		reason.DecayRate = opts.decayRate
	end
end

local function getCategoryDecayRate(category)
	category = category or "Movement"
	local rates = Evidence.Config.DecayRates
	if category == "Aim" then
		return (rates.Aim and rates.Aim.default) or 0
	elseif category == "Exploit" then
		return (rates.Exploit and rates.Exploit.default) or 0
	elseif category == "Movement" then
		return (rates.Movement and rates.Movement.default) or 0
	end
	return 0
end

--[[ Public Functions ]]

--- Get the current evidence threshold from menu
---@return number Current threshold value
function Evidence.GetThreshold()
	return G.Menu.Advanced.Evicence_Tolerance or Evidence.Config.MarkAsCheatThreshold
end

--- Try to mark player as cheater if threshold is exceeded
---@param steamID string Player's SteamID64
---@param evidence table Evidence data
---@param state table Player state
local function tryMarkCheater(steamID, evidence, state)
	if not evidence or evidence.MarkedAsCheater then
		return
	end

	local threshold = Evidence.GetThreshold()

	if evidence.TotalScore < threshold then
		return
	end

	evidence.MarkedAsCheater = true
	state = state or select(2, getOrCreateEvidence(steamID)) or {}
	state.info = state.info or {}
	state.info.IsCheater = true

	-- Use name from state.info (already populated by PlayerState.AttachWrappedPlayer)
	local playerName = (state.info and state.info.Name) or "Unknown"

	-- Fallback: search FastPlayers if name not in state (don't exclude local player)
	if playerName == "Unknown" then
		local allPlayers = FastPlayers.GetAll(false)
		for _, player in ipairs(allPlayers) do
			if tostring(player:GetSteamID64()) == steamID then
				local name = player.GetName and player:GetName()
				if name and name ~= "" then
					playerName = name
					-- Update state for future use
					if state.info then
						state.info.Name = name
					end
				end
				break
			end
		end
	end

	local primaryReason = "Cheater"
	local maxWeight = 0
	for detectionName, reasonData in pairs(evidence.Reasons) do
		if reasonData.Weight > maxWeight then
			maxWeight = reasonData.Weight
			local reasonMap = {
				["anti_aim"] = "Anti-Aim",
				["bhop"] = "Bhop",
				["fake_lag"] = "Fake Lag",
				["warp_dt"] = "Warp/Doubletap",
				["Duck_Speed"] = "Duck Speed",
				["silent_aimbot"] = "Silent Aimbot",
				["manual_priority"] = "Manual Priority",
			}
			primaryReason = reasonMap[detectionName] or detectionName
		end
	end

	Database.UpsertCheater(steamID, {
		name = playerName,
		reason = primaryReason,
		proof = "Evidence System",
		evidenceScore = evidence.TotalScore,
		reasons = evidence.Reasons,
		firstSeen = os.time(),
		lastSeen = os.time(),
	})

	-- Immediate save after marking cheater (critical moment, prevents data loss)
	Database.SaveDatabase()

	-- Set priority 10 if AutoPriority enabled
	if G.Menu.Main and G.Menu.Main.AutoPriority then
		Evidence.SetPriorityForSteamID(steamID, 10)
	end

	if G.Menu.Advanced.debug then
		print(
			string.format(
				"[Evidence] MARKED %s as cheater (Score: %.1f >= %.1f) - Saved to database",
				playerName,
				evidence.TotalScore,
				threshold
			)
		)
	end
end

--- Add evidence weight for a specific detection
---@param steamID string Player's SteamID64
---@param detectionName string Detection method name
---@param weight number Weight to add
function Evidence.AddEvidence(steamID, detectionName, weight, opts)
	if not steamID or not detectionName or not weight then
		return
	end

	-- Convert to string and validate SteamID64 format
	steamID = tostring(steamID)

	-- SteamID64 must be 17 digits starting with 7656119 (valid Steam accounts)
	-- Silently skip bots/invalid IDs (they won't match this pattern)
	if not steamID:match("^7656119%d+$") or #steamID ~= 17 then
		return -- Skip silently (bots return UserID instead of SteamID64)
	end

	-- Skip local player unless debug mode is enabled
	if not G.Menu.Advanced.debug then
		local localPlayer = entities.GetLocalPlayer()
		if localPlayer then
			local localSteamID = Common.GetSteamID64(localPlayer)
			if localSteamID and tostring(localSteamID) == steamID then
				return -- Skip local player
			end
		end
	end

	-- Debug: Log successful evidence add
	Logger.Debug("Evidence", string.format("Adding %.1f evidence for %s (method: %s)", weight, steamID, detectionName))

	local evidence, state = getOrCreateEvidence(steamID)
	if not evidence then
		return
	end

	-- Initialize detection stack if needed
	if not evidence.Reasons[detectionName] then
		evidence.Reasons[detectionName] = {
			Weight = 0,
			Category = getCategory(detectionName),
			LastAddedTick = globals.TickCount(),
		}
	end
	applyReasonOptions(evidence.Reasons[detectionName], opts)

	-- Add weight
	evidence.Reasons[detectionName].Weight = evidence.Reasons[detectionName].Weight + weight
	evidence.Reasons[detectionName].LastAddedTick = globals.TickCount()
	evidence.Dirty = true

	-- Recalculate total and check if player should be marked
	recalcTotalScore(evidence)

	tryMarkCheater(steamID, evidence, state)

	enqueueForDecay(steamID)
end

local function processEvidenceState(steamID, state, deltaTime)
	if not state or not state.Evidence then
		return false
	end
	local evidence = state.Evidence
	if not evidence.Reasons or next(evidence.Reasons) == nil then
		evidence.Dirty = false
		return false
	end

	local changed = false
	local minFloor = Evidence.Config.MinWeightFloor or 0
	local toRemove = {}
	local hasReasons = false

	if deltaTime > 0 then
		for detectionName, reason in pairs(evidence.Reasons) do
			local detectionEnabled = isDetectionEnabled(detectionName)
			if detectionEnabled and reason.ManualDecay ~= true and reason.Weight > minFloor then
				local rate = reason.DecayRate or getCategoryDecayRate(reason.Category)
				if rate > 0 then
					local newWeight = math.max(minFloor, reason.Weight - rate * deltaTime)
					if newWeight ~= reason.Weight then
						reason.Weight = newWeight
						changed = true
					end
				end
			end

			if reason.ManualDecay ~= true and reason.Weight <= minFloor then
				toRemove[#toRemove + 1] = detectionName
			else
				hasReasons = true
			end
		end
	else
		hasReasons = true
	end

	for _, detectionName in ipairs(toRemove) do
		evidence.Reasons[detectionName] = nil
		changed = true
	end

	if evidence.Dirty or changed then
		recalcTotalScore(evidence)
		evidence.Dirty = false
		tryMarkCheater(steamID, evidence, state)
	end

	return hasReasons and next(evidence.Reasons) ~= nil
end

local function processDecayBatch()
	ensureDecayQueue()
	local queueSize = #decayQueue
	if queueSize == 0 then
		return
	end

	local batchSize = math.max(1, math.ceil(queueSize / DECAY_BATCHES_PER_CYCLE))
	local processed = 0

	while processed < batchSize and queueSize > 0 do
		if decayCursor > queueSize then
			decayCursor = 1
			queueSize = #decayQueue
			if queueSize == 0 then
				break
			end
		end

		local steamID = decayQueue[decayCursor]
		decayCursor = decayCursor + 1
		if steamID then
			local state = PlayerState and PlayerState.Get and PlayerState.Get(steamID)
			if state and state.Evidence and state.Evidence.Reasons and next(state.Evidence.Reasons) ~= nil then
				local hasReasons = processEvidenceState(steamID, state, DECAY_SECONDS_PER_BATCH)
				if not hasReasons then
					removeFromDecayQueue(steamID)
				end
			else
				removeFromDecayQueue(steamID)
			end
		end
		processed = processed + 1
	end
end

--- Apply decay to all players (called per tick, internally rate-limited)
function Evidence.ApplyDecay()
	local currentTick = globals.TickCount()
	if currentTick - lastDecayTick >= DECAY_INTERVAL_TICKS then
		lastDecayTick = currentTick
		processDecayBatch()
	end
end

--- Check if player is marked as cheater (for detection skip optimization)
---@param steamID string Player's SteamID64
---@return boolean True if player is confirmed cheater
function Evidence.IsMarkedCheater(steamID)
	if not steamID then
		return false
	end

	-- Ensure steamID is a string
	-- steamID = tostring(steamID) -- Use raw key

	-- Check database first (known cheater lists)
	if G.DataBase[steamID] then
		return true
	end

	-- Check if marked by evidence system
	if G.PlayerData[steamID] and G.PlayerData[steamID].Evidence then
		return G.PlayerData[steamID].Evidence.MarkedAsCheater
	end

	-- Check playerlist priority
	local priority = playerlist.GetPriority(steamID)
	if priority == 10 then
		return true
	end

	if PlayerState then
		local state = PlayerState.Get(steamID)
		if state and state.Evidence then
			return state.Evidence.MarkedAsCheater == true
		end
	end

	return false
end

--- Apply decay to a specific detection method for a player
---@param steamID string Player's SteamID64
---@param detectionName string Detection method name
---@param decayAmount number Amount to decay
function Evidence.ApplyDecayForMethod(steamID, detectionName, decayAmount)
	if not steamID or not detectionName or not decayAmount then
		return
	end

	-- Convert to string and validate SteamID64 format
	steamID = tostring(steamID)

	if not steamID:match("^7656119%d+$") or #steamID ~= 17 then
		return
	end

	initPlayerEvidence(steamID)

	local evidence, state = getOrCreateEvidence(steamID)
	if not evidence then
		return
	end

	-- Initialize detection stack if needed
	if not evidence.Reasons[detectionName] then
		evidence.Reasons[detectionName] = {
			Weight = 0,
			Category = getCategory(detectionName),
			LastAddedTick = globals.TickCount(),
		}
	end
	local reason = evidence.Reasons[detectionName]
	reason.ManualDecay = true

	-- Apply decay (minimum 0)
	local oldWeight = reason.Weight
	reason.Weight = math.max(0, reason.Weight - decayAmount)

	-- Recalculate total if changed
	if oldWeight ~= reason.Weight then
		evidence.Dirty = true
		recalcTotalScore(evidence)
		enqueueForDecay(steamID)
		tryMarkCheater(steamID, evidence, state)

		-- Debug: Log decay
		Logger.Debug(
			"Evidence",
			string.format(
				"Decayed %.1f evidence for %s (method: %s, old: %.1f, new: %.1f)",
				decayAmount,
				steamID,
				detectionName,
				oldWeight,
				evidence.Reasons[detectionName].Weight
			)
		)
	end
end

--- Get current evidence score for a player
---@param steamID string Player's SteamID64
---@return number Total evidence score
function Evidence.GetScore(steamID)
	if not steamID then
		return 0
	end

	-- Ensure steamID is a string
	steamID = tostring(steamID)

	if not G.PlayerData[steamID] or not G.PlayerData[steamID].Evidence then
		return 0
	end

	return G.PlayerData[steamID].Evidence.TotalScore or 0
end

--- Get current evidence weight for a specific detection method
---@param steamID string Player's SteamID64
---@param detectionName string Detection method name
---@return number Current weight for this method
function Evidence.GetMethodWeight(steamID, detectionName)
	if not steamID or not detectionName then
		return 0
	end

	-- Ensure steamID is a string
	steamID = tostring(steamID)

	if
		not G.PlayerData[steamID]
		or not G.PlayerData[steamID].Evidence
		or not G.PlayerData[steamID].Evidence.Reasons
	then
		return 0
	end

	local methodData = G.PlayerData[steamID].Evidence.Reasons[detectionName]
	if not methodData then
		return 0
	end

	return methodData.Weight or 0
end

--- Get detailed evidence breakdown for a player
---@param steamID string Player's SteamID64
---@return table Evidence details
function Evidence.GetDetails(steamID)
	if not steamID then
		return nil
	end

	-- Ensure steamID is a string
	steamID = tostring(steamID)

	if not G.PlayerData[steamID] or not G.PlayerData[steamID].Evidence then
		return nil
	end

	return G.PlayerData[steamID].Evidence
end

--- Clean up player data when they leave (centralized black box)
---@param steamID string Player's SteamID64
function Evidence.OnPlayerLeave(steamID)
	-- Clean up evidence data
	if G.PlayerData[steamID] then
		G.PlayerData[steamID] = nil
	end
	removeFromDecayQueue(steamID)

	-- Detection module data cleanup is handled by script unload
	-- Individual modules' local data structures are cleaned up automatically
end

--- Set playerlist priority for a player by SteamID
---@param steamID string Player's SteamID64
---@param priority number Priority level to set (10 = cheater)
function Evidence.SetPriorityForSteamID(steamID, priority)
	if not steamID then
		return false
	end
	steamID = tostring(steamID)

	local allPlayers = FastPlayers.GetAll(false)
	for _, player in ipairs(allPlayers) do
		if tostring(player:GetSteamID64()) == steamID then
			local entity = player:GetRawEntity()
			if entity then
				local success = pcall(playerlist.SetPriority, entity, priority)
				if success then
					Logger.Info(
						"Evidence",
						string.format("Set priority %d for %s", priority, player:GetName() or steamID)
					)
					return true
				end
			end
			break
		end
	end
	return false
end

return Evidence

end)
__bundle_register("Cheater_Detection.Utils.Logger", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Logger System ]]

local G = require("Cheater_Detection.Utils.Globals")

local Logger = {}

-- Log levels
Logger.Levels = {
	DEBUG = 1,   -- Detailed debug info (off by default)
	INFO = 2,    -- General info (detections, database saves)
	WARNING = 3, -- Warnings
	ERROR = 4,   -- Errors
}

-- Color codes (RGBA)
local Colors = {
	DEBUG = {170, 170, 170, 255},   -- Gray
	INFO = {153, 204, 255, 255},    -- Light blue
	WARNING = {255, 170, 0, 255},   -- Orange
	ERROR = {255, 68, 68, 255},     -- Red
}

--- Check if log level is enabled
---@param level number Log level to check
---@return boolean
local function isLevelEnabled(level)
	if not G.Menu or not G.Menu.Advanced or not G.Menu.Advanced.LogLevel then
		return level >= Logger.Levels.INFO -- Default: INFO and above
	end
	
	-- Convert boolean table to level number: [Debug, Info, Warning, Error]
	local logLevelTable = G.Menu.Advanced.LogLevel
	local enabledLevel = Logger.Levels.INFO -- Default
	
	if type(logLevelTable) == "table" then
		for i = 1, 4 do
			if logLevelTable[i] then
				enabledLevel = i
				break
			end
		end
	elseif type(logLevelTable) == "number" then
		enabledLevel = logLevelTable
	end
	
	return level >= enabledLevel
end

--- Log a message with specified level
---@param level number Log level (Logger.Levels.X)
---@param category string Category/module name
---@param message string Message to log
function Logger.Log(level, category, message)
	if not isLevelEnabled(level) then
		return
	end
	
	local levelName = ""
	local color = nil
	
	if level == Logger.Levels.DEBUG then
		levelName = "DEBUG"
		color = Colors.DEBUG
	elseif level == Logger.Levels.INFO then
		levelName = "INFO"
		color = Colors.INFO
	elseif level == Logger.Levels.WARNING then
		levelName = "WARN"
		color = Colors.WARNING
	elseif level == Logger.Levels.ERROR then
		levelName = "ERROR"
		color = Colors.ERROR
	end
	
	if color then
		printc(color[1], color[2], color[3], color[4], string.format("[%s] [%s] %s", levelName, category, message))
	else
		print(string.format("[%s] [%s] %s", levelName, category, message))
	end
end

--- Convenience functions
function Logger.Debug(category, message)
	Logger.Log(Logger.Levels.DEBUG, category, message)
end

function Logger.Info(category, message)
	Logger.Log(Logger.Levels.INFO, category, message)
end

function Logger.Warning(category, message)
	Logger.Log(Logger.Levels.WARNING, category, message)
end

function Logger.Error(category, message)
	Logger.Log(Logger.Levels.ERROR, category, message)
end

return Logger

end)
__bundle_register("Cheater_Detection.Utils.Globals", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Imports first --]]
local G = {}
G.Menu = require("Cheater_Detection.Utils.DefaultConfig")

G.AutoVote = {
	Options = { "Yes", "No" },
	VoteCommand = "vote",
	VoteIdx = nil,
	VoteValue = nil, -- Set this to 1 for yes, 2 for no, or nil for off
}

--[[Shared Variables]]

-- G.PlayerData is initialized by PlayerState.lua (line 14)
-- It's an alias for PlayerState.ActivePlayers

return G

end)
__bundle_register("Cheater_Detection.Utils.DefaultConfig", function(require, _LOADED, __bundle_register, __bundle_modules)
local Default_Config = {
	currentTab = "Main",

	Main = {
		Fetch_Database = true,
		AutoPriority = true, -- Auto set priority 10 on detected cheaters
		AutoFetch = true, -- Automatically fetch database on startup
		LastFetchTimestamp = 0,
		partyCallaut = true,
		Chat_Prefix = true,
		Cheater_Tags = true,
	},

	Advanced = {
		Evicence_Tolerance = 100, -- Evidence score threshold to mark as cheater
		LogLevel = { false, true, false, false }, -- [Debug, Info, Warning, Error] (default: Info)
		debug = false, -- Debug mode (removes self from database, enables verbose logging)
		-- Detection toggles (only for implemented detections)
		Choke = true, -- Fake Lag detection
		Warp = true, -- Warp/DT detection
		Bhop = true, -- Bunny hop detection
		DuckSpeed = true, -- Duck speed detection
		AntyAim = true, -- Anti-aim detection
		SilentAimbot = true, -- Silent aimbot (extrapolation) detection
	},

	Misc = {
		Autovote = true,
		AutovoteAutoCast = true,
		intent = {
			legit = true,
			cheater = true,
			bot = true,
			valve = true,
			friend = false,
		},
		Vote_Reveal = {
			Enable = true,
			TargetTeam = {
				MyTeam = true,
				enemyTeam = true,
			},
			Output = {
				PublicChat = false,
				PartyChat = true,
				ClientChat = true,
				Console = true,
			},
		},
		Class_Change_Reveal = {
			Enable = false,
			EnemyOnly = true,
			Output = {
				PublicChat = false,
				PartyChat = true,
				ClientChat = true,
				Console = true,
			},
		},
		Chat_notify = true,
		JoinNotifications = {
			Enable = true,
			CheckCheater = true,
			CheckValve = true,
			ValveAutoDisconnect = false,
			-- Default output channels (used if no override)
			DefaultOutput = {
				PublicChat = false,
				PartyChat = false,
				ClientChat = true,
				Console = true,
			},
			-- Cheater-specific overrides
			UseCheaterOverride = false,
			CheaterOverride = {
				PublicChat = false,
				PartyChat = false,
				ClientChat = true,
				Console = true,
			},
			-- Valve employee-specific overrides
			UseValveOverride = false,
			ValveOverride = {
				PublicChat = false,
				PartyChat = true,
				ClientChat = true,
				Console = true,
			},
		},
		SteamHistory = {
			Enable = false,
			ApiKey = "",
		},
	},
}

return Default_Config

end)
__bundle_register("Cheater_Detection.Database.Database", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    Simplified Database.lua
    Direct implementation of database functionality using native Lua tables
    Stores only essential data: name and proof for each SteamID64
]]

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
-- [[ Imported by: Fetcher.lua (indirectly) ]]
local G = require("Cheater_Detection.Utils.Globals")
-- [[ Imported by: Fetcher.lua, Database.lua ]]
local Json = Common.Json
-- [[ Imported by: Database.lua ]]

--[[ Module Declaration ]]
local Database = {
	-- Configuration (Simplified)
	Config = {
		SaveOnExit = true,
		DebugMode = false,
		-- MaxEntries = 15000, -- Cleanup logic removed
	},

	-- State tracking (Simplified)
	State = {
		isDirty = false, -- Still potentially useful for SaveOnExit
		lastSave = 0,
		lastLoaded = 0,
		isInitialized = false,
	},
	-- Removed saveCount
}

--[[ Local Variables/Utilities ]]
local LogLevel = {
	ERROR = 1,
	WARNING = 2,
	SUCCESS = 3, -- Added Success level
	INFO = 4, -- Shifted Info down
	DEBUG = 5, -- Shifted Debug down
}

local currentLogLevel = LogLevel.INFO -- Default log level still includes SUCCESS
local showDebug = false -- Set to true to see all debug messages

--[[ Helper/Private Functions ]]
-- Log function with severity level and colors (Refactored to use Database's Log)
local function Log(level, message, color)
	-- Ensure Database and its Log function are available
	if Database and Database.Log then
		Database.Log(level, message, color)
	elseif G and G.Menu and G.Menu.Advanced and G.Menu.Advanced.debug then
		-- Fallback to plain print if Database.Log is unavailable (only in debug)
		local prefixMap =
			{ [1] = "[ERROR] ", [2] = "[WARNING] ", [3] = "[SUCCESS] ", [4] = "[INFO] ", [5] = "[DEBUG] " }
		print((prefixMap[level] or "") .. message)
	end
end

-- Save database automatically when the script unloads (if dirty)
local function DatabaseAutoSaveOnUnload()
	Log(LogLevel.DEBUG, "[DB] Unloading database, saving data...")

	-- Safety checks
	if not Database or not Database.Config or not Database.State then
		print("[DB] Database not properly initialized, skipping save on unload")
		return
	end

	if type(G.DataBase) ~= "table" then
		print("[DB] G.DataBase is not a table, initializing empty before save")
		G.DataBase = {}
	end

	-- Always save on unload to prevent data loss
	if Database.Config.SaveOnExit then
		-- If not dirty, mark as dirty temporarily to force save
		local wasDirty = Database.State.isDirty
		Database.State.isDirty = true

		Log(LogLevel.INFO, "[DB] Saving database on exit")

		-- Wrap in pcall to prevent crash
		local success, err = pcall(Database.SaveDatabase)
		if not success then
			print("[DB] ERROR saving database on unload: " .. tostring(err))
		end

		-- Restore original dirty state if it wasn't modified
		if not wasDirty then
			Database.State.isDirty = false
		end
	else
		Log(LogLevel.WARNING, "[DB] SaveOnExit disabled, skipping final save")
	end
end

--[[ Public Module Functions ]]
-- Robust SetPriority with multiple fallback methods
-- Tries: entity -> index -> SteamID64 -> SteamID3
-- For database entries (not in-game), tries: SteamID64 -> SteamID3
function Database.SetPriority(target, priority, isInGame)
	if not target then
		Log(LogLevel.ERROR, "[DB] SetPriority: target is nil")
		return false
	end

	local success = false
	local lastError = nil

	-- Method 1: Try entity (only if in-game)
	if isInGame ~= false and type(target) == "userdata" then
		success, lastError = pcall(playerlist.SetPriority, target, priority)
		if success then
			Log(LogLevel.DEBUG, string.format("[DB] SetPriority via entity: priority=%d", priority))
			return true
		end
	end

	-- Method 2: Try index (only if in-game)
	if isInGame ~= false and type(target) == "number" and target < 101 then
		success, lastError = pcall(playerlist.SetPriority, target, priority)
		if success then
			Log(LogLevel.DEBUG, string.format("[DB] SetPriority via index %d: priority=%d", target, priority))
			return true
		end
	end

	-- Method 3: Try SteamID64
	local steamID64 = nil
	if type(target) == "string" and #target == 17 then
		steamID64 = target
	elseif type(target) == "userdata" then
		-- Try to get SteamID64 from entity
		steamID64 = Common.GetSteamID64(target)
	end

	if steamID64 then
		success, lastError = pcall(playerlist.SetPriority, steamID64, priority)
		if success then
			Log(LogLevel.DEBUG, string.format("[DB] SetPriority via SteamID64 %s: priority=%d", steamID64, priority))
			if priority == 10 then
				local menuMain = G.Menu and G.Menu.Main
				local autoFlagEnabled = menuMain and menuMain.AutoPriority == true
				if autoFlagEnabled then
					local existing = Database.GetCheater(steamID64)
					if not existing then
						local name = "Manual Flag"
						local info = nil
						if type(target) == "userdata" then
							info = client.GetPlayerInfo and client.GetPlayerInfo(target:GetIndex())
						elseif type(target) == "number" and target < 101 then
							info = client.GetPlayerInfo and client.GetPlayerInfo(target)
						end
						if info and info.Name and info.Name ~= "" then
							name = info.Name
						end
						Database.UpsertCheater(steamID64, {
							name = name,
							reason = "Manual Priority 10",
						})
					end
				end
			end
			return true
		end
	end

	-- Method 4: Try SteamID3 conversion
	if steamID64 then
		-- Convert SteamID64 to SteamID3 format [U:1:XXXXXXXX]
		local accountID = tonumber(steamID64) - 76561197960265728
		if accountID and accountID > 0 then
			local steamID3 = string.format("[U:1:%d]", accountID)
			success, lastError = pcall(playerlist.SetPriority, steamID3, priority)
			if success then
				Log(LogLevel.DEBUG, string.format("[DB] SetPriority via SteamID3 %s: priority=%d", steamID3, priority))
				return true
			end
		end
	end

	-- All methods failed
	Log(
		LogLevel.ERROR,
		string.format(
			"[DB] SetPriority FAILED for target (type=%s): %s",
			type(target),
			tostring(lastError or "all methods failed")
		)
	)
	return false
end

-- Find best path for database storage (saves as JSON now)
function Database.GetFilePath()
	-- Ensure base directory exists
	pcall(filesystem.CreateDirectory, "Lua Cheater_Detection")
	return "Lua Cheater_Detection/database.json" -- Hardcoded path for simplicity
end

-- Save the G.DataBase table to the JSON file
function Database.SaveDatabase()
	Log(LogLevel.DEBUG, "[DB] Starting database save operation")

	if not Database.State.isDirty then
		Log(LogLevel.DEBUG, "[DB] Database not dirty, skipping save")
		return
	end

	if type(G.DataBase) ~= "table" then
		Log(LogLevel.ERROR, "[DB] Cannot save: G.DataBase is not a table")
		return
	end

	local encodedData
	if Json and Json.encode then -- Add nil check for Json.encode
		encodedData = Json.encode(G.DataBase)
	else
		Log(LogLevel.ERROR, "[DB] Json.encode function is not available!")
		return -- Cannot proceed without encoder
	end

	if not encodedData then
		Log(LogLevel.ERROR, "[DB] Failed to encode database to JSON")
		return
	end

	local filepath = Database.GetFilePath()
	Log(LogLevel.DEBUG, "[DB] Writing to file: " .. filepath)

	local file = io.open(filepath, "w")
	if not file then
		Log(LogLevel.ERROR, "[DB] Failed to open file for writing: " .. filepath)
		return
	end

	file:write(encodedData)
	file:close()

	--@diagnostic disable-next-line: cast-local-type -- Disable incorrect linter warning
	encodedData = nil -- Clear reference for GC

	Database.State.isDirty = false
	Database.State.lastSave = os.time()

	---@diagnostic disable-next-line: param-type-mismatch -- Disable incorrect linter warning
	Log(LogLevel.SUCCESS, "[DB] Database saved successfully")
end

-- Load the database from the JSON file
function Database.LoadDatabase(silent, force)
	-- Skip loading if recently loaded (within 10 seconds) unless forced
	local currentTime = os.time()
	if Database.State.isInitialized and not force and (currentTime - Database.State.lastLoaded < 10) then
		Log(LogLevel.DEBUG, "[DB] Skipping reload, database already loaded recently")
		return
	end

	Log(LogLevel.DEBUG, "[DB] Starting database load operation") -- Keep DEBUG
	local filePath = Database.GetFilePath()

	local file = io.open(filePath, "r")
	if not file then
		-- Always log warning if file missing, as it prevents loading
		Log(LogLevel.WARNING, "[DB] Database file not found, initializing empty database")
		G.DataBase = {}
		Database.State.isDirty = true
		Database.State.lastLoaded = os.time()
		return
	end

	local content = file:read("*a")
	file:close()

	if not content or #content == 0 then
		-- Always log warning if file empty, as it means no data
		Log(LogLevel.WARNING, "[DB] Database file is empty, initializing empty database")
		G.DataBase = {}
		Database.State.isDirty = true
		Database.State.lastLoaded = os.time()
		return
	end

	Log(LogLevel.DEBUG, "[DB] Decoding JSON content") -- Keep DEBUG
	local decodedData
	if Json and Json.decode then -- Add nil check for Json.decode
		decodedData = Json.decode(content)
	else
		-- Always log critical error
		Log(LogLevel.ERROR, "[DB] Json.decode function is not available!")
		G.DataBase = {} -- Fallback to empty DB
		Database.State.isDirty = true
		Database.State.lastLoaded = os.time()
		return -- Cannot proceed without decoder
	end
	content = nil -- Clear content reference

	if type(decodedData) ~= "table" then
		-- Always log critical error
		Log(LogLevel.ERROR, "[DB] JSON decode failed or result is not a table")
		G.DataBase = {}
		Database.State.isDirty = true
		Database.State.lastLoaded = os.time()
		return
	end

	Log(LogLevel.DEBUG, "[DB] Starting database validation") -- Keep DEBUG
	local initialCount = 0
	for _ in pairs(decodedData) do
		initialCount = initialCount + 1
	end
	G.DataBase = decodedData -- Assign after counting

	local changesMade = false
	local entriesToRemove = {}
	local totalEntries = 0
	local passedCount = 0
	local failedCount = 0

	for steamID, value in pairs(G.DataBase) do
		totalEntries = totalEntries + 1
		if
			type(value) ~= "table"
			or type(steamID) ~= "string"
			or not steamID:match("^7656119%d+$")
			or #steamID ~= 17
		then
			failedCount = failedCount + 1
			table.insert(entriesToRemove, steamID)
		else
			passedCount = passedCount + 1
		end
		-- Removed periodic validation progress log
	end

	-- Always Log validation summary, color based on failures
	if failedCount > 0 then
		Log(
			LogLevel.WARNING, -- Yellow if failures
			string.format(
				"[DB] Validation finished: %d total, %d passed, %d FAILED",
				totalEntries,
				passedCount,
				failedCount
			)
		)
	elseif not silent then -- Only log non-failure summary if not silent
		Log(
			LogLevel.INFO, -- Cyan if no failures and not silent
			string.format(
				"[DB] Validation finished: %d total, %d passed, %d failed",
				totalEntries,
				passedCount,
				failedCount
			)
		)
	end

	-- Always log if removing entries (Warning)
	if #entriesToRemove > 0 then
		Log(LogLevel.WARNING, string.format("[DB] Removing %d invalid entries", #entriesToRemove))
		for _, key in ipairs(entriesToRemove) do
			G.DataBase[key] = nil
		end
		changesMade = true
	end

	Database.State.isDirty = changesMade
	Database.State.lastLoaded = os.time()
	Database.State.isInitialized = true

	-- Only log final success count if not silent
	if not silent then
		local finalCount = 0
		for _ in pairs(G.DataBase) do
			finalCount = finalCount + 1
		end
		-- Always print the final count summary using printc in green, regardless of debug mode
		Log(LogLevel.SUCCESS, string.format("[DB] Database loaded with %d valid entries", finalCount))
	end
end

-- Simplified Initialize function that serves both internal and external needs
function Database.Initialize(silent)
	-- Skip if already initialized and not forcing
	if Database.State.isInitialized then
		Log(LogLevel.DEBUG, "[DB] Database already initialized, skipping")
		return
	end

	Log(LogLevel.DEBUG, "[DB] Initializing Database module...") -- Keep DEBUG

	-- Ensure G.DataBase exists as a table before loading
	if type(G.DataBase) ~= "table" then
		Log(LogLevel.DEBUG, "[DB] G.DataBase not found, initializing empty")
		G.DataBase = {}
	end

	-- Load the database (uses the updated LoadDatabase logging)
	Database.LoadDatabase(silent, false)

	-- Verify G.DataBase is initialized (LoadDatabase should ensure this)
	if not G.DataBase then
		-- Always log critical error
		Log(LogLevel.ERROR, "[DB] CRITICAL: G.DataBase is nil after LoadDatabase!")
		G.DataBase = {} -- Critical fallback
		Database.State.isDirty = true
	else
		Log(LogLevel.DEBUG, "[DB] G.DataBase initialized, type:" .. type(G.DataBase)) -- Keep DEBUG
	end

	-- Removed redundant final count log here, handled in LoadDatabase

	-- Always set local player priority to 0 and clear from database
	-- Debug mode is only a floodgate for detection, not for cleanup
	local localPlayer = entities.GetLocalPlayer()
	if localPlayer then
		-- Get SteamID64 for all operations
		local mySteamID = Common.GetSteamID64(localPlayer)
		if mySteamID then
			-- Always set priority to 0 using robust method
			local prioritySet = Database.SetPriority(localPlayer, 0, true)
			if prioritySet then
				Log(LogLevel.INFO, string.format("[DB] Set local player priority to 0 (SteamID64: %s)", mySteamID))
			else
				Log(
					LogLevel.WARNING,
					string.format("[DB] Failed to set local player priority (SteamID64: %s)", mySteamID)
				)
			end

			-- Always remove from database (debug mode controls detection, not cleanup)
			if G.DataBase[mySteamID] then
				G.DataBase[mySteamID] = nil
				Database.State.isDirty = true
				Log(
					LogLevel.SUCCESS,
					string.format("[DB] Removed local player from database (SteamID64: %s)", mySteamID)
				)
				-- Removed immediate save
				-- Database.SaveDatabase()
				Log(LogLevel.INFO, "[DB] Database cleanup (local player) - marked dirty")
			else
				Log(LogLevel.DEBUG, "[DB] Local player not in database")
			end
		else
			Log(LogLevel.WARNING, "[DB] Failed to get local player SteamID64")
		end
	else
		Log(LogLevel.WARNING, "[DB] Failed to get local player entity")
	end

	Log(LogLevel.DEBUG, "[DB] Database initialization complete.") -- Keep DEBUG
	Database.State.isInitialized = true
end

--[[ Self-Initialization ]]
-- Initial load and setup (silent=true to avoid verbose messages at load time)
Database.Initialize(true)

--- Upsert a cheater entry into the database (minimal format like fetched data)
---@param steamID string Player's SteamID64
---@param data table Cheater data (name, reason)
function Database.UpsertCheater(steamID, data)
	if not steamID or type(steamID) ~= "string" then
		Log(LogLevel.ERROR, "[DB] UpsertCheater: Invalid steamID")
		return false
	end

	if not steamID:match("^7656119%d+$") or #steamID ~= 17 then
		Log(LogLevel.ERROR, "[DB] UpsertCheater: Invalid steamID format: " .. steamID)
		return false
	end

	-- Ensure G.DataBase exists
	if type(G.DataBase) ~= "table" then
		G.DataBase = {}
	end

	-- Minimal format like fetched databases: just Name and Reason
	G.DataBase[steamID] = {
		Name = data.name or "Unknown",
		Reason = data.reason or "Cheater", -- Use provided reason, fallback to "Cheater" for imported data
	}

	-- Mark as dirty for save
	Database.State.isDirty = true

	-- Removed immediate save to prevent lag spikes
	-- Database.SaveDatabase()

	Log(
		LogLevel.INFO,
		string.format(
			"[DB] Added cheater: %s (%s) - Reason: %s",
			data.name or "Unknown",
			steamID,
			data.reason or "Cheater"
		)
	)

	return true
end

--- Get a cheater entry from the database
---@param steamID string Player's SteamID64
---@return table|nil Cheater data or nil if not found
function Database.GetCheater(steamID)
	if not steamID or type(G.DataBase) ~= "table" then
		return nil
	end

	return G.DataBase[steamID]
end

--- Remove a cheater entry from the database
---@param steamID string Player's SteamID64
---@return boolean Success
function Database.RemoveCheater(steamID)
	if not steamID or type(G.DataBase) ~= "table" then
		return false
	end

	if G.DataBase[steamID] then
		G.DataBase[steamID] = nil
		Database.State.isDirty = true
		-- Removed immediate save
		-- Database.SaveDatabase()
		Log(LogLevel.INFO, "[DB] Removed cheater: " .. steamID)
		return true
	end

	return false
end

--- Force save the database (ignores dirty flag)
---@return boolean Success
function Database.ForceSave()
	local wasDirty = Database.State.isDirty
	Database.State.isDirty = true
	Database.SaveDatabase()
	if not wasDirty then
		Database.State.isDirty = false
	end
	return true
end

--[[ Callback Registration ]]
callbacks.Register("Unload", "DatabaseAutoSaveOnUnload", DatabaseAutoSaveOnUnload)

return Database

end)
__bundle_register("Cheater_Detection.Utils.Common", function(require, _LOADED, __bundle_register, __bundle_modules)
---@diagnostic disable: duplicate-set-field, undefined-field

--[[ Imports ]]
--
local Common = {
	Lib = nil,
	Json = nil,
	Log = nil,
	Notify = nil,
	TF2 = nil,
	Math = nil,
	Conversion = nil,
	WPlayer = nil,
	PR = nil,
	Helpers = nil,
}

local HistoryManager = require("Cheater_Detection.Utils.HistoryManager")

-- Move requires here
Common.Json = require("Cheater_Detection.Libs.Json")
local G = require("Cheater_Detection.Utils.Globals")

if UnloadLib ~= nil then
	UnloadLib()
end

--------------------------------------------------------------------------------------
--Library loading--
--------------------------------------------------------------------------------------

--Function to download content from a URL
-- REMOVED: Security risk (Remote Code Execution)
-- The library must be installed locally.

-- Load and validate library
local function loadlib()
	local success, localLib = pcall(require, "lnxLib")
	if success and localLib then
		return localLib
	end

	-- Fallback: Check if it's in the Libs folder
	local success2, localLib2 = pcall(require, "Cheater_Detection.Libs.lnxLib")
	if success2 and localLib2 then
		return localLib2
	end

	error("Critical Error: lnxLib not found! Please install it or ensure it is in the Libs folder.")
end

local lnxLib = loadlib()

if not lnxLib then
	error("Failed to load lnxLib")
end

Common.Lib = lnxLib

-- Now initialize remaining Common fields using the loaded libraries
Common.Log = Common.Lib.Utils.Logger.new("Cheater Detection")
Common.Notify = Common.Lib.UI.Notify
Common.TF2 = Common.Lib.TF2
Common.Math = Common.Lib.Utils.Math
Common.Conversion = Common.Lib.Utils.Conversion
Common.WPlayer = Common.TF2.WPlayer
Common.PR = Common.Lib.TF2.PlayerResource
Common.Helpers = Common.Lib.TF2.Helpers

-- Now using WrappedPlayer module instead of monkey patching

local cachedSteamIDs = {}
local lastTick = -1

function Common.IsFriend(entity)
	return (not G.Menu.Main.debug and Common.TF2.IsFriend(entity:GetIndex(), true)) -- Entity is a freind and party member
end

function Common.GetSteamID64(Player)
	assert(Player, "Player is nil")

	local currentTick = globals.TickCount()
	local playerIndex = Player:GetIndex()

	-- Reset cache on new tick (simple conditional is better than "branchless")
	if lastTick ~= currentTick then
		cachedSteamIDs = {}
		lastTick = currentTick
	end

	-- Retrieve cached result or calculate it
	local result = cachedSteamIDs[playerIndex]
	if not result then
		local playerInfo = assert(client.GetPlayerInfo(playerIndex), "Failed to get player info")
		local steamID = assert(playerInfo.SteamID, "Failed to get SteamID")

		if playerInfo.IsBot or playerInfo.IsHLTV or steamID == "[U:1:0]" then
			result = playerInfo.UserID
		else
			local converted = steam.ToSteamID64(steamID)
			result = assert(converted, "Failed to convert SteamID to SteamID64")
		end
	end

	cachedSteamIDs[playerIndex] = result
	return result
end

function Common.IsCheater(playerInfo)
	local steamId = nil

	if type(playerInfo) == "number" and playerInfo < 101 then
		-- Assuming playerInfo is the index
		local targetIndex = playerInfo
		local targetPlayer = nil

		-- Find the player with the same index
		for _, player in ipairs(G.players) do
			if player:GetIndex() == targetIndex then
				targetPlayer = player
				break
			end
		end
	elseif type(playerInfo) == "string" then
		-- playerInfo is a SteamID64 string
		steamId = playerInfo
	elseif type(playerInfo) == "table" then
		-- playerInfo is a playerInfo table
		if playerInfo.SteamID then
			steamId = steam.ToSteamID64(playerInfo.SteamID)
		end
	end

	if not steamId then
		return false
	end

	-- Check if the player is marked as a cheater based on various criteria
	-- Use Evidence system instead of deprecated G.PlayerData.info fields
	local Evidence = require("Cheater_Detection.Core.Evidence_system")
	local isMarkedCheater = Evidence.IsMarkedCheater(steamId)
	local inDatabase = G.DataBase[steamId] ~= nil
	local priorityCheater = playerlist.GetPriority(steamId) == 10

	return isMarkedCheater or inDatabase or priorityCheater
end

---@param entity Entity
---@param checkFriend boolean?
---@param checkDormant boolean?
---@param skipEntity Entity? Optional entity to skip (e.g., the local player)
function Common.IsValidPlayer(entity, checkFriend, checkDormant, skipEntity)
	-- Simple validation checks
	if not entity or not entity:IsValid() or not entity:IsAlive() then
		return false
	end

	-- Check dormancy (default is to reject dormant unless explicitly false)
	if checkDormant ~= false and entity:IsDormant() then
		return false
	end

	-- Reject spectators/unassigned
	local team = entity:GetTeamNumber()
	if team == TEAM_SPECTATOR or team == TEAM_UNASSIGNED then
		return false
	end

	-- Skip specific entity if requested
	if skipEntity and entity == skipEntity then
		return false
	end

	-- Skip friends (default behavior unless debug enabled or explicitly disabled)
	if not G.Menu.Advanced.debug and checkFriend ~= false and Common.IsFriend(entity) then
		return false
	end

	return true -- Entity is a valid player
end

-- Create a common record structure
function Common.createRecord(angle, position, headHitbox, bodyHitbox, simTime, onGround)
	return {
		Angle = angle,
		ViewPos = position,
		Hitboxes = {
			Head = headHitbox,
			Body = bodyHitbox,
		},
		SimTime = simTime,
		onGround = onGround,
	}
end

-- Maximum number of historical snapshots to keep per player
Common.MAX_HISTORY = 66

-- Convenience: build a record directly from a player wrapper/entity
---@param player table|Entity WrappedPlayer or entity implementing required methods
---@return table|nil record
function Common.createRecordFromPlayer(player)
	if not player or type(player.GetEyeAngles) ~= "function" then
		return nil
	end

	return Common.createRecord(
		player:GetEyeAngles(),
		player:GetEyePos(),
		player:GetHitboxPos(1), -- Head
		player:GetHitboxPos(4), -- Body
		player:GetSimulationTime(),
		player:IsOnGround()
	)
end

-- Legacy shim; new code should use HistoryManager.Push directly
function Common.pushHistory(player)
	HistoryManager.Push(player)
end

function Common.FromSteamid3To64(steamid3)
	if not steamid3 then
		return nil
	end

	local raw = tostring(steamid3)
	if raw == "" then
		return nil
	end

	-- Already SteamID64
	if raw:match("^7656119%d+$") then
		return raw
	end

	-- Handle SteamID2 format (STEAM_X:Y:Z)
	if raw:match("^STEAM_%d+:%d+:%d+$") then
		local ok, converted = pcall(steam.ToSteamID64, raw)
		return ok and tostring(converted) or nil
	end

	-- Ensure SteamID3 wrapped in brackets
	if not raw:match("^%[U:1:%d+%]$") then
		raw = string.format("[U:1:%s]", raw)
	end

	local ok, converted = pcall(steam.ToSteamID64, raw)
	return ok and tostring(converted) or nil
end

function Common.IsSteamID64(steamID)
	if not steamID then
		return false
	end
	steamID = tostring(steamID)
	return steamID:match("^7656119%d+$") and #steamID == 17
end

-- Helper function to determine if the content is JSON
function Common.isJson(content)
	local firstChar = content:sub(1, 1)
	return firstChar == "{" or firstChar == "["
end

-- Safe integer rounding function for drawing coordinates
Common.RoundCoord = function(value)
	if not value then
		return 0
	end

	if type(value) ~= "number" then
		return 0
	end

	-- Check for NaN and infinity
	if value ~= value or value == math.huge or value == -math.huge then
		return 0
	end

	return math.floor(value + 0.5)
end

local E_Flows = { FLOW_OUTGOING = 0, FLOW_INCOMING = 1, MAX_FLOWS = 2 }

function Common.CheckConnectionState()
	local netChannel = clientstate.GetNetChannel()
	if not netChannel then
		return { stable = false, reason = "No NetChannel" }
	end

	-- Check for timeout
	if netChannel:IsTimingOut() then
		return { stable = false, reason = "Timing out" }
	end

	-- If we're just playing a demo, consider connection perfectly stable and skip further checks
	if netChannel:IsPlayback() then
		return { stable = true, reason = "Demo" }
	end

	-- Check latency, choke, and loss (incoming) — only for real servers
	local latency = netChannel:GetAvgLatency(E_Flows.FLOW_INCOMING)
	local choke = netChannel:GetAvgChoke(E_Flows.FLOW_INCOMING)
	local loss = netChannel:GetAvgLoss(E_Flows.FLOW_INCOMING)
	-- Thresholds: adjust as needed
	if latency > 0.5 then
		return { stable = false, reason = string.format("High latency: %.2f", latency) }
	end
	if choke > 0.2 then
		return { stable = false, reason = string.format("High choke: %.2f", choke) }
	end
	if loss > 0.1 then
		return { stable = false, reason = string.format("High loss: %.2f", loss) }
	end

	return { stable = true }
end

--[[ Registrations and final actions ]]
--
local function OnUnload() -- Called when the script is unloaded
	if UnloadLib then
		pcall(UnloadLib) --unloading lualib safely
	end
	pcall(engine.PlaySound, "hl1/fvox/deactivated.wav") --deactivated safely
end

-- Unregister previous callbacks
callbacks.Unregister("Unload", "CD_Unload") -- unregister the "Unload" callback

-- Register callbacks
callbacks.Register("Unload", "CD_Unload", OnUnload) -- Register the "Unload" callback

-- Play sound when loaded
engine.PlaySound("hl1/fvox/activated.wav")

return Common

end)
__bundle_register("Cheater_Detection.Libs.Json", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
David Kolf's JSON module for Lua 5.1 - 5.4

Version 2.6


For the documentation see the corresponding readme.txt or visit
<http://dkolf.de/src/dkjson-lua.fsl/>.

You can contact the author by sending an e-mail to 'david' at the
domain 'dkolf.de'.


Copyright (C) 2010-2021 David Heiko Kolf

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
--]]

---@alias JsonState { indent : boolean?, keyorder : integer[]?, level : integer?, buffer : string[]?, bufferlen : integer?, tables : table[]?, exception : function? }

-- global dependencies:
local pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset =
	pairs, type, tostring, tonumber, getmetatable, setmetatable, rawset
local error, require, pcall, select = error, require, pcall, select
local floor, huge = math.floor, math.huge
local strrep, gsub, strsub, strbyte, strchar, strfind, strlen, strformat =
	string.rep, string.gsub, string.sub, string.byte, string.char, string.find, string.len, string.format
local strmatch = string.match
local concat = table.concat

---@class Json
local json = { version = "dkjson 2.6.1 L" }

local _ENV = nil -- blocking globals in Lua 5.2 and later

json.null = setmetatable({}, {
	__tojson = function()
		return "null"
	end,
})

local function isarray(tbl)
	local max, n, arraylen = 0, 0, 0
	for k, v in pairs(tbl) do
		if k == "n" and type(v) == "number" then
			arraylen = v
			if v > max then
				max = v
			end
		else
			if type(k) ~= "number" or k < 1 or floor(k) ~= k then
				return false
			end
			if k > max then
				max = k
			end
			n = n + 1
		end
	end
	if max > 10 and max > arraylen and max > n * 2 then
		return false -- don't create an array with too many holes
	end
	return true, max
end

local escapecodes = {
	['"'] = '\\"',
	["\\"] = "\\\\",
	["\b"] = "\\b",
	["\f"] = "\\f",
	["\n"] = "\\n",
	["\r"] = "\\r",
	["\t"] = "\\t",
}

local function escapeutf8(uchar)
	local value = escapecodes[uchar]
	if value then
		return value
	end
	local a, b, c, d = strbyte(uchar, 1, 4)
	a, b, c, d = a or 0, b or 0, c or 0, d or 0
	if a <= 0x7f then
		value = a
	elseif 0xc0 <= a and a <= 0xdf and b >= 0x80 then
		value = (a - 0xc0) * 0x40 + b - 0x80
	elseif 0xe0 <= a and a <= 0xef and b >= 0x80 and c >= 0x80 then
		value = ((a - 0xe0) * 0x40 + b - 0x80) * 0x40 + c - 0x80
	elseif 0xf0 <= a and a <= 0xf7 and b >= 0x80 and c >= 0x80 and d >= 0x80 then
		value = (((a - 0xf0) * 0x40 + b - 0x80) * 0x40 + c - 0x80) * 0x40 + d - 0x80
	else
		return ""
	end
	if value <= 0xffff then
		return strformat("\\u%.4x", value)
	elseif value <= 0x10ffff then
		-- encode as UTF-16 surrogate pair
		value = value - 0x10000
		local highsur, lowsur = 0xD800 + floor(value / 0x400), 0xDC00 + (value % 0x400)
		return strformat("\\u%.4x\\u%.4x", highsur, lowsur)
	else
		return ""
	end
end

local function fsub(str, pattern, repl)
	-- gsub always builds a new string in a buffer, even when no match
	-- exists. First using find should be more efficient when most strings
	-- don't contain the pattern.
	if strfind(str, pattern) then
		return gsub(str, pattern, repl)
	else
		return str
	end
end

local function quotestring(value)
	-- based on the regexp "escapable" in https://github.com/douglascrockford/JSON-js
	value = fsub(value, '[%z\1-\31"\\\127]', escapeutf8)
	if strfind(value, "[\194\216\220\225\226\239]") then
		value = fsub(value, "\194[\128-\159\173]", escapeutf8)
		value = fsub(value, "\216[\128-\132]", escapeutf8)
		value = fsub(value, "\220\143", escapeutf8)
		value = fsub(value, "\225\158[\180\181]", escapeutf8)
		value = fsub(value, "\226\128[\140-\143\168-\175]", escapeutf8)
		value = fsub(value, "\226\129[\160-\175]", escapeutf8)
		value = fsub(value, "\239\187\191", escapeutf8)
		value = fsub(value, "\239\191[\176-\191]", escapeutf8)
	end
	return '"' .. value .. '"'
end
json.quotestring = quotestring

local function replace(str, o, n)
	local i, j = strfind(str, o, 1, true)
	if i then
		return strsub(str, 1, i - 1) .. n .. strsub(str, j + 1, -1)
	else
		return str
	end
end

-- locale independent num2str and str2num functions
local decpoint, numfilter

local function updatedecpoint()
	decpoint = strmatch(tostring(0.5), "([^05+])")
	-- build a filter that can be used to remove group separators
	numfilter = "[^0-9%-%+eE" .. gsub(decpoint, "[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0") .. "]+"
end

updatedecpoint()

local function num2str(num)
	return replace(fsub(tostring(num), numfilter, ""), decpoint, ".")
end

local function str2num(str)
	local num = tonumber(replace(str, ".", decpoint))
	if not num then
		updatedecpoint()
		num = tonumber(replace(str, ".", decpoint))
	end
	return num
end

local function addnewline2(level, buffer, buflen)
	buffer[buflen + 1] = "\n"
	buffer[buflen + 2] = strrep("  ", level)
	buflen = buflen + 2
	return buflen
end

function json.addnewline(state)
	if state.indent then
		state.bufferlen = addnewline2(state.level or 0, state.buffer, state.bufferlen or #state.buffer)
	end
end

local encode2 -- forward declaration

local function addpair(key, value, prev, indent, level, buffer, buflen, tables, globalorder, state)
	local kt = type(key)
	if kt ~= "string" and kt ~= "number" then
		return nil, "type '" .. kt .. "' is not supported as a key by JSON."
	end
	if prev then
		buflen = buflen + 1
		buffer[buflen] = ","
	end
	if indent then
		buflen = addnewline2(level, buffer, buflen)
	end
	buffer[buflen + 1] = quotestring(key)
	buffer[buflen + 2] = ":"
	return encode2(value, indent, level, buffer, buflen + 2, tables, globalorder, state)
end

local function appendcustom(res, buffer, state)
	local buflen = state.bufferlen
	if type(res) == "string" then
		buflen = buflen + 1
		buffer[buflen] = res
	end
	return buflen
end

local function exception(reason, value, state, buffer, buflen, defaultmessage)
	defaultmessage = defaultmessage or reason
	local handler = state.exception
	if not handler then
		return nil, defaultmessage
	else
		state.bufferlen = buflen
		local ret, msg = handler(reason, value, state, defaultmessage)
		if not ret then
			return nil, msg or defaultmessage
		end
		return appendcustom(ret, buffer, state)
	end
end

function json.encodeexception(reason, value, state, defaultmessage)
	return quotestring("<" .. defaultmessage .. ">")
end

encode2 = function(value, indent, level, buffer, buflen, tables, globalorder, state)
	local valtype = type(value)
	local valmeta = getmetatable(value)
	valmeta = type(valmeta) == "table" and valmeta -- only tables
	local valtojson = valmeta and valmeta.__tojson
	if valtojson then
		if tables[value] then
			return exception("reference cycle", value, state, buffer, buflen)
		end
		tables[value] = true
		state.bufferlen = buflen
		local ret, msg = valtojson(value, state)
		if not ret then
			return exception("custom encoder failed", value, state, buffer, buflen, msg)
		end
		tables[value] = nil
		buflen = appendcustom(ret, buffer, state)
	elseif value == nil then
		buflen = buflen + 1
		buffer[buflen] = "null"
	elseif valtype == "number" then
		local s
		if value ~= value or value >= huge or -value >= huge then
			-- This is the behaviour of the original JSON implementation.
			s = "null"
		else
			s = num2str(value)
		end
		buflen = buflen + 1
		buffer[buflen] = s
	elseif valtype == "boolean" then
		buflen = buflen + 1
		buffer[buflen] = value and "true" or "false"
	elseif valtype == "string" then
		buflen = buflen + 1
		buffer[buflen] = quotestring(value)
	elseif valtype == "table" then
		if tables[value] then
			return exception("reference cycle", value, state, buffer, buflen)
		end
		tables[value] = true
		level = level + 1
		local isa, n = isarray(value)
		if n == 0 and valmeta and valmeta.__jsontype == "object" then
			isa = false
		end
		local msg
		if isa then -- JSON array
			buflen = buflen + 1
			buffer[buflen] = "["
			for i = 1, n do
				buflen, msg = encode2(value[i], indent, level, buffer, buflen, tables, globalorder, state)
				if not buflen then
					return nil, msg
				end
				if i < n then
					buflen = buflen + 1
					buffer[buflen] = ","
				end
			end
			buflen = buflen + 1
			buffer[buflen] = "]"
		else -- JSON object
			local prev = false
			buflen = buflen + 1
			buffer[buflen] = "{"
			local order = valmeta and valmeta.__jsonorder or globalorder
			if order then
				local used = {}
				n = #order
				for i = 1, n do
					local k = order[i]
					local v = value[k]
					if v ~= nil then
						used[k] = true
						buflen, msg = addpair(k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
						prev = true -- add a seperator before the next element
					end
				end
				for k, v in pairs(value) do
					if not used[k] then
						buflen, msg = addpair(k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
						if not buflen then
							return nil, msg
						end
						prev = true -- add a seperator before the next element
					end
				end
			else -- unordered
				for k, v in pairs(value) do
					buflen, msg = addpair(k, v, prev, indent, level, buffer, buflen, tables, globalorder, state)
					if not buflen then
						return nil, msg
					end
					prev = true -- add a seperator before the next element
				end
			end
			if indent then
				buflen = addnewline2(level - 1, buffer, buflen)
			end
			buflen = buflen + 1
			buffer[buflen] = "}"
		end
		tables[value] = nil
	else
		return exception(
			"unsupported type",
			value,
			state,
			buffer,
			buflen,
			"type '" .. valtype .. "' is not supported by JSON."
		)
	end
	return buflen
end

---Encodes a lua table to a JSON string.
---@param value any
---@param state? JsonState
---@return string|boolean
function json.encode(value, state)
	state = state or {}
	local oldbuffer = state.buffer
	local buffer = oldbuffer or {}
	state.buffer = buffer
	updatedecpoint()
	local ret, msg = encode2(
		value,
		state.indent,
		state.level or 0,
		buffer,
		state.bufferlen or 0,
		state.tables or {},
		state.keyorder,
		state
	)
	if not ret then
		error(msg, 2)
	elseif oldbuffer == buffer then
		state.bufferlen = ret
		return true
	else
		state.bufferlen = nil
		state.buffer = nil
		return concat(buffer)
	end
end

local function loc(str, where)
	local line, pos, linepos = 1, 1, 0
	while true do
		pos = strfind(str, "\n", pos, true)
		if pos and pos < where then
			line = line + 1
			linepos = pos
			pos = pos + 1
		else
			break
		end
	end
	return "line " .. line .. ", column " .. (where - linepos)
end

local function unterminated(str, what, where)
	return nil, strlen(str) + 1, "unterminated " .. what .. " at " .. loc(str, where)
end

local function scanwhite(str, pos)
	while true do
		pos = strfind(str, "%S", pos)
		if not pos then
			return nil
		end
		local sub2 = strsub(str, pos, pos + 1)
		if sub2 == "\239\187" and strsub(str, pos + 2, pos + 2) == "\191" then
			-- UTF-8 Byte Order Mark
			pos = pos + 3
		elseif sub2 == "//" then
			pos = strfind(str, "[\n\r]", pos + 2)
			if not pos then
				return nil
			end
		elseif sub2 == "/*" then
			pos = strfind(str, "*/", pos + 2)
			if not pos then
				return nil
			end
			pos = pos + 2
		else
			return pos
		end
	end
end

local escapechars = {
	['"'] = '"',
	["\\"] = "\\",
	["/"] = "/",
	["b"] = "\b",
	["f"] = "\f",
	["n"] = "\n",
	["r"] = "\r",
	["t"] = "\t",
}

local function unichar(value)
	if value < 0 then
		return nil
	elseif value <= 0x007f then
		return strchar(value)
	elseif value <= 0x07ff then
		return strchar(0xc0 + floor(value / 0x40), 0x80 + (floor(value) % 0x40))
	elseif value <= 0xffff then
		return strchar(0xe0 + floor(value / 0x1000), 0x80 + (floor(value / 0x40) % 0x40), 0x80 + (floor(value) % 0x40))
	elseif value <= 0x10ffff then
		return strchar(
			0xf0 + floor(value / 0x40000),
			0x80 + (floor(value / 0x1000) % 0x40),
			0x80 + (floor(value / 0x40) % 0x40),
			0x80 + (floor(value) % 0x40)
		)
	else
		return nil
	end
end

local function scanstring(str, pos)
	local lastpos = pos + 1
	local buffer, n = {}, 0
	while true do
		local nextpos = strfind(str, '["\\]', lastpos)
		if not nextpos then
			return unterminated(str, "string", pos)
		end
		if nextpos > lastpos then
			n = n + 1
			buffer[n] = strsub(str, lastpos, nextpos - 1)
		end
		if strsub(str, nextpos, nextpos) == '"' then
			lastpos = nextpos + 1
			break
		else
			local escchar = strsub(str, nextpos + 1, nextpos + 1)
			local value
			if escchar == "u" then
				value = tonumber(strsub(str, nextpos + 2, nextpos + 5), 16)
				if value then
					local value2
					if 0xD800 <= value and value <= 0xDBff then
						-- we have the high surrogate of UTF-16. Check if there is a
						-- low surrogate escaped nearby to combine them.
						if strsub(str, nextpos + 6, nextpos + 7) == "\\u" then
							value2 = tonumber(strsub(str, nextpos + 8, nextpos + 11), 16)
							if value2 and 0xDC00 <= value2 and value2 <= 0xDFFF then
								value = (value - 0xD800) * 0x400 + (value2 - 0xDC00) + 0x10000
							else
								value2 = nil -- in case it was out of range for a low surrogate
							end
						end
					end
					value = value and unichar(value)
					if value then
						if value2 then
							lastpos = nextpos + 12
						else
							lastpos = nextpos + 6
						end
					end
				end
			end
			if not value then
				value = escapechars[escchar] or escchar
				lastpos = nextpos + 2
			end
			n = n + 1
			buffer[n] = value
		end
	end
	if n == 1 then
		return buffer[1], lastpos
	elseif n > 1 then
		return concat(buffer), lastpos
	else
		return "", lastpos
	end
end

local scanvalue -- forward declaration

local function scantable(what, closechar, str, startpos, nullval, objectmeta, arraymeta)
	local tbl, n = {}, 0
	local pos = startpos + 1
	if what == "object" then
		setmetatable(tbl, objectmeta)
	else
		setmetatable(tbl, arraymeta)
	end
	while true do
		pos = scanwhite(str, pos)
		if not pos then
			return unterminated(str, what, startpos)
		end
		local char = strsub(str, pos, pos)
		if char == closechar then
			return tbl, pos + 1
		end
		local val1, err
		val1, pos, err = scanvalue(str, pos, nullval, objectmeta, arraymeta)
		if err then
			return nil, pos, err
		end
		pos = scanwhite(str, pos)
		if not pos then
			return unterminated(str, what, startpos)
		end
		char = strsub(str, pos, pos)
		if char == ":" then
			if val1 == nil then
				return nil, pos, "cannot use nil as table index (at " .. loc(str, pos) .. ")"
			end
			pos = scanwhite(str, pos + 1)
			if not pos then
				return unterminated(str, what, startpos)
			end
			local val2
			val2, pos, err = scanvalue(str, pos, nullval, objectmeta, arraymeta)
			if err then
				return nil, pos, err
			end
			tbl[val1] = val2
			pos = scanwhite(str, pos)
			if not pos then
				return unterminated(str, what, startpos)
			end
			char = strsub(str, pos, pos)
		else
			n = n + 1
			tbl[n] = val1
		end
		if char == "," then
			pos = pos + 1
		end
	end
end

scanvalue = function(str, pos, nullval, objectmeta, arraymeta)
	pos = pos or 1
	pos = scanwhite(str, pos)
	if not pos then
		return nil, strlen(str) + 1, "no valid JSON value (reached the end)"
	end
	local char = strsub(str, pos, pos)
	if char == "{" then
		return scantable("object", "}", str, pos, nullval, objectmeta, arraymeta)
	elseif char == "[" then
		return scantable("array", "]", str, pos, nullval, objectmeta, arraymeta)
	elseif char == '"' then
		return scanstring(str, pos)
	else
		local pstart, pend = strfind(str, "^%-?[%d%.]+[eE]?[%+%-]?%d*", pos)
		if pstart then
			local number = str2num(strsub(str, pstart, pend))
			if number then
				return number, pend + 1
			end
		end
		pstart, pend = strfind(str, "^%a%w*", pos)
		if pstart then
			local name = strsub(str, pstart, pend)
			if name == "true" then
				return true, pend + 1
			elseif name == "false" then
				return false, pend + 1
			elseif name == "null" then
				return nullval, pend + 1
			end
		end
		return nil, pos, "no valid JSON value at " .. loc(str, pos)
	end
end

local function optionalmetatables(...)
	if select("#", ...) > 0 then
		return ...
	else
		return { __jsontype = "object" }, { __jsontype = "array" }
	end
end

---@param str string
---@param pos integer?
---@param nullval any?
---@param ... table?
function json.decode(str, pos, nullval, ...)
	local objectmeta, arraymeta = optionalmetatables(...)
	return scanvalue(str, pos, nullval, objectmeta, arraymeta)
end

return json

end)
__bundle_register("Cheater_Detection.Utils.HistoryManager", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ HistoryManager.lua
     Centralized history sampling orchestrator.
     Detections declare how many ticks of history they need and which fields.
     The manager captures only the required data, trims old entries, and reuses
     record tables to minimize garbage churn.
]]

local PlayerState = require("Cheater_Detection.Utils.PlayerState")
local Logger = require("Cheater_Detection.Utils.Logger")
local TickProfiler = require("Cheater_Detection.Utils.TickProfiler")

---@class HistoryManager
local HistoryManager = {}

local recordPool = {}
local consumers = {}
local activeFields = {}
local maxRetentionTicks = 0

local DEFAULT_RETENTION_TICKS = 33 -- Reduced from 66 to save memory

HistoryManager.Fields = {
	Angles = "angles",
	EyePosition = "eye_pos",
	HeadHitbox = "hitbox_head",
	BodyHitbox = "hitbox_body",
	SimulationTime = "sim_time",
	OnGround = "on_ground",
	Velocity = "velocity",
	ViewOffset = "view_offset",
}

local FIELD_BUILDERS = {
	[HistoryManager.Fields.Angles] = function(player)
		return player:GetEyeAngles()
	end,
	[HistoryManager.Fields.EyePosition] = function(player)
		return player:GetEyePos()
	end,
	[HistoryManager.Fields.HeadHitbox] = function(player)
		return player.GetHitboxPos and player:GetHitboxPos(1) or nil
	end,
	[HistoryManager.Fields.BodyHitbox] = function(player)
		return player.GetHitboxPos and player:GetHitboxPos(4) or nil
	end,
	[HistoryManager.Fields.SimulationTime] = function(player)
		return player:GetSimulationTime()
	end,
	[HistoryManager.Fields.OnGround] = function(player)
		return player:IsOnGround()
	end,
	[HistoryManager.Fields.Velocity] = function(player)
		return player:GetVelocity()
	end,
	[HistoryManager.Fields.ViewOffset] = function(player)
		return player:GetViewOffset()
	end,
}

local function acquireRecord()
	local record = recordPool[#recordPool]
	if record then
		recordPool[#recordPool] = nil
		return record
	end
	return {}
end

local function recycleRecord(record)
	for key in pairs(record) do
		record[key] = nil
	end
	recordPool[#recordPool + 1] = record
end

local function recomputeRequirements()
	local newMax = 0
	local newFields = {}
	for _, spec in pairs(consumers) do
		if spec.retentionTicks > newMax then
			newMax = spec.retentionTicks
		end
		for field in pairs(spec.fields) do
			newFields[field] = true
		end
	end
	maxRetentionTicks = newMax
	activeFields = newFields
end

local function buildRecord(player)
	local record = acquireRecord()
	local hasData = false
	for field in pairs(activeFields) do
		local builder = FIELD_BUILDERS[field]
		if builder then
			local value = builder(player)
			if value ~= nil then
				record[field] = value
				hasData = true
			else
				record[field] = nil
			end
		end
	end
	record.tick = globals.TickCount()
	return hasData and record or nil
end

local function trimHistory(history)
	local limit = (maxRetentionTicks > 0 and maxRetentionTicks) or DEFAULT_RETENTION_TICKS
	while #history > limit do
		recycleRecord(table.remove(history, 1))
	end
end

---Register a detection/module that needs history data.
---@param name string
---@param spec { retentionTicks:number, fields:string[] }
function HistoryManager.RegisterConsumer(name, spec)
	assert(type(name) == "string" and name ~= "", "HistoryManager.RegisterConsumer requires a name")
	assert(type(spec) == "table", "HistoryManager.RegisterConsumer requires a spec table")

	local retention = math.max(1, tonumber(spec.retentionTicks) or DEFAULT_RETENTION_TICKS)
	local fieldSet = {}
	if type(spec.fields) == "table" then
		for _, field in ipairs(spec.fields) do
			if FIELD_BUILDERS[field] then
				fieldSet[field] = true
			else
				Logger.Warning(
					"HistoryManager",
					string.format("Unknown history field '%s' requested by %s", tostring(field), name)
				)
			end
		end
	end

	if not next(fieldSet) then
		Logger.Warning(
			"HistoryManager",
			string.format("Consumer %s registered without valid fields; ignoring registration", name)
		)
		return
	end

	consumers[name] = {
		retentionTicks = retention,
		fields = fieldSet,
	}

	recomputeRequirements()
end

---Unregister a consumer (e.g., when detection unloads).
---@param name string
function HistoryManager.UnregisterConsumer(name)
	if not consumers[name] then
		return
	end
	consumers[name] = nil
	recomputeRequirements()
end

---Push a snapshot for the given player if any fields are active.
---@param player table
function HistoryManager.Push(player)
	if not next(activeFields) then
		return
	end
	if not player or type(player.GetSteamID64) ~= "function" then
		return
	end

	local steamID = player:GetSteamID64()
	if not steamID then
		return
	end

	TickProfiler.BeginSection("History_BuildRecord")
	local record = buildRecord(player)
	TickProfiler.EndSection("History_BuildRecord")

	if not record then
		return
	end

	local state = PlayerState.GetOrCreate(steamID)
	if not state then
		recycleRecord(record)
		return
	end

	state.History = state.History or {}
	state.History[#state.History + 1] = record
	state.Current = record

	TickProfiler.BeginSection("History_Trim")
	trimHistory(state.History)
	TickProfiler.EndSection("History_Trim")
end

---Expose current retention tick count (max of all consumers).
---@return integer
function HistoryManager.GetRetentionTicks()
	return (maxRetentionTicks > 0 and maxRetentionTicks) or DEFAULT_RETENTION_TICKS
end

---Expose currently active field set (copy).
---@return table<string, boolean>
function HistoryManager.GetActiveFields()
	local copy = {}
	for field in pairs(activeFields) do
		copy[field] = true
	end
	return copy
end

local function ensureLegacyConsumer()
	if activeFields and next(activeFields) then
		return
	end

	HistoryManager.RegisterConsumer("__legacy_default", {
		retentionTicks = DEFAULT_RETENTION_TICKS,
		fields = {
			HistoryManager.Fields.Angles,
			HistoryManager.Fields.EyePosition,
			HistoryManager.Fields.HeadHitbox,
			HistoryManager.Fields.BodyHitbox,
			HistoryManager.Fields.SimulationTime,
			HistoryManager.Fields.OnGround,
		},
	})
end

ensureLegacyConsumer()

function HistoryManager.RemoveLegacyConsumer()
	if consumers.__legacy_default then
		consumers.__legacy_default = nil
		recomputeRequirements()
	end
end

return HistoryManager

end)
__bundle_register("Cheater_Detection.Utils.TickProfiler", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
	TickProfiler
	Lightweight internal profiler that measures time spent in labeled sections per tick
	and renders a bottom-left overlay while debug mode is enabled.
]]

local TickProfiler = {}

local sections = {}
local stacks = {}
local acc = {} -- Accumulator for rolling stats
local display = {} -- Display entries
local enabled = false
local lastSnapshot = 0
local SNAPSHOT_INTERVAL = 10 -- Update display every ~10 ticks for smoothness

-- Configuration
local SMOOTHING_FACTOR = 0.1 -- For EMA smoothing of display values
local SORT_DELAY = 33 -- Re-sort every ~0.5 seconds (33 ticks)
local lastSortTime = 0

local font = draw.CreateFont("Tahoma", 12, 600, FONTFLAG_OUTLINE)
local fontSmall = draw.CreateFont("Tahoma", 11, 400, FONTFLAG_OUTLINE)
local overlayPadding = 12

-- Color Palette
local COLORS = {
	GREY = { 150, 150, 150, 255 },
	WHITE = { 255, 255, 255, 255 },
	YELLOW = { 255, 200, 50, 255 },
	RED = { 255, 50, 50, 255 },
}

-- Helper: Linear Interpolation for Colors
local function LerpColor(t, c1, c2)
	return {
		math.floor(c1[1] + (c2[1] - c1[1]) * t),
		math.floor(c1[2] + (c2[2] - c1[2]) * t),
		math.floor(c1[3] + (c2[3] - c1[3]) * t),
		255,
	}
end

-- Helper: Get Color based on value and thresholds
local function GetColorForValue(val, t1, t2, t3)
	if val <= t1 then
		local t = val / t1
		return LerpColor(t, COLORS.GREY, COLORS.WHITE)
	elseif val <= t2 then
		local t = (val - t1) / (t2 - t1)
		return LerpColor(t, COLORS.WHITE, COLORS.YELLOW)
	else
		local t = math.min(1, (val - t2) / (t3 - t2))
		return LerpColor(t, COLORS.YELLOW, COLORS.RED)
	end
end

local function now()
	return globals.RealTime()
end

local function reset()
	sections = {}
	stacks = {}
	acc = {}
	display = {}
end

function TickProfiler.SetEnabled(state)
	local shouldEnable = state == true
	if shouldEnable == enabled then
		return
	end

	enabled = shouldEnable

	if not enabled then
		reset()
	end
end

function TickProfiler.IsEnabled()
	return enabled
end

function TickProfiler.BeginSection(name)
	if not enabled then
		return
	end

	local stack = stacks[name]
	if not stack then
		stack = {}
		stacks[name] = stack
	end

	-- Record start time and memory
	local startTime = now()
	local startMem = collectgarbage("count") * 1024 -- Convert to bytes
	stack[#stack + 1] = { time = startTime, mem = startMem }
end

function TickProfiler.EndSection(name)
	if not enabled then
		return
	end

	local stack = stacks[name]
	if not stack or #stack == 0 then
		return
	end

	local startData = stack[#stack]
	stack[#stack] = nil

	local elapsed = now() - startData.time
	if elapsed < 0 then
		elapsed = 0
	end

	-- Calculate memory delta
	local endMem = collectgarbage("count") * 1024
	local memDelta = endMem - startData.mem
	-- Don't clamp memory delta to 0, negative means freed memory (which is good/interesting)

	-- Initialize accumulator for this section if needed
	local section = acc[name]
	if not section then
		section = {
			total = 0,
			samples = 0,
			peak = 0,
			memTotal = 0,
			memPeak = 0,
			-- Display values (smoothed)
			dispAvg = 0,
			dispPeak = 0,
			dispMemAvg = 0,
			dispMemPeak = 0,
		}
		acc[name] = section
	end

	-- Update accumulator
	section.total = section.total + elapsed
	section.samples = section.samples + 1
	if elapsed > section.peak then
		section.peak = elapsed
	end

	section.memTotal = section.memTotal + memDelta
	if memDelta > section.memPeak then
		section.memPeak = memDelta
	end
end

-- Alias for Measure
function TickProfiler.Guard(name, fn, ...)
	return TickProfiler.Measure(name, fn, ...)
end

function TickProfiler.Measure(name, fn, ...)
	if not enabled then
		return fn(...)
	end
	if type(fn) ~= "function" then
		return
	end

	TickProfiler.BeginSection(name)
	local results = { pcall(fn, ...) }
	TickProfiler.EndSection(name)

	if not results[1] then
		error(results[2])
	end

	return table.unpack(results, 2)
end

function TickProfiler.Reset()
	reset()
end

function TickProfiler.GetSections()
	return acc
end

local function buildEntries()
	local currentTick = globals.TickCount()

	-- Update smoothed values periodically
	if currentTick - lastSnapshot >= SNAPSHOT_INTERVAL then
		lastSnapshot = currentTick

		for name, data in pairs(acc) do
			local avg = data.samples > 0 and (data.total / data.samples) or 0
			local memAvg = data.samples > 0 and (data.memTotal / data.samples) or 0

			-- Apply smoothing (EMA)
			data.dispAvg = data.dispAvg + (avg - data.dispAvg) * SMOOTHING_FACTOR
			data.dispPeak = data.dispPeak + (data.peak - data.dispPeak) * SMOOTHING_FACTOR
			data.dispMemAvg = data.dispMemAvg + (memAvg - data.dispMemAvg) * SMOOTHING_FACTOR
			data.dispMemPeak = data.dispMemPeak + (data.memPeak - data.dispMemPeak) * SMOOTHING_FACTOR

			-- Reset accumulators for next window
			data.total = 0
			data.samples = 0
			data.peak = 0
			data.memTotal = 0
			data.memPeak = 0
		end
	end

	-- Re-sort periodically to prevent jumping
	if currentTick - lastSortTime >= SORT_DELAY then
		lastSortTime = currentTick
		display = {}

		for name, data in pairs(acc) do
			display[#display + 1] = {
				name = name,
				timeAvg = data.dispAvg * 1000000, -- Convert to microseconds
				timePeak = data.dispPeak * 1000000,
				memAvg = data.dispMemAvg,
				memPeak = data.dispMemPeak,
			}
		end

		table.sort(display, function(a, b)
			-- Sort by Time Avg descending, then Memory Avg descending
			if math.abs(a.timeAvg - b.timeAvg) > 10 then -- 10us threshold for stability
				return a.timeAvg > b.timeAvg
			end
			return a.memAvg > b.memAvg
		end)
	end

	return display
end

local function drawOverlay()
	if not enabled then
		return
	end
	if engine.IsGameUIVisible() or engine.Con_IsVisible() then
		return
	end

	local entries = buildEntries()
	if #entries == 0 then
		return
	end

	draw.SetFont(font)
	local screenW, screenH = draw.GetScreenSize()
	local x = overlayPadding
	local lineHeight = 14

	-- Calculate total height needed
	local headerHeight = lineHeight + 4
	local statsHeight = lineHeight + 4
	local entriesHeight = #entries * lineHeight
	local totalHeight = entriesHeight + headerHeight + statsHeight + overlayPadding

	-- Start from bottom, but ensure we don't overflow top of screen
	local y = screenH - overlayPadding
	local minY = overlayPadding + totalHeight

	-- If we would overflow, start from the top instead
	if minY > screenH then
		y = totalHeight
	end

	-- Helper to format time
	local function formatTime(microseconds)
		if microseconds >= 1000 then
			return string.format("%6.2f ms", microseconds / 1000)
		else
			return string.format("%6.0f µs", microseconds)
		end
	end

	-- Helper to format memory (with sign for negative)
	local function formatMemory(bytes)
		local sign = bytes < 0 and "-" or " "
		local absBytes = math.abs(bytes)

		if absBytes >= 1024 * 1024 then
			return string.format("%s%5.2f MB", sign, absBytes / (1024 * 1024))
		elseif absBytes >= 1024 then
			return string.format("%s%5.2f KB", sign, absBytes / 1024)
		else
			return string.format("%s%5.0f B ", sign, absBytes)
		end
	end

	-- Calculate total measured memory
	local totalMeasuredMem = 0
	for _, entry in ipairs(entries) do
		totalMeasuredMem = totalMeasuredMem + entry.memAvg
	end

	-- Draw entries from bottom to top
	for i = #entries, 1, -1 do
		local entry = entries[i]

		-- Colors
		-- Time: 50us (White) -> 500us (Yellow) -> 2ms (Red)
		local timeColor = GetColorForValue(entry.timeAvg, 50, 500, 2000)

		-- Mem: Handle negative (freed memory) as green, positive uses the gradient
		local memColor
		if entry.memAvg < 0 then
			-- Negative memory (freed) = green (good thing)
			memColor = { 100, 255, 100, 255 }
		else
			-- Positive: 100B (White) -> 1KB (Yellow) -> 10KB (Red)
			memColor = GetColorForValue(entry.memAvg, 100, 1024, 10240)
		end

		local tAvgStr = formatTime(entry.timeAvg)
		local tPeakStr = formatTime(entry.timePeak)
		local mAvgStr = formatMemory(entry.memAvg)
		local mPeakStr = formatMemory(entry.memPeak)

		-- Draw Columns
		local curX = x

		-- Time Avg
		draw.Color(timeColor[1], timeColor[2], timeColor[3], 255)
		draw.Text(curX, y, tAvgStr)
		curX = curX + 70

		-- Time Peak
		draw.Color(150, 150, 150, 255) -- Peak is less important, keep greyish
		draw.Text(curX, y, tPeakStr)
		curX = curX + 70

		-- Separator
		draw.Color(100, 100, 100, 255)
		draw.Text(curX, y, "|")
		curX = curX + 15

		-- Mem Avg
		draw.Color(memColor[1], memColor[2], memColor[3], 255)
		draw.Text(curX, y, mAvgStr)
		curX = curX + 70

		-- Mem Peak
		draw.Color(150, 150, 150, 255)
		draw.Text(curX, y, mPeakStr)
		curX = curX + 70

		-- Separator
		draw.Color(100, 100, 100, 255)
		draw.Text(curX, y, "|")
		curX = curX + 15

		-- Name
		draw.Color(255, 255, 255, 255)
		draw.Text(curX, y, entry.name)

		y = y - lineHeight
	end

	-- Draw Header
	y = y - lineHeight - 4
	draw.SetFont(fontSmall)
	draw.Color(200, 200, 200, 255)

	-- Manual spacing to match columns roughly
	local curX = x
	draw.Text(curX, y, "Time Avg")
	curX = curX + 70
	draw.Text(curX, y, "Time Peak")
	curX = curX + 85
	draw.Text(curX, y, "Mem Avg")
	curX = curX + 70
	draw.Text(curX, y, "Mem Peak")
	curX = curX + 85
	draw.Text(curX, y, "Section Name")

	-- Draw Global Stats
	y = y - lineHeight - 4
	local memUsed = collectgarbage("count") * 1024
	local memStr = string.format("Lua Total: %s | Measured: %s", formatMemory(memUsed), formatMemory(totalMeasuredMem))
	draw.Color(255, 200, 100, 255)
	draw.Text(x, y, memStr)
end

callbacks.Unregister("Draw", "CD_TickProfilerOverlay")
callbacks.Register("Draw", "CD_TickProfilerOverlay", drawOverlay)

return TickProfiler

end)
__bundle_register("Cheater_Detection.Utils.PlayerState", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ PlayerState.lua
     Central storage for per-player runtime data.
     Ensures a single source of truth that is populated only for
     players currently in the server.
]]

local G = require("Cheater_Detection.Utils.Globals")

local PlayerState = {}

---@type table<string, table>
local ActivePlayers = {}
G.PlayerData = ActivePlayers -- Maintain backwards compatibility

local function newVector(vec)
	if not vec then
		return Vector3(0, 0, 0)
	end
	return Vector3(vec.x, vec.y, vec.z)
end

local function newAngles(ang)
	if not ang then
		return EulerAngles(0, 0, 0)
	end
	return EulerAngles(ang.x, ang.y, ang.z)
end

local function createHistoryRecord()
	return {
		Angle = EulerAngles(0, 0, 0),
		Hitboxes = {
			Head = Vector3(0, 0, 0),
			Body = Vector3(0, 0, 0),
		},
		SimTime = 0,
		onGround = true,
		StdDev = 1,
		FiredGun = false,
	}
end

local function createCurrent()
	return {
		Angle = EulerAngles(0, 0, 0),
		Hitboxes = {
			Head = Vector3(0, 0, 0),
			Body = Vector3(0, 0, 0),
		},
		SimTime = 0,
		onGround = true,
		FiredGun = false,
	}
end

local function createInfo()
	return {
		Name = "Unknown",
		IsCheater = false,
		bhop = 0,
		LastOnGround = true,
		LastVelocity = Vector3(0, 0, 0),
		LastStrike = 0,
	}
end

local function createEvidence()
	return {
		TotalScore = 0,
		LastUpdateTick = 0,
		Reasons = {},
	}
end

local function createState()
	return {
		Entity = nil,
		info = createInfo(),
		Evidence = createEvidence(),
		Current = createCurrent(),
		History = { createHistoryRecord() },
		LastSeenTick = 0,
	}
end

---Return the internal storage table (legacy compatibility)
---@return table<string, table>
function PlayerState.GetTable()
	return ActivePlayers
end

---Create or fetch a player's state table
---@param steamID string
---@return table|nil
function PlayerState.Get(steamID)
	if not steamID then
		return nil
	end
	-- steamID = tostring(steamID) -- Use raw key
	return ActivePlayers[steamID]
end

---Create or fetch a player's state table
---@param steamID string
---@return table|nil
function PlayerState.GetOrCreate(steamID)
	if not steamID then
		return nil
	end

	-- steamID = tostring(steamID) -- Use raw key
	local state = ActivePlayers[steamID]
	if not state then
		state = createState()
		ActivePlayers[steamID] = state
	end

	state.LastSeenTick = globals.TickCount()
	return state
end

function PlayerState.GetHistory(steamID)
	local state = PlayerState.GetOrCreate(steamID)
	if not state then
		return nil
	end
	state.History = state.History or { createHistoryRecord() }
	return state.History
end

function PlayerState.PushHistory(steamID, record, maxHistory)
	if not steamID or not record then
		return
	end
	local state = PlayerState.GetOrCreate(steamID)
	if not state then
		return
	end
	state.History = state.History or {}
	state.History[#state.History + 1] = record
	state.Current = record
	local limit = maxHistory or 66
	if #state.History > limit then
		table.remove(state.History, 1)
	end
end

---Attach runtime info from a WrappedPlayer to its state table
---@param wrapped table
---@return table|nil
function PlayerState.AttachWrappedPlayer(wrapped)
	if not wrapped or type(wrapped.GetSteamID64) ~= "function" then
		return nil
	end

	local steamID = wrapped:GetSteamID64()
	if not steamID then
		return nil
	end

	local state = PlayerState.GetOrCreate(steamID)
	if not state then
		return nil
	end
	state.Entity = wrapped:GetRawEntity()

	state.info = state.info or createInfo()

	if wrapped.GetName then
		local name = wrapped:GetName()
		if name and name ~= "" then
			state.info.Name = name
		end
	end

	if wrapped.GetTeamNumber then
		state.info.Team = wrapped:GetTeamNumber()
	end

	return state
end

---Ensure only actively tracked players remain in memory
---@param activeSet table<string, boolean>
function PlayerState.TrimToActive(activeSet)
	if not activeSet then
		return
	end

	for steamID, state in pairs(ActivePlayers) do
		if not activeSet[steamID] then
			-- Preserve persistent data (Evidence, info) but clear tick-based data
			-- This allows Evidence decay to continue even when player is not in current list
			local hasEvidence = state.Evidence and state.Evidence.TotalScore and state.Evidence.TotalScore > 0

			if hasEvidence then
				-- Keep persistent data, clear tick-based data only
				state.Entity = nil
				state.Current = nil
				state.History = nil
				state.LastSeenTick = 0

				if G.Menu and G.Menu.Advanced and G.Menu.Advanced.debug then
					print(
						string.format(
							"[PlayerState] Preserved Evidence for inactive player %s (Score: %.1f)",
							steamID,
							state.Evidence.TotalScore
						)
					)
				end
			else
				-- No evidence, safe to delete entirely
				if G.Menu and G.Menu.Advanced and G.Menu.Advanced.debug then
					print(string.format("[PlayerState] TRIMMING %s (no evidence)", steamID))
				end
				ActivePlayers[steamID] = nil
			end
		end
	end
end

---Remove every tracked player (e.g., on disconnect/map change)
function PlayerState.Reset()
	for steamID in pairs(ActivePlayers) do
		ActivePlayers[steamID] = nil
	end
end

return PlayerState

end)
__bundle_register("Cheater_Detection.Utils.FastPlayers", function(require, _LOADED, __bundle_register, __bundle_modules)
-- fastplayers.lua ─────────────────────────────────────────────────────────
-- FastPlayers: Simplified per-tick cached player lists.
-- Caches self-manage on demand to minimize overhead.

--[[ Imports ]]
local G = require("Cheater_Detection.Utils.Globals")
local Common = require("Cheater_Detection.Utils.Common")
local PlayerState = require("Cheater_Detection.Utils.PlayerState")
local WrappedPlayer = require("Cheater_Detection.Utils.WrappedPlayer")
local TickProfiler = require("Cheater_Detection.Utils.TickProfiler")

--[[ Module Declaration ]]
local FastPlayers = {}

--[[ Local Caches ]]
local cachedAllPlayers = {}
local cachedTeammates = {}
local cachedEnemies = {}
local cachedLocal
local activeSteamIDs = {}
local lastEntityIndices = {} -- Track entity indices from last tick

-- Cache State
local lastUpdateTick = -1
local cachedExcludeLocal = nil

FastPlayers.TeammatesUpdated = false
FastPlayers.EnemiesUpdated = false

--[[ Public API ]]

--- Returns list of valid players, updating cache if necessary.
---@param excludelocal boolean? Pass true to exclude local player, false to include
---@return WrappedPlayer[]
function FastPlayers.GetAll(excludelocal)
	local currentTick = globals.TickCount()

	-- Check if cache is outdated or if the exclusion criteria changed
	if currentTick > lastUpdateTick or cachedExcludeLocal ~= excludelocal then
		local excludePlayer = excludelocal and FastPlayers.GetLocal() or nil

		TickProfiler.BeginSection("FP_FindByClass")
		local entities_list = entities.FindByClass("CTFPlayer") or {}
		local entityCount = #entities_list
		TickProfiler.EndSection("FP_FindByClass")

		-- Fast path: If entity count matches and we have cache (and exclusion mode didn't change), assume no change
		-- Note: We only use fast path if exclusion mode matches, otherwise we MUST rebuild
		TickProfiler.BeginSection("FP_CheckChange")
		local lastCount = #lastEntityIndices
		-- We force rebuild if exclusion mode changed because the list content is different
		local exclusionChanged = (cachedExcludeLocal ~= excludelocal)
		local needsRebuild = exclusionChanged
			or (entityCount ~= lastCount)
			or (#cachedAllPlayers == 0)
			or (currentTick > lastUpdateTick)
		TickProfiler.EndSection("FP_CheckChange")

		-- Actually, the logic above is slightly redundant.
		-- If currentTick > lastUpdateTick, we are here.
		-- We should check if we can reuse the PREVIOUS tick's data?
		-- The user wants to avoid "cycling code".
		-- But if it's a new tick, we MUST validate the entities.
		-- However, we can optimize the wrapping part.

		-- Let's simplify: If we are here, we ARE rebuilding the list for this tick.
		-- But we can optimize by checking if the entity list actually changed from the last time we built it.
		-- But since we don't run every tick, "last time" might be 10 ticks ago.

		TickProfiler.BeginSection("FP_Rebuild")

		-- Clear old data
		cachedAllPlayers = {}
		activeSteamIDs = {}
		lastEntityIndices = {}

		-- Build new player list and indices
		for _, ent in pairs(entities_list) do
			local excludeEntity = excludePlayer and excludePlayer.GetRawEntity and excludePlayer:GetRawEntity() or nil
			if Common.IsValidPlayer(ent, nil, false, excludeEntity) then
				local wrapped = WrappedPlayer.FromEntity(ent)
				if wrapped then
					cachedAllPlayers[#cachedAllPlayers + 1] = wrapped
					lastEntityIndices[#lastEntityIndices + 1] = ent:GetIndex()

					local steamID = wrapped:GetSteamID64()
					if steamID then
						activeSteamIDs[steamID] = true
					end
				end
			end
		end

		-- Clean up disconnected players from wrapper pool
		if WrappedPlayer and WrappedPlayer.PruneInactive then
			WrappedPlayer.PruneInactive(currentTick)
		end

		TickProfiler.EndSection("FP_Rebuild")

		-- Update state
		lastUpdateTick = currentTick
		cachedExcludeLocal = excludelocal

		-- Invalidate derived caches
		cachedTeammates = {}
		cachedEnemies = {}
		FastPlayers.TeammatesUpdated = false
		FastPlayers.EnemiesUpdated = false

		-- No periodic trimming - PlayerState persists until player_disconnect event
	end

	return cachedAllPlayers
end

--- Returns the local player as a WrappedPlayer instance.
---@return WrappedPlayer?
function FastPlayers.GetLocal()
	-- Always check validity, but reuse wrapper if possible
	if not cachedLocal or not cachedLocal:IsValid() then
		local rawLocal = entities.GetLocalPlayer()
		cachedLocal = rawLocal and WrappedPlayer.FromEntity(rawLocal) or nil
	else
		-- Ensure the wrapper is up to date for this tick (handled by WrappedPlayer internally usually, but good to be safe)
		-- WrappedPlayer.FromEntity will just return the existing wrapper if valid
		local rawLocal = entities.GetLocalPlayer()
		if rawLocal and rawLocal:GetIndex() ~= cachedLocal:GetIndex() then
			cachedLocal = WrappedPlayer.FromEntity(rawLocal)
		end
	end
	return cachedLocal
end

--- Returns list of teammates, optionally excluding a player (or the local player).
---@param exclude boolean|WrappedPlayer? Pass `true` to exclude the local player, or a WrappedPlayer instance to exclude that specific teammate. Omit/nil to include everyone.
---@return WrappedPlayer[]
function FastPlayers.GetTeammates(exclude)
	-- Ensure main list is up to date
	FastPlayers.GetAll()

	if not FastPlayers.TeammatesUpdated then
		-- cachedTeammates is already cleared in GetAll rebuild

		-- Determine which player (if any) to exclude
		local localPlayer = FastPlayers.GetLocal()
		local excludePlayer = nil
		if exclude == true then
			excludePlayer = localPlayer -- explicitly exclude self
		elseif type(exclude) == "table" then
			excludePlayer = exclude
		end

		-- Use local player's team for filtering
		local myTeam = localPlayer and localPlayer:GetTeamNumber() or nil
		if myTeam then
			for _, wp in ipairs(cachedAllPlayers) do
				if wp:GetTeamNumber() == myTeam and wp ~= excludePlayer then
					cachedTeammates[#cachedTeammates + 1] = wp
				end
			end
		end

		FastPlayers.TeammatesUpdated = true
	end
	return cachedTeammates
end

--- Returns list of enemies (players on a different team).
---@return WrappedPlayer[]
function FastPlayers.GetEnemies()
	-- Ensure main list is up to date
	FastPlayers.GetAll()

	if not FastPlayers.EnemiesUpdated then
		-- cachedEnemies is already cleared in GetAll rebuild
		local pLocal = FastPlayers.GetLocal()
		if pLocal then
			local myTeam = pLocal:GetTeamNumber()
			for _, wp in ipairs(cachedAllPlayers) do
				if wp:GetTeamNumber() ~= myTeam then
					cachedEnemies[#cachedEnemies + 1] = wp
				end
			end
		end
		FastPlayers.EnemiesUpdated = true
	end
	return cachedEnemies
end

return FastPlayers

end)
__bundle_register("Cheater_Detection.Utils.WrappedPlayer", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ WrappedPlayer.lua ]]
--
-- A proper wrapper for player entities that extends lnxLib's WPlayer

-- Get required modules
local Common = require("Cheater_Detection.Utils.Common")
local PlayerState = require("Cheater_Detection.Utils.PlayerState")
local G = require("Cheater_Detection.Utils.Globals")

assert(Common, "Common is nil")
local WPlayer = Common.WPlayer
assert(WPlayer, "WPlayer is nil")

---@class WrappedPlayer
---@field _basePlayer table Base WPlayer from lnxLib
---@field _rawEntity Entity Raw entity object
local WrappedPlayer = {}

local WrapperPool = {}

local function hydrateWrapper(wrapped, entity, cachedSteamID)
	local currentIndex = entity:GetIndex()

	-- Optimization: Reuse existing WPlayer if it matches the entity index
	-- We use a cached integer index to avoid function call overhead
	if wrapped._basePlayer and wrapped._cachedIndex == currentIndex then
		-- Update the raw entity reference (in case userdata changed)
		wrapped._rawEntity = entity
		wrapped._lastSeenTick = globals.TickCount()
		return wrapped
	end

	local basePlayer = WPlayer.FromEntity(entity)
	if not basePlayer then
		return nil
	end

	-- Minimal per-instance data (cache created on-demand)
	wrapped._basePlayer = basePlayer
	wrapped._rawEntity = entity
	wrapped._cachedIndex = currentIndex -- Cache the index for fast checks
	wrapped._lastSeenTick = globals.TickCount()

	-- Initialize persistent cache tables if missing
	if not wrapped._cache then
		wrapped._cache = {}
	end
	if not wrapped._cacheTs then
		wrapped._cacheTs = {}
	end

	-- Get and cache SteamID once (reuse passed value to avoid duplicate conversion)
	if not wrapped._steamID64 then
		local steamID = cachedSteamID or Common.GetSteamID64(basePlayer)
		if steamID then
			wrapped._steamID64 = steamID

			-- Attach PlayerState only if needed
			if PlayerState then
				wrapped._state = PlayerState.AttachWrappedPlayer(wrapped)
			end
		end
	end

	return wrapped
end

-- Instance metatable that forwards unknown lookups to the base WPlayer
local WrappedPlayerMT = {}

-- Optimized cacheValue using per-key timestamps
-- This avoids clearing the cache table every tick (saving cycles)
-- Old values stay in memory (minor leak) but are ignored if outdated
local function cacheValue(self, key, computeFn)
	-- Use rawget to bypass metatable and avoid name collisions with basePlayer methods
	if type(self) ~= "table" then
		return computeFn()
	end

	local currentTick = globals.TickCount()

	-- Access internal cache tables directly (bypassing metatable)
	local cacheTs = rawget(self, "_cacheTs")
	if not cacheTs then
		rawset(self, "_cacheTs", {})
		rawset(self, "_cache", {})
		cacheTs = rawget(self, "_cacheTs")
	end

	local cache = rawget(self, "_cache")
	local lastTick = cacheTs[key]

	-- Check if valid for this tick
	if lastTick == currentTick then
		return cache[key]
	end

	-- Compute and cache
	local result = computeFn()
	if result ~= nil then
		cache[key] = result
		cacheTs[key] = currentTick
	end
	return result
end

local function wrapCall(target, method)
	if type(method) ~= "function" then
		return method
	end
	return function(_, ...)
		return method(target, ...)
	end
end

function WrappedPlayerMT.__index(self, key)
	-- 1) Custom helpers defined on WrappedPlayer
	local custom = WrappedPlayer[key]

	if custom ~= nil then
		return custom
	end

	-- 2) Fallback to lnxLib WPlayer (already proxies to raw entity)
	local basePlayer = rawget(self, "_basePlayer")
	if basePlayer then
		local value = basePlayer[key]
		if value ~= nil then
			return wrapCall(basePlayer, value)
		end
	end

	-- 3) Expose raw entity fields as a last resort
	local rawEntity = rawget(self, "_rawEntity")
	if rawEntity then
		local rawValue = rawEntity[key]
		if rawValue ~= nil then
			return wrapCall(rawEntity, rawValue)
		end
	end

	return nil
end

--- Creates a new WrappedPlayer from a TF2 entity
---@param entity Entity The entity to wrap
---@return WrappedPlayer|nil The wrapped player or nil if invalid
function WrappedPlayer.FromEntity(entity)
	if not entity or not entity:IsValid() then
		return nil
	end

	-- Use SteamID64 as the primary key for caching if available
	local steamID = Common.GetSteamID64(entity)
	local key = steamID and tostring(steamID) or entity:GetIndex()

	local wrapped = WrapperPool[key]
	if not wrapped then
		wrapped = setmetatable({}, WrappedPlayerMT)
		WrapperPool[key] = wrapped
	end

	-- Pass steamID to avoid duplicate GetSteamID64 call in hydrateWrapper
	if not hydrateWrapper(wrapped, entity, steamID) then
		WrapperPool[key] = nil
		return nil
	end

	return wrapped
end

--- Create WrappedPlayer from index
---@param index number The entity index
---@return WrappedPlayer|nil The wrapped player or nil if invalid
function WrappedPlayer.FromIndex(index)
	local entity = entities.GetByIndex(index)
	return entity and WrappedPlayer.FromEntity(entity) or nil
end

--- Returns the underlying raw entity
function WrappedPlayer:GetRawEntity()
	return self._rawEntity
end

--- Resets per-tick cache (No-op now, handled by timestamps)
function WrappedPlayer:ResetCache()
	-- No-op: We use timestamps now
end

--- Returns the base WPlayer from lnxLib
function WrappedPlayer:GetBasePlayer()
	return self._basePlayer
end

--- Checks if a given entity is valid
---@param checkFriend boolean? Check if the entity is a friend
---@param checkDormant boolean? Check if the entity is dormant
---@param skipEntity Entity? Optional entity to skip
---@return boolean Whether the entity is valid
function WrappedPlayer:IsValidPlayer(checkFriend, checkDormant, skipEntity)
	return Common.IsValidPlayer(self._rawEntity, checkFriend, checkDormant, skipEntity)
end

--- Get SteamID64 for this player object
---@return string|number The player's SteamID64
function WrappedPlayer:GetSteamID64()
	-- Use rawget to access the cached value directly
	-- This is CRITICAL to prevent infinite recursion if self._steamID64 triggers __index
	local cached = rawget(self, "_steamID64")
	if cached then
		return cached
	end

	-- If not in cache (which shouldn't happen often due to hydrateWrapper), try to fetch it
	local steamID = Common.GetSteamID64(self._basePlayer)
	if steamID then
		self._steamID64 = steamID
		return steamID
	end

	return nil
end

--- Get SteamID3 for this player object
---@return string|nil
function WrappedPlayer:GetSteamID3()
	if not self._steamID3 then
		local steamID64 = self:GetSteamID64()
		local numeric = tonumber(steamID64)
		if numeric then
			local accountID = numeric - 76561197960265728
			if accountID and accountID >= 0 then
				self._steamID3 = string.format("[U:1:%d]", accountID)
			end
		end
	end
	return self._steamID3
end

--- Returns PlayerState entry associated with this player
---@return table|nil
function WrappedPlayer:GetState()
	if not PlayerState then
		return nil
	end
	if not self._state then
		self._state = PlayerState.AttachWrappedPlayer(self)
	end
	return self._state
end

function WrappedPlayer:GetEvidence()
	local state = self:GetState()
	if not state then
		return nil
	end
	state.Evidence = state.Evidence or {}
	return state.Evidence
end

function WrappedPlayer:GetData()
	return self:GetState()
end

function WrappedPlayer:GetInfo()
	local state = self:GetState()
	if not state then
		return nil
	end
	state.info = state.info or {}
	return state.info
end

function WrappedPlayer:GetHistory()
	if not PlayerState then
		return nil
	end
	local steamID = self:GetSteamID64()
	if not steamID then
		return nil
	end
	return PlayerState.GetHistory(steamID)
end

function WrappedPlayer:PushHistory(record, maxHistory)
	if not PlayerState then
		return
	end
	local steamID = self:GetSteamID64()
	if not steamID then
		return
	end
	PlayerState.PushHistory(steamID, record, maxHistory or Common.MAX_HISTORY or 66)
end

--- Check if player is on the ground via m_fFlags
---@return boolean Whether the player is on the ground
function WrappedPlayer:IsOnGround()
	local flags = self._basePlayer:GetPropInt("m_fFlags")
	return (flags & FL_ONGROUND) ~= 0
end

function WrappedPlayer:IsAlive()
	return self._rawEntity and self._rawEntity:IsAlive() or false
end

function WrappedPlayer:IsDormant()
	return cacheValue(self, "isDormant", function()
		return self._rawEntity and self._rawEntity:IsDormant() or true
	end)
end

function WrappedPlayer:IsFriend(includeParty)
	return Common.IsFriend(self._rawEntity, includeParty)
end

function WrappedPlayer:IsEnemyOf(other)
	if not other or type(other.GetTeamNumber) ~= "function" then
		return false
	end
	local myTeam = self._rawEntity and self._rawEntity:GetTeamNumber()
	return myTeam ~= nil and myTeam ~= 0 and myTeam ~= other:GetTeamNumber()
end

--- Returns the view offset from the player's origin as a Vector3
---@return Vector3 The player's view offset
function WrappedPlayer:GetViewOffset()
	return cacheValue(self, "viewOffset", function()
		return self._basePlayer:GetPropVector("localdata", "m_vecViewOffset[0]")
	end)
end

--- Returns the player's eye position in world coordinates
---@return Vector3 The player's eye position
function WrappedPlayer:GetEyePos()
	return cacheValue(self, "eyePos", function()
		local origin = self:GetAbsOrigin()
		local offset = self:GetViewOffset()
		if origin and offset then
			return origin + offset
		end
		return nil
	end)
end

--- Returns the player's eye angles as an EulerAngles object
---@return EulerAngles The player's eye angles
function WrappedPlayer:GetEyeAngles()
	return cacheValue(self, "eyeAngles", function()
		local ang = self._basePlayer:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]")
		if ang then
			return EulerAngles(ang.x, ang.y, ang.z)
		end
		return nil
	end)
end

function WrappedPlayer:GetAbsOrigin()
	return cacheValue(self, "absOrigin", function()
		return self._basePlayer:GetAbsOrigin()
	end)
end

function WrappedPlayer:GetVelocity()
	return cacheValue(self, "velocity", function()
		return self._basePlayer:EstimateAbsVelocity()
	end)
end

--- Returns the world position the player is looking at by tracing a ray
---@return Vector3|nil The look position or nil if trace failed
function WrappedPlayer:GetLookPos()
	return cacheValue(self, "lookPos", function()
		local eyePos = self:GetEyePos()
		local eyeAng = self:GetEyeAngles()
		if not eyePos or not eyeAng then
			return nil
		end
		local targetPos = eyePos + eyeAng:Forward() * 8192
		local tr = engine.TraceLine(eyePos, targetPos, MASK_SHOT)
		return tr and tr.endpos or nil
	end)
end

--- Returns the currently active weapon wrapper
---@return table|nil The active weapon wrapper or nil
function WrappedPlayer:GetActiveWeapon()
	local w = self._basePlayer:GetPropEntity("m_hActiveWeapon")
	return w and Common.WWeapon.FromEntity(w) or nil
end

function WrappedPlayer:GetActiveWeaponID()
	return cacheValue(self, "weaponID", function()
		local weapon = self:GetActiveWeapon()
		if weapon and weapon.GetWeaponID then
			return weapon:GetWeaponID()
		end
		return nil
	end)
end

function WrappedPlayer:GetWeaponChargeData()
	return cacheValue(self, "weaponCharge", function()
		local weapon = self:GetActiveWeapon()
		if not weapon then
			return nil
		end
		return {
			ChargeBegin = weapon.GetChargeBeginTime and weapon:GetChargeBeginTime() or 0,
			ChargedDamage = weapon.GetChargedDamage and weapon:GetChargedDamage() or 0,
		}
	end)
end

--- Returns the player's observer mode
---@return number The observer mode
function WrappedPlayer:GetObserverMode()
	return self._basePlayer:GetPropInt("m_iObserverMode")
end

--- Returns the player's observer target wrapper
---@return WrappedPlayer|nil The observer target or nil
function WrappedPlayer:GetObserverTarget()
	local target = self._basePlayer:GetPropEntity("m_hObserverTarget")
	return target and WrappedPlayer.FromEntity(target) or nil
end

--- Returns the next attack time
---@return number The next attack time
function WrappedPlayer:GetNextAttack()
	return self._basePlayer:GetPropFloat("m_flNextAttack")
end

function WrappedPlayer:GetTeamNumber()
	return self._basePlayer:GetTeamNumber()
end

function WrappedPlayer:SetPriority(level)
	if not level then
		return false
	end
	local success = pcall(playerlist.SetPriority, self._rawEntity or self._basePlayer, level)
	return success
end

function WrappedPlayer:IsCheater()
	local info = self:GetInfo()
	return info and info.IsCheater or false
end

function WrappedPlayer:MarkCheater(reason)
	local info = self:GetInfo()
	if not info then
		return
	end
	info.IsCheater = true
	info.CheaterReason = reason or info.CheaterReason
end

function WrappedPlayer.PruneInactive(currentTick)
	currentTick = currentTick or globals.TickCount()
	-- Allow 1 tick grace period so we don't wipe the pool before updating it
	local threshold = currentTick - 1
	for index, wrapped in pairs(WrapperPool) do
		if not wrapped or wrapped._lastSeenTick < threshold then
			WrapperPool[index] = nil
		end
	end
end

function WrappedPlayer.ResetPool()
	for index in pairs(WrapperPool) do
		WrapperPool[index] = nil
	end
end

return WrappedPlayer

end)
__bundle_register("Cheater_Detection.Detection Methods.manual_priority", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Manual Priority Enforcement ]]
--
-- Awards evidence when a player is manually assigned priority 10 in Lmaobox.
-- Meant to integrate with the AutoFlagPriorityTen option to mark custom cheaters.

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local Evidence = require("Cheater_Detection.Core.Evidence_system")

--[[ Module Declaration ]]
local ManualPriority = {}

--[[ Configuration ]]
local DETECTION_NAME = "manual_priority"
local EVIDENCE_WEIGHT = 100 -- Immediate threshold push

-- Track last tick we awarded evidence per steamID to avoid double counting in same frame
local lastTriggerTick = {}

--[[ Helper Functions ]]
local function shouldRun()
	local advanced = G.Menu and G.Menu.Advanced
	return advanced and advanced.AutoFlagPriorityTen == true
end

local function validatePlayer(player)
	if not player or not player:IsValid() or not player:IsAlive() or player:IsDormant() then
		return false
	end
	return true
end

--[[ Public Functions ]]
function ManualPriority.Check(player)
	if not shouldRun() then
		return false
	end

	if not validatePlayer(player) then
		return false
	end

	local steamID = Common.GetSteamID64(player)
	if not Common.IsSteamID64(steamID) then
		return false
	end
	steamID = tostring(steamID)

	if Evidence.IsMarkedCheater(steamID) then
		return false
	end

	local priority = playerlist.GetPriority(steamID)
	if priority ~= 10 then
		lastTriggerTick[steamID] = nil
		return false
	end

	local currentTick = globals.TickCount()
	if lastTriggerTick[steamID] == currentTick then
		return false
	end

	lastTriggerTick[steamID] = currentTick

	Evidence.AddEvidence(steamID, DETECTION_NAME, EVIDENCE_WEIGHT)

	if G.Menu.Advanced.debug then
		print(string.format("[ManualPriority] %s flagged via priority 10", player:GetName() or steamID))
	end

	return true
end

return ManualPriority

end)
__bundle_register("Cheater_Detection.Detection Methods.warp_dt", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Warp / Doubletap Detection ]]
--
-- Detects time manipulation exploits using statistical analysis of simulation time
-- Uses standard deviation of tick deltas to identify sequence burst patterns

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local Evidence = require("Cheater_Detection.Core.Evidence_system")
local PlayerState = require("Cheater_Detection.Utils.PlayerState")

--[[ Module Declaration ]]
local WarpDT = {}

local DETECTION_NAME = "warp_dt"
local EVIDENCE_WEIGHT = 100 -- Instant ban - blatant exploit
local HISTORY_SIZE = 33 -- Ticks to analyze
local MIN_DELTA_SAMPLES = 30 -- Minimum samples for statistical analysis
local WARP_STDDEV_SIGNATURE = -132 -- Specific standard deviation value indicating warp
local TICK_TOLERANCE = 13 -- Tolerance for tick interval checks

-- Minimal per-player state
local playerWarpData = {}

--[[ Helper Functions ]]
local function validatePlayer(player)
	if not player or not player:IsValid() or not player:IsAlive() or player:IsDormant() then
		return false
	end
	return true
end

local function getPlayerState(steamID)
	local state = playerWarpData[steamID]
	if not state then
		state = {
			lastTickCount = nil,
		}
		playerWarpData[steamID] = state
	end
	return state
end

local function timeToTicks(time)
	return Common.Conversion.Time_to_Ticks(time)
end

local function collectSimTimeTicks(steamID)
	local state = PlayerState.Get(steamID)
	if not state or not state.History then
		return nil
	end

	local history = state.History
	local total = #history
	if total < HISTORY_SIZE then
		return nil
	end

	local ticks = {}
	local startIndex = math.max(1, total - HISTORY_SIZE + 1)
	for i = startIndex, total do
		local entry = history[i]
		local simTime = entry and (entry.sim_time or entry.SimTime)
		if not simTime then
			return nil
		end
		ticks[#ticks + 1] = timeToTicks(simTime)
	end

	if #ticks < HISTORY_SIZE then
		return nil
	end

	return ticks
end

--[[ Public Functions ]]
function WarpDT.Check(player)
	-- Skip if detection disabled in menu
	if not G.Menu.Advanced.Warp then
		return false
	end

	-- Validate player
	if not validatePlayer(player) then
		return false
	end

	-- Get steamID for tracking
	local steamID = tostring(Common.GetSteamID64(player))
	if not Common.IsSteamID64(steamID) then
		return false
	end

	-- Skip if already marked as cheater
	if Evidence.IsMarkedCheater(steamID) then
		return false
	end

	local playerState = getPlayerState(steamID)

	local simTicks = collectSimTimeTicks(steamID)
	if not simTicks then
		return false
	end

	local deltaTicks = {}
	for i = 2, #simTicks do
		deltaTicks[#deltaTicks + 1] = simTicks[i] - simTicks[i - 1]
	end

	if #deltaTicks < MIN_DELTA_SAMPLES then
		return false
	end

	-- Calculate mean delta
	local meanDelta = 0
	for _, delta in ipairs(deltaTicks) do
		meanDelta = meanDelta + delta
	end
	meanDelta = meanDelta / #deltaTicks

	-- Calculate variance
	local sumSquaredDiff = 0
	for _, delta in ipairs(deltaTicks) do
		local diff = delta - meanDelta
		sumSquaredDiff = sumSquaredDiff + diff * diff
	end

	local variance = sumSquaredDiff / (#deltaTicks - 1)
	local stdDev = math.sqrt(variance)

	--[[ 
		MAGIC FIX EXPLANATION:
		When a player manipulates tickbase (warp/doubletap) with extreme values (e.g. -2000 ticks),
		the variance calculation overflows or corrupts due to floating point precision issues with
		massive negative deltas.
		
		In Lua/Source Engine, `math.sqrt(corrupted_variance)` often results in `-nan(ind)` or `-inf`.
		However, due to a specific engine quirk/compiler behavior, `math.max(-132, NaN)` or 
		`math.max(-132, -inf)` reliably resolves to exactly -132.
		
		This "magic number" -132 acts as a catch-all bucket for these mathematical impossibilities
		that only occur during heavy tickbase manipulation.
	]]
	stdDev = math.max(-132, stdDev)

	-- Check tick interval consistency (avoid false positives from script lag)
	local currentTick = globals.TickCount()
	if not playerState.lastTickCount then
		playerState.lastTickCount = currentTick
	else
		local tickInterval = globals.TickInterval()
		local expectedInterval = (currentTick - playerState.lastTickCount) / tickInterval

		-- If ticks are inconsistent, may be our own lag - skip
		if math.abs(currentTick - playerState.lastTickCount) < expectedInterval + TICK_TOLERANCE then
			playerState.lastTickCount = currentTick
			return false
		end

		playerState.lastTickCount = currentTick
	end

	-- Detect warp signature
	if stdDev == WARP_STDDEV_SIGNATURE then
		Evidence.AddEvidence(steamID, DETECTION_NAME, EVIDENCE_WEIGHT)

		if G.Menu.Advanced.debug then
			print(string.format("[WarpDT] %s - Sequence burst detected (stdDev: %.0f)", player:GetName(), stdDev))
		end

		return true
	end

	return false
end

return WarpDT

end)
__bundle_register("Cheater_Detection.Detection Methods.fake_lag", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Fake Lag Detection ]]
--
-- Detects packet choking (fakelag, doubletap) by monitoring simulation time delta

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local Evidence = require("Cheater_Detection.Core.Evidence_system")

--[[ Module Declaration ]]
local FakeLag = {}

--[[ Configuration ]]
local DETECTION_NAME = "fake_lag"
local EVIDENCE_WEIGHT = 22 -- High weight - exploit
local MAX_TICK_DELTA = 14 -- Increased to prevent false positives on laggy bots/players

-- Per-player state tracking
local playerSimTimeData = {}

--[[ Helper Functions ]]
local function validatePlayer(player)
	if not player or not player:IsValid() or not player:IsAlive() or player:IsDormant() then
		return false
	end
	return true
end

local function initPlayerData(steamID)
	if not playerSimTimeData[steamID] then
		playerSimTimeData[steamID] = {
			lastSimTime = nil,
		}
	end
end

local function timeToTicks(time)
	return math.floor(time / globals.TickInterval() + 0.5)
end

--[[ Public Functions ]]
function FakeLag.Check(player)
	-- Skip if detection disabled in menu
	if not G.Menu.Advanced.Choke then
		return false
	end

	-- Validate player
	if not validatePlayer(player) then
		return false
	end

	-- Get steamID for tracking
	local steamID = Common.GetSteamID64(player)
	if not Common.IsSteamID64(steamID) then
		return false
	end
	steamID = tostring(steamID)

	-- Skip if already marked as cheater
	if Evidence.IsMarkedCheater(steamID) then
		return false
	end

	-- Initialize tracking data
	initPlayerData(steamID)
	local data = playerSimTimeData[steamID]

	-- Get current simulation time
	local currentSimTime = player:GetSimulationTime()
	if not currentSimTime then
		return false
	end

	-- Need previous simtime for comparison
	if not data.lastSimTime then
		data.lastSimTime = currentSimTime
		return false
	end

	-- Calculate delta
	local delta = currentSimTime - data.lastSimTime

	-- Skip if rewinding (demo playback or local player lag compensation)
	if delta == 0 then
		return false
	end

	-- Convert to ticks
	local deltaTicks = timeToTicks(delta)

	-- Detect excessive tick delta (choking packets)
	if deltaTicks >= MAX_TICK_DELTA then
		Evidence.AddEvidence(steamID, DETECTION_NAME, EVIDENCE_WEIGHT)

		if G.Menu.Advanced.debug then
			print(
				string.format(
					"[FakeLag] %s - Tick delta: %d (threshold: %d)",
					player:GetName(),
					deltaTicks,
					MAX_TICK_DELTA
				)
			)
		end

		data.lastSimTime = currentSimTime
		return true
	end

	-- Update last simtime
	data.lastSimTime = currentSimTime
	return false
end

return FakeLag

end)
__bundle_register("Cheater_Detection.Detection Methods.Duck_Speed", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Duck Speed Detection ]]

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local Evidence = require("Cheater_Detection.Core.Evidence_system")

--[[ Module Declaration ]]
local DuckSpeed = {}

--[[ Configuration ]]
local DETECTION_NAME = "Duck_Speed"
local EVIDENCE_WEIGHT = 20 -- Higher weight - movement exploit
local VIOLATION_TICKS_REQUIRED = 66 -- 1 second of violation
local DUCK_SPEED_MULTIPLIER = 0.66 -- TF2 duck speed penalty
local FULLY_CROUCHED_VIEW_OFFSET = 45 -- View offset Z when fully crouched

-- Per-player state tracking
local playerDuckData = {}

--[[ Helper Functions ]]
local function validatePlayer(player)
	if not player or not player:IsValid() or not player:IsAlive() or player:IsDormant() then
		return false
	end
	return true
end

local function initPlayerData(steamID)
	if not playerDuckData[steamID] then
		playerDuckData[steamID] = {
			violationTicks = 0,
			lastDecayTick = 0,
		}
	end
end

--[[ Public Functions ]]
function DuckSpeed.Check(player)
	-- Skip if detection disabled in menu
	if not G.Menu.Advanced.DuckSpeed then
		return false
	end

	-- Validate player
	if not validatePlayer(player) then
		return false
	end

	-- Get steamID for tracking
	local steamID = Common.GetSteamID64(player)
	if not Common.IsSteamID64(steamID) then
		return false
	end
	steamID = tostring(steamID)

	-- Skip if already marked as cheater
	if Evidence.IsMarkedCheater(steamID) then
		return false
	end

	-- Initialize tracking data
	initPlayerData(steamID)
	local data = playerDuckData[steamID]

	-- Get raw entity for prop access
	local entity = player:GetRawEntity()
	if not entity then
		return false
	end

	-- Check flags
	local flags = player:GetPropInt("m_fFlags")
	local onGround = (flags & FL_ONGROUND) ~= 0
	local ducking = (flags & FL_DUCKING) ~= 0

	-- Only check when on ground and ducking
	if not (onGround and ducking) then
		data.violationTicks = 0
		return false
	end

	-- Get max speed and current velocity
	local maxSpeed = entity:GetPropFloat("m_flMaxspeed")
	local velocity = entity:EstimateAbsVelocity()

	if not maxSpeed or not velocity then
		return false
	end

	local currentSpeed = velocity:Length()
	local maxDuckSpeed = maxSpeed * DUCK_SPEED_MULTIPLIER

	-- Check if exceeding duck speed limit
	if currentSpeed >= maxDuckSpeed then
		-- Verify fully crouched via view offset
		local viewOffset = player:GetViewOffset()
		if viewOffset and math.floor(viewOffset.z) == FULLY_CROUCHED_VIEW_OFFSET then
			data.violationTicks = data.violationTicks + 1

			-- Require sustained violation (1 second = 66 ticks)
			if data.violationTicks >= VIOLATION_TICKS_REQUIRED then
				-- Check cooldown (1 second)
				local currentTick = globals.TickCount()
				if currentTick - data.lastDecayTick >= 66 then
					Evidence.AddEvidence(steamID, DETECTION_NAME, 25, { manualDecay = true })
					data.lastDecayTick = currentTick

					if G.Menu.Advanced.debug then
						print(
							string.format(
								"[DuckSpeed] %s - Speed: %.1f / Max: %.1f (%.0f%% over limit)",
								player:GetName(),
								currentSpeed,
								maxDuckSpeed,
								(currentSpeed / maxDuckSpeed - 1) * 100
							)
						)
					end
				end

				-- Reset counter
				data.violationTicks = 0
				return true
			end
		end
	else
		-- Reset violation counter if not violating
		data.violationTicks = 0

		-- Apply manual decay when obeying speed limit
		-- Decay 5 points per second (approx) -> 0.075 per tick
		-- Only decay if we have evidence
		if Evidence.GetMethodWeight(steamID, DETECTION_NAME) > 0 then
			Evidence.ApplyDecayForMethod(steamID, DETECTION_NAME, 0.075)
		end
	end

	return false
end

return DuckSpeed

end)
__bundle_register("Cheater_Detection.Detection Methods.bhop", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Bunny Hop Detection ]]

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local Evidence = require("Cheater_Detection.Core.Evidence_system")

--[[ Module Declaration ]]
local Bhop = {}

--[[ Configuration ]]
local DETECTION_NAME = "bhop"
local EVIDENCE_WEIGHT_BASE = 5
local DECAY_AMOUNT = 2.0 -- Weight to remove on failed bhop
local GROUND_TICKS_FOR_DECAY = 5 -- Must be grounded for this many ticks before decay applies

-- Per-player state tracking
local playerBhopData = {}

local function initPlayerData(steamID)
	if not playerBhopData[steamID] then
		playerBhopData[steamID] = {
			lastOnGround = true, -- Track last ground state
			lastVelocityZ = 0, -- Track last velocity for jump detection
			groundedTicks = 0, -- Track how long player has been grounded
			decayApplied = false, -- Track if we already applied decay for this ground period
			hasJumped = false, -- Track if player has ever jumped (prevents initial false positives)
		}
	end
end

--[[ Public Functions ]]
function Bhop.Check(player)
	-- Skip if detection disabled in menu
	if not G.Menu.Advanced.Bhop then
		return false
	end

	-- Validate player
	if not Common.IsValidPlayer(player, true, false) then
		return false
	end

	-- Get steamID for tracking
	local steamID = Common.GetSteamID64(player)
	if not Common.IsSteamID64(steamID) then
		return false
	end
	steamID = tostring(steamID)

	-- Skip if already marked as cheater
	if Evidence.IsMarkedCheater(steamID) then
		return false
	end

	-- Initialize tracking data
	initPlayerData(steamID)
	local data = playerBhopData[steamID]

	-- Get raw entity for velocity access
	local entity = player:GetRawEntity()
	if not entity then
		return false
	end

	-- Get velocity for jump detection
	local velocity = entity:EstimateAbsVelocity()
	if not velocity then
		return false
	end

	-- Check ground state (matches old CheckBhop logic)
	local flags = player:GetPropInt("m_fFlags")
	local onGround = (flags & FL_ONGROUND) ~= 0

	if onGround then
		-- Player on ground - increment grounded tick counter
		data.groundedTicks = data.groundedTicks + 1

		-- Only apply decay if they've been grounded long enough AND have jumped before
		if data.hasJumped and data.groundedTicks >= GROUND_TICKS_FOR_DECAY and not data.decayApplied then
			-- They stayed grounded for 2+ ticks - bhop sequence ended
			Evidence.ApplyDecayForMethod(steamID, DETECTION_NAME, DECAY_AMOUNT)

			if G.Menu.Advanced.debug then
				print(
					string.format(
						"[Bhop] %s - Landed (stopped bhopping) -%.1f evidence",
						player:GetName(),
						DECAY_AMOUNT
					)
				)
			end

			data.decayApplied = true -- Mark decay as applied for this ground period
		end

		data.lastOnGround = true
	else
		-- Player in air - check if they jumped (velocity increased AND exact jump values)
		if data.lastOnGround and data.lastVelocityZ < velocity.z and (velocity.z == 271 or velocity.z == 277) then
			-- Jump detected - add weight immediately
			data.hasJumped = true -- Mark that this player has jumped
			-- Use manual decay (only decays when landed, not automatic time-based)
			Evidence.AddEvidence(steamID, DETECTION_NAME, EVIDENCE_WEIGHT_BASE, { manualDecay = true })

			if G.Menu.Advanced.debug then
				print(
					string.format(
						"[Bhop] %s - Bhop detected (vel.z: %.0f) +%.1f evidence",
						player:GetName(),
						velocity.z,
						EVIDENCE_WEIGHT_BASE
					)
				)
			end

			return true
		end

		-- Reset ground tracking when leaving ground
		data.lastOnGround = false
		data.groundedTicks = 0
		data.decayApplied = false
	end

	-- Store current velocity for next tick comparison
	data.lastVelocityZ = velocity.z

	return false
end

return Bhop

end)
__bundle_register("Cheater_Detection.Detection Methods.anti_aim", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Anti-Aim Detection ]]

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local Evidence = require("Cheater_Detection.Core.Evidence_system")
local Logger = require("Cheater_Detection.Utils.Logger")

--[[ Module Declaration ]]
local AntiAim = {}

--[[ Configuration ]]
local DETECTION_NAME = "anti_aim"
local EVIDENCE_WEIGHT = 25 -- High weight - this is plain cheating
local MIN_DETECTIONS = 1 -- Instant evidence on first detection

-- Invalid pitch thresholds
local INVALID_PITCH_MIN = -90
local INVALID_PITCH_MAX = 90
local EXACT_PITCH_SUSPECT = 89.000 -- Common rage AA value

--[[ Helper Functions ]]
local function validatePlayer(player)
	if not player or not player:IsValid() or not player:IsAlive() or player:IsDormant() then
		return false
	end
	return true
end

--[[ Public Functions ]]
function AntiAim.Check(player)
	-- Skip if detection disabled in menu
	if not G.Menu.Advanced.AntyAim then
		return false
	end

	-- Validate player
	if not validatePlayer(player) then
		return false
	end

	-- Get steamID for tracking
	local steamID = tostring(Common.GetSteamID64(player))
	if not Common.IsSteamID64(steamID) then
		return false
	end

	-- Skip if already marked as cheater
	if Evidence.IsMarkedCheater(steamID) then
		return false
	end

	-- Get eye angles
	local angles = player:GetEyeAngles()
	if not angles then
		return false
	end

	local detected = false
	local detectionReason = nil
	-- Enhanced detection with cheat fingerprinting
	if angles.pitch > 89.4 or angles.pitch < -89.4 then
		-- Simplified detection: Any pitch outside valid bounds is Anti-Aim
		detected = true
		detectionReason = "Anti-Aim (OOB Pitch)"
	end

	-- Add evidence immediately (exploits = instant flag)
	if detected then
		Evidence.AddEvidence(steamID, DETECTION_NAME, EVIDENCE_WEIGHT)

		if G.Menu.Advanced.debug then
			print(
				string.format(
					"[AntiAim] %s - Detected %s (pitch: %.3f) +%.1f evidence",
					player:GetName(),
					detectionReason,
					angles.pitch,
					EVIDENCE_WEIGHT
				)
			)
		end

		Logger.Info(
			"AntiAim",
			string.format("%s detected using %s (pitch: %.3f)", player:GetName(), detectionReason, angles.pitch)
		)
		return true
	end

	return false
end

return AntiAim

end)
__bundle_register("Cheater_Detection.Misc.Auto_Vote", function(require, _LOADED, __bundle_register, __bundle_modules)
local AutoVote = {}

local G = require("Cheater_Detection.Utils.Globals")
local Common = require("Cheater_Detection.Utils.Common")
local FastPlayers = require("Cheater_Detection.Utils.FastPlayers")
local WrappedPlayer = require("Cheater_Detection.Utils.WrappedPlayer")
local Evidence = require("Cheater_Detection.Core.Evidence_system")
local Sources = require("Cheater_Detection.Database.Sources")
local Logger = require("Cheater_Detection.Utils.Logger")
local VoteReveal = require("Cheater_Detection.Misc.Vote_Revel")

local LOG_CATEGORY = "AutoVote"

-- Bit operations fallback (bit library is often nil in Lmaobox)
local function shiftRight(value, bits)
	return math.floor(value / (2 ^ bits))
end

-- User message IDs (TF2 specific)
local VoteStart = 46
local VotePass = 47
local VoteFailed = 48
local CallVoteFailed = 49

-- Prioritised voting order (highest to lowest priority)
local GROUP_PRIORITY = {
	"retaliation", -- Players who voted NO on my votes (highest priority)
	"bot", -- Cheat bots
	"cheater", -- Known cheaters
	"valve", -- Valve employees
	"legit", -- Legit players
	"friend", -- Friends (lowest priority)
}

local VOTE_OPTION_YES = 1
local VOTE_OPTION_NO = 2

local MIN_SECONDS_BETWEEN_CALLVOTES = 1.5

-- Track players who CALLED a vote against us: steamID -> true
-- These players go into "retaliation" group
local RetaliationCallers = {}

-- Track score penalties for players who voted against our interests: steamID -> score
-- Does NOT put them in retaliation group, just adds to their kick priority score
local ScorePenalties = {}

local State = {
	currentVoteIdx = nil,
	currentTarget = nil,
	lastVoteTime = 0,
	lastDecisionTick = 0,
	serverCooldownUntil = 0, -- Server-reported cooldown end time
	lastCooldownLog = 0,
	-- Exponential backoff for guessed cooldowns
	failureBackoff = 60, -- Start at 60 seconds (1 min)
	maxBackoff = 120, -- Max 2 minutes
	backoffUntil = 0,
	iCalledThisVote = false, -- Track if WE initiated the current vote
	voteSentTime = 0, -- When we sent the vote command
	voteTimeout = 3.0, -- Seconds to wait for server response
}

local function logInfo(message)
	Logger.Info(LOG_CATEGORY, message)
end

local function logDebug(message)
	Logger.Debug(LOG_CATEGORY, message)
end

--- Record the CALLER of a vote against us (goes into retaliation GROUP)
local function recordRetaliationCaller(callerSteamID, callerName)
	if not callerSteamID then
		return
	end
	RetaliationCallers[callerSteamID] = true
	logInfo(
		string.format("RETALIATION: %s CALLED a vote against us - added to retaliation group", callerName or "Unknown")
	)
end

--- Record score penalties for players who voted against our interests
--- Does NOT add them to retaliation group, just increases kick priority score
local function recordScorePenalties()
	local activeVote = VoteReveal.GetActiveVote()
	if not activeVote then
		return
	end

	-- Determine what WE would have voted
	local ourVoteOption = nil
	if State.iCalledThisVote then
		-- We initiated this vote, we want YES
		ourVoteOption = 1
	elseif State.currentTarget then
		-- We're voting on someone else's vote
		ourVoteOption = State.currentTarget.expectedResult
	else
		-- Check if we or our friends are the target
		local localPlayer = FastPlayers.GetLocal()
		local localSteamID = localPlayer and localPlayer:GetSteamID64()

		-- Check if target is us or our friend
		if activeVote.targetIdx then
			local targetEntity = entities.GetByIndex(activeVote.targetIdx)
			if targetEntity and targetEntity:IsValid() then
				local targetSteamID = targetEntity:GetSteamID64()
				if targetSteamID == localSteamID or isFriendEntity(targetEntity) then
					-- They're voting against us/friend - we want NO
					ourVoteOption = 2
				end
			end
		end
	end

	if not ourVoteOption then
		return -- Not our concern
	end

	-- Get players who voted against our interest
	local againstVoters = {}
	if ourVoteOption == 1 then
		-- We wanted YES, track NO voters
		againstVoters = VoteReveal.GetNoVoters()
	else
		-- We wanted NO, track YES voters
		againstVoters = VoteReveal.GetYesVoters()
	end

	for _, voter in ipairs(againstVoters) do
		if voter.steamID then
			ScorePenalties[voter.steamID] = (ScorePenalties[voter.steamID] or 0) + 10
			logInfo(
				string.format(
					"PENALTY: %s voted against our interest (+10 score, total: %d)",
					voter.name,
					ScorePenalties[voter.steamID]
				)
			)
		end
	end
end

local function resetVoteState()
	State.currentVoteIdx = nil
	State.currentTarget = nil
	State.iCalledThisVote = false
	State.voteSentTime = 0 -- Clear timeout tracking
end

local function getMenu()
	return G.Menu and G.Menu.Misc or nil
end

local function isFriendEntity(entity)
	return entity and Common.IsFriend(entity) or false
end

local function isValveEmployee(steamID)
	return Sources.IsValveEmployee and Sources.IsValveEmployee(steamID)
end

local function getCheaterStatus(steamID)
	if not steamID then
		return false
	end
	if Evidence.IsMarkedCheater(steamID) then
		return true
	end
	return G.DataBase and G.DataBase[steamID] ~= nil
end

local function isBot(player, steamID)
	if not player then
		return false
	end

	-- Use client.GetPlayerInfo to check for bots (correct method)
	local idx = player:GetIndex()
	if idx then
		local info = client.GetPlayerInfo(idx)
		if info and (info.IsBot or info.IsHLTV) then
			return true
		end
	end

	-- Check if SteamID is invalid (bots have [U:1:0])
	if steamID and steamID == "[U:1:0]" then
		return true
	end

	return false
end

local function getGroupForPlayer(player)
	if not player then
		return nil
	end
	local config = getMenu()
	if not config or not config.intent then
		return nil
	end

	local entity = player:GetRawEntity()
	local steamID = player:GetSteamID64()
	local isFriend = isFriendEntity(entity)

	-- HIGHEST PRIORITY: Retaliation - players who CALLED a vote against us
	if steamID and RetaliationCallers[steamID] then
		return "retaliation"
	end

	-- Check groups in priority order
	if config.intent.bot and isBot(player, steamID) then
		return "bot"
	end
	if config.intent.cheater and getCheaterStatus(steamID) then
		return "cheater"
	end
	if config.intent.valve and isValveEmployee(steamID) then
		return "valve"
	end
	-- Friends as separate lowest-priority group if enabled
	if config.intent.friend and isFriend then
		return "friend"
	end
	-- Legit players (non-friends) if enabled
	if config.intent.legit and not isFriend then
		return "legit"
	end

	return nil
end

local function getScoreboard()
	local pr = Common.PR
	if not pr or type(pr.GetScore) ~= "function" then
		return nil
	end
	return pr.GetScore()
end

local function collectCandidates()
	local scoreboard = getScoreboard() or {}
	local candidates = {}

	local players = FastPlayers.GetAll(true)
	local localPlayer = FastPlayers.GetLocal()
	if not localPlayer then
		return candidates
	end

	local localIndex = localPlayer:GetIndex()
	local localTeam = localPlayer:GetTeamNumber()

	-- Can only vote kick players on YOUR team
	if not localTeam or localTeam < 2 then
		return candidates -- Not on a valid team (spec/unassigned)
	end

	for _, player in ipairs(players) do
		local index = player:GetIndex()
		local playerTeam = player:GetTeamNumber()

		-- Skip self, skip players not on our team
		if index ~= localIndex and playerTeam == localTeam then
			local group = getGroupForPlayer(player)
			if group then
				local score = scoreboard[index + 1] or 0

				-- Add score penalty for players who voted against our interests
				local steamID = player:GetSteamID64()
				if steamID and ScorePenalties[steamID] then
					score = score + ScorePenalties[steamID]
				end

				candidates[#candidates + 1] = {
					player = player,
					score = score,
					group = group,
				}
			end
		end
	end

	return candidates
end

local function pickNextTarget()
	local candidates = collectCandidates()
	if #candidates == 0 then
		return nil
	end

	table.sort(candidates, function(a, b)
		if a.group == b.group then
			return a.score > b.score
		end
		local aPriority, bPriority = 99, 99
		for i, name in ipairs(GROUP_PRIORITY) do
			if a.group == name then
				aPriority = i
			end
			if b.group == name then
				bPriority = i
			end
		end
		if aPriority == bPriority then
			return a.score > b.score
		end
		return aPriority < bPriority
	end)

	return candidates[1]
end

local function shouldVoteAutomatically()
	local menu = getMenu()
	local result = menu and menu.Autovote and menu.AutovoteAutoCast ~= false
	if not result then
		logDebug(
			string.format(
				"Auto-cast disabled: menu=%s, Autovote=%s, AutovoteAutoCast=%s",
				tostring(menu ~= nil),
				tostring(menu and menu.Autovote),
				tostring(menu and menu.AutovoteAutoCast)
			)
		)
		return false
	end

	-- Check if we're in a casual game mode
	local isCasual = gamerules.IsMatchTypeCasual()
	if not isCasual then
		logDebug("Auto-vote disabled: not in casual game mode")
		return false
	end

	return true
end

local function issueVote(target)
	if not target or not target.player then
		return false
	end

	-- Team check already done in collectCandidates
	local targetEntity = target.player:GetRawEntity()
	if not targetEntity or not targetEntity:IsValid() then
		return false
	end

	local idx = targetEntity:GetIndex()
	if not idx then
		return false
	end

	local info = client.GetPlayerInfo(idx)
	if not info or not info.UserID then
		return false
	end

	client.Command(string.format("callvote kick %d", info.UserID), true)
	logInfo(
		string.format(
			"Initiated vote on %s [%s] (group: %s, score: %d)",
			target.player:GetName(),
			target.player:GetSteamID64(),
			target.group,
			target.score
		)
	)

	State.currentTarget = {
		steamID = target.player:GetSteamID64(),
		group = target.group,
		expectedResult = VOTE_OPTION_YES,
	}
	State.lastVoteTime = globals.RealTime()
	State.iCalledThisVote = true -- Track that WE initiated this vote
	State.voteSentTime = globals.RealTime() -- Track when we sent the command
	return true
end

local function sendVote(voteIdx, option)
	client.Command(string.format("vote %d option%d", voteIdx, option), true)
end

local function determineVoteOptionForEntity(entity)
	local menu = getMenu()
	if not menu or not menu.Autovote then
		return nil
	end

	if not entity or not entity:IsValid() then
		return nil
	end

	if menu.intent and menu.intent.friend and isFriendEntity(entity) then
		return nil
	end

	local wrapped = WrappedPlayer.FromEntity(entity)
	if not wrapped then
		return nil
	end

	local group = getGroupForPlayer(wrapped)
	if not group then
		return nil
	end

	return VOTE_OPTION_YES
end

local function handleVoteStart(msg)
	-- Check if we're in a casual game mode before processing votes
	local isCasual = gamerules.IsMatchTypeCasual()
	if not isCasual then
		logDebug("Vote handling disabled: not in casual game mode")
		return
	end

	local menu = getMenu()
	local team = msg:ReadByte()
	local voteIdx = msg:ReadInt(32)
	local callerIdx = msg:ReadByte()
	local dispStr = msg:ReadString(64)
	local detailsStr = msg:ReadString(64)
	local targetPacked = msg:ReadByte()
	local targetIdx = shiftRight(targetPacked, 1)

	State.currentVoteIdx = voteIdx

	-- Check if someone is CALLING a vote against US or our FRIEND
	local localPlayer = FastPlayers.GetLocal()
	local localIndex = localPlayer and localPlayer:GetIndex() or -1
	local localSteamID = localPlayer and localPlayer:GetSteamID64()

	local voteTargetEntity = entities.GetByIndex(targetIdx)
	if voteTargetEntity and voteTargetEntity:IsValid() and callerIdx ~= localIndex then
		local voteTargetSteamID = voteTargetEntity:GetSteamID64()
		-- Is this a vote against US?
		if voteTargetSteamID == localSteamID then
			-- Get caller info and add to retaliation group
			local callerEntity = entities.GetByIndex(callerIdx)
			if callerEntity and callerEntity:IsValid() then
				local callerSteamID = callerEntity:GetSteamID64()
				local callerName = client.GetPlayerNameByIndex(callerIdx)
				recordRetaliationCaller(callerSteamID, callerName)
			end
		-- Is this a vote against our FRIEND?
		elseif isFriendEntity(voteTargetEntity) then
			local callerEntity = entities.GetByIndex(callerIdx)
			if callerEntity and callerEntity:IsValid() then
				local callerSteamID = callerEntity:GetSteamID64()
				local callerName = client.GetPlayerNameByIndex(callerIdx)
				recordRetaliationCaller(callerSteamID, callerName)
			end
		end
	end

	-- Check if this is the vote WE initiated
	if State.currentTarget and State.voteSentTime > 0 then
		local localPlayer = FastPlayers.GetLocal()
		-- GetIndex() is forwarded to WPlayer via metatable (lint warning is false positive)
		local localIndex = localPlayer and localPlayer:GetIndex() or -1

		-- Check if we're the caller AND it matches our target
		if callerIdx == localIndex then
			local targetEntity = entities.GetByIndex(targetIdx)
			if targetEntity and targetEntity:IsValid() then
				-- GetSteamID64() is forwarded to WPlayer via metatable (lint warning is false positive)
				local targetSteamID = targetEntity:GetSteamID64()
				if targetSteamID == State.currentTarget.steamID then
					-- This is DEFINITELY our vote! Clear timeout and proceed
					State.voteSentTime = 0
					local option = State.currentTarget.expectedResult or VOTE_OPTION_YES
					sendVote(voteIdx, option)
					logInfo(string.format("OUR vote started - Voting option %d on vote %d", option, voteIdx))
					return
				end
			end
		end
		-- Not our vote - someone else started a vote
		logDebug(string.format("Vote started by player %d while we were waiting", callerIdx))
	end

	if not menu or not menu.Autovote then
		return
	end

	local targetEntity = entities.GetByIndex(targetIdx)
	logDebug(
		string.format(
			"VoteStart: voteIdx=%d, team=%d, callerIdx=%d, targetIdx=%d, disp=%s",
			voteIdx,
			team,
			callerIdx,
			targetIdx,
			dispStr
		)
	)

	local option = determineVoteOptionForEntity(targetEntity)
	if not option then
		logDebug("VoteStart received but no eligible automatic response")
		return
	end

	sendVote(voteIdx, option)
	logInfo(
		string.format(
			"Auto voted %s on %s (caller idx %d, team %d, reason %s)",
			option == VOTE_OPTION_YES and "YES" or "NO",
			client.GetPlayerNameByIndex(targetIdx) or "Unknown",
			callerIdx,
			team,
			dispStr
		)
	)
end

local function handleVoteEnd()
	resetVoteState()
end

--- Handle vote failure with retaliation tracking and cooldown
local function handleVoteFailed()
	-- Record score penalties for players who voted against our interests
	recordScorePenalties()

	-- Assume 60s cooldown if we don't have explicit cooldown
	local now = globals.RealTime()
	if State.serverCooldownUntil < now then
		State.serverCooldownUntil = now + State.failureBackoff
		logInfo(string.format("Vote failed - cooldown %ds (backoff)", State.failureBackoff))

		-- Exponential backoff: increase for next time, max 2 minutes
		State.failureBackoff = math.min(State.failureBackoff * 2, State.maxBackoff)
	end

	resetVoteState()
end

local function onVoteEvent(event)
	local name = event:GetName()

	if name == "round_end" or name == "game_newmap" then
		resetVoteState()
		return
	end

	-- Vote started successfully - reset backoff
	if name == "vote_started" then
		local issue = event:GetString("issue")
		local param1 = event:GetString("param1")
		local initiator = event:GetInt("initiator")
		logInfo(string.format("Vote started: %s (%s) by entity %d", issue or "?", param1 or "?", initiator or -1))
		State.failureBackoff = 60 -- Reset backoff on success
		return
	end

	-- Vote passed - success, reset backoff
	if name == "vote_passed" then
		local details = event:GetString("details")
		local param1 = event:GetString("param1")
		logInfo(string.format("Vote passed: %s (%s)", details or "?", param1 or "?"))
		State.failureBackoff = 60 -- Reset backoff on success
		resetVoteState()
		return
	end

	-- Vote failed (not enough votes) - record retaliation
	if name == "vote_failed" then
		logInfo("Vote failed (not enough votes)")
		handleVoteFailed()
		return
	end

	-- Vote ended (generic)
	if name == "vote_ended" then
		resetVoteState()
		return
	end
end

-- Track last log time to avoid spam
local lastStatusLog = 0
local STATUS_LOG_INTERVAL = 5.0

function AutoVote.OnCreateMove()
	local menu = getMenu()
	if not menu then
		return
	end

	if not shouldVoteAutomatically() then
		return
	end

	-- Check for timeout on vote we sent
	if State.voteSentTime > 0 then
		local now = globals.RealTime()
		if now - State.voteSentTime > State.voteTimeout then
			-- Server didn't respond within timeout - assume silent rejection
			logInfo(string.format("Vote timeout after %.1fs - server silently rejected", State.voteTimeout))
			State.serverCooldownUntil = now + State.failureBackoff
			logInfo(string.format("Cooldown: %ds (estimated from timeout)", State.failureBackoff))

			-- Exponential backoff
			State.failureBackoff = math.min(State.failureBackoff * 2, State.maxBackoff)

			-- Reset vote state
			resetVoteState()
			return
		end
	end

	-- Vote already in progress
	if State.currentTarget or State.currentVoteIdx then
		return
	end

	local now = globals.RealTime()

	-- Check cooldown (either server-reported or backoff-estimated)
	if State.serverCooldownUntil > now then
		local remaining = math.ceil(State.serverCooldownUntil - now)
		-- Log cooldown every 10 seconds
		if now - State.lastCooldownLog > 10 then
			State.lastCooldownLog = now
			logInfo(string.format("Cooldown: %d seconds left (next backoff: %ds)", remaining, State.failureBackoff))
		end
		return
	end

	-- Local cooldown between vote attempts
	local timeSinceLastVote = now - State.lastVoteTime
	if timeSinceLastVote < MIN_SECONDS_BETWEEN_CALLVOTES then
		return
	end

	-- Rate limit per tick
	if globals.TickCount() == State.lastDecisionTick then
		return
	end

	State.lastDecisionTick = globals.TickCount()

	local target = pickNextTarget()
	if not target then
		-- Log status periodically
		if globals.RealTime() - lastStatusLog > STATUS_LOG_INTERVAL then
			lastStatusLog = globals.RealTime()
			local candidates = collectCandidates()
			if #candidates == 0 then
				logInfo("No vote targets on your team (check intent settings)")
			end
		end
		return
	end

	logInfo(
		string.format(
			"Attempting vote on %s [%s] (group: %s, score: %d)",
			target.player:GetName(),
			target.player:GetSteamID64(),
			target.group,
			target.score
		)
	)

	if issueVote(target) then
		logInfo("Vote command sent - waiting for server response...")
	else
		logInfo("Cannot vote - target may be on enemy team or invalid")
	end
end

function AutoVote.OnDispatchUserMessage(msg)
	local id = msg:GetID()
	if id == VoteStart then
		handleVoteStart(msg)
	elseif id == VotePass then
		-- Vote passed - reset backoff
		State.failureBackoff = 60
		handleVoteEnd()
	elseif id == VoteFailed then
		-- Vote failed (not enough YES votes) - record retaliation
		logInfo("VoteFailed user message received")
		handleVoteFailed()
	elseif id == CallVoteFailed then
		-- Try ALL possible data formats from TF2 server
		local cooldownFound = false
		local cooldownTime = 0
		local reason = -1

		-- Method 1: Standard TF2 format (reason:byte, time:short)
		reason = msg:ReadByte()
		local time1 = msg:ReadInt(16)
		logInfo(string.format("CallVoteFailed FORMAT1: reason=%d, time=%d", reason or -1, time1 or -1))

		if time1 and time1 > 0 and time1 <= 300 then
			cooldownFound = true
			cooldownTime = time1
			logInfo(string.format("VALID COOLDOWN: %d seconds (format1)", cooldownTime))
		end

		-- Method 2: Try reading as float (some servers might use float)
		-- Note: Can't reset message position, so this is just for reference
		-- We would need separate message handlers for different formats

		-- Method 3: Check if reason itself might be the cooldown (some servers)
		if not cooldownFound and reason and reason > 0 and reason <= 300 then
			cooldownFound = true
			cooldownTime = reason
			logInfo(string.format("VALID COOLDOWN: %d seconds (reason-as-time)", cooldownTime))
		end

		-- Additional debug info
		logInfo(
			string.format(
				"CallVoteFailed SUMMARY: id=%d, reason=%d, time=%d, valid=%s",
				id,
				reason or -1,
				time1 or -1,
				tostring(cooldownFound)
			)
		)

		-- Apply cooldown if found, otherwise use backoff
		if cooldownFound and cooldownTime > 0 then
			State.serverCooldownUntil = globals.RealTime() + cooldownTime
			State.failureBackoff = 60 -- Reset backoff since we got real data
			logInfo(string.format("Vote cooldown: %d seconds (server confirmed)", cooldownTime))
		else
			-- No valid cooldown - use backoff
			State.serverCooldownUntil = globals.RealTime() + State.failureBackoff
			logInfo(
				string.format("Vote rejected (reason %d) - cooldown %ds (estimated)", reason or 0, State.failureBackoff)
			)

			-- Exponential backoff: increase for next time, max 2 minutes
			State.failureBackoff = math.min(State.failureBackoff * 2, State.maxBackoff)
		end

		handleVoteEnd()
	end
end

function AutoVote.OnFireGameEvent(event)
	onVoteEvent(event)
end

function AutoVote.Reset()
	resetVoteState()
	State.lastVoteTime = 0
	State.lastDecisionTick = 0
	State.serverCooldownUntil = 0
	State.lastCooldownLog = 0
	State.failureBackoff = 60 -- Reset to 60s
	State.voteSentTime = 0 -- Clear timeout
	-- Don't clear RetaliationCallers/ScorePenalties - they persist for the session
	logInfo("AutoVote reset - cooldown cleared")
end

--- Get current retaliation data (for debugging)
function AutoVote.GetRetaliationData()
	return {
		callers = RetaliationCallers,
		penalties = ScorePenalties,
	}
end

-- Register callbacks to enable auto-voting
callbacks.Register("CreateMove", "CD_AutoVote_CreateMove", AutoVote.OnCreateMove)
callbacks.Register("DispatchUserMessage", "CD_AutoVote_UserMsg", AutoVote.OnDispatchUserMessage)
callbacks.Register("FireGameEvent", "CD_AutoVote_Event", AutoVote.OnFireGameEvent)

return AutoVote

end)
__bundle_register("Cheater_Detection.Misc.Vote_Revel", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Custom Vote Reveal UI - TF2 Style ]]

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")

local VoteReveal = {}

-- User message IDs
local VoteStart = 46
local VotePass = 47
local VoteFailed = 48
local CallVoteFailed = 49

-- Team constants
local TEAM_UNASSIGNED = 0
local TEAM_SPECTATOR = 1
local TEAM_RED = 2
local TEAM_BLU = 3

-- Team colors (RGBA)
local TEAM_COLORS = {
	[TEAM_UNASSIGNED] = { 246, 215, 167, 255 },
	[TEAM_SPECTATOR] = { 207, 207, 196, 255 },
	[TEAM_RED] = { 207, 115, 108, 255 },
	[TEAM_BLU] = { 95, 143, 181, 255 },
}

-- Vote state
local activeVote = nil
local voteAlpha = 0
local targetAlpha = 0
local lastUpdateTime = 0

-- Fonts
local font_title = draw.CreateFont("Verdana", 14, 700, FONTFLAG_OUTLINE)
local font_body = draw.CreateFont("Verdana", 12, 400, FONTFLAG_OUTLINE)
local font_small = draw.CreateFont("Tahoma", 11, 400, FONTFLAG_OUTLINE)

--[[ Helper Functions ]]

local function getConfig()
	return G.Menu and G.Menu.Misc and G.Menu.Misc.Vote_Reveal or nil
end

local function localize(key, ...)
	local result = client.Localize(key)
	if not result or #result == 0 then
		return key
	end

	local args = { ... }
	local index = 0
	result = result:gsub("%%[acdglpsuwx%[%]]%d", function(capture)
		index = index + 1
		return args[index] or capture
	end)

	return result
end

local function getTeamName(teamIdx)
	local names = {
		[TEAM_UNASSIGNED] = "UNASSIGNED",
		[TEAM_SPECTATOR] = "SPECTATOR",
		[TEAM_RED] = "RED",
		[TEAM_BLU] = "BLU",
	}
	return names[teamIdx] or "UNKNOWN"
end

local function getPlayerScore(playerIdx)
	local pr = Common.PR
	if not pr or type(pr.GetScore) ~= "function" then
		return 0
	end
	local scoreboard = pr.GetScore()
	if not scoreboard then
		return 0
	end
	return scoreboard[playerIdx + 1] or 0
end

local function truncateText(text, maxWidth, font)
	draw.SetFont(font)
	local width = draw.GetTextSize(text)
	if width <= maxWidth then
		return text
	end

	-- Binary search for the right length
	local left, right = 1, #text
	while left < right do
		local mid = math.floor((left + right + 1) / 2)
		local sub = text:sub(1, mid) .. "..."
		local w = draw.GetTextSize(sub)
		if w <= maxWidth then
			left = mid
		else
			right = mid - 1
		end
	end

	return text:sub(1, left) .. "..."
end

--[[ Vote Tracking ]]

local function startVote(team, voteidx, callerIdx, dispStr, detailsStr, targetIdx)
	local options = { "Yes", "No" }

	activeVote = {
		voteIdx = voteidx,
		team = team,
		caller = client.GetPlayerNameByIndex(callerIdx) or "Unknown",
		callerIdx = callerIdx,
		reason = localize(dispStr, detailsStr),
		targetName = targetIdx > 0 and client.GetPlayerNameByIndex(targetIdx) or "",
		targetIdx = targetIdx,
		options = options,
		votes = {
			[1] = {}, -- Yes votes
			[2] = {}, -- No votes
		},
		counts = { 0, 0 },
		startTime = globals.RealTime(),
	}

	targetAlpha = 255

	-- Console output as backup
	local config = getConfig()
	if config and config.Output and config.Output.Console then
		print(string.format("[Vote] %s started vote: %s", activeVote.caller, activeVote.reason))
	end
end

local function castVote(voteOption, team, playerIdx, voteidx)
	if not activeVote or activeVote.voteIdx ~= voteidx then
		return
	end

	local option = voteOption + 1 -- TF2 uses 0-indexed
	if option < 1 or option > 2 then
		return
	end

	local playerName = client.GetPlayerNameByIndex(playerIdx)
	if not playerName then
		return
	end

	local score = getPlayerScore(playerIdx)
	local teamName = getTeamName(team)

	-- Add to vote list
	table.insert(activeVote.votes[option], {
		name = playerName,
		team = team,
		teamName = teamName,
		score = score,
		idx = playerIdx,
	})

	-- Console output
	local config = getConfig()
	if config and config.Output and config.Output.Console then
		print(string.format("[Vote] %s voted: %s (Score: %d)", playerName, activeVote.options[option], score))
	end
end

local function updateVoteCounts(voteidx, counts)
	if not activeVote or activeVote.voteIdx ~= voteidx then
		return
	end

	for i = 1, 5 do
		activeVote.counts[i] = counts[i] or 0
	end
end

local function endVote(reason)
	if not activeVote then
		return
	end

	-- Console output
	local config = getConfig()
	if config and config.Output and config.Output.Console then
		print(string.format("[Vote] Vote ended: %s", reason or ""))
		for i, voters in ipairs(activeVote.votes) do
			if #voters > 0 then
				print(string.format("  %s: %d", activeVote.options[i], #voters))
				for _, voter in ipairs(voters) do
					print(string.format("    - %s [%s] (Score: %d)", voter.name, voter.teamName, voter.score))
				end
			end
		end
	end

	targetAlpha = 0
end

--[[ Visual Rendering ]]

local function lerpAlpha(dt)
	local speed = 800 -- Alpha units per second
	if voteAlpha < targetAlpha then
		voteAlpha = math.min(targetAlpha, voteAlpha + speed * dt)
	elseif voteAlpha > targetAlpha then
		voteAlpha = math.max(targetAlpha, voteAlpha - speed * dt)
	end

	-- Clear vote when fully faded out
	if voteAlpha <= 0 and targetAlpha == 0 then
		activeVote = nil
	end
end

-- Simplify vote type text
local function getVoteTypeText(reason)
	local lower = reason:lower()
	if lower:find("kick") then
		return "VOTE KICK"
	elseif lower:find("map") or lower:find("nextlevel") then
		return "VOTE MAP"
	elseif lower:find("scramble") then
		return "VOTE SCRAMBLE"
	elseif lower:find("restart") then
		return "VOTE RESTART"
	else
		return "VOTE"
	end
end

local function drawVoteUI()
	if not activeVote or voteAlpha <= 0 then
		return
	end

	local config = getConfig()
	if not config or not config.Enable then
		return
	end

	local alpha = math.floor(voteAlpha)

	-- UI dimensions (floor all to avoid sub-pixel rendering)
	local screenW, _ = draw.GetScreenSize()
	local boxW = 280
	local boxX = math.floor((screenW - boxW) / 2)
	local boxY = 55
	local pad = 12
	local lineH = 18

	-- Calculate height
	local maxVoters = math.max(#activeVote.votes[1], #activeVote.votes[2])
	local voterRows = math.min(maxVoters, 8)
	local hasTarget = activeVote.targetName and #activeVote.targetName > 0
	local headerH = hasTarget and 70 or 52
	local boxH = headerH + (voterRows * lineH) + pad + 20

	-- Background
	draw.Color(18, 18, 22, math.floor(alpha * 0.96))
	draw.FilledRect(boxX, boxY, boxX + boxW, boxY + boxH)

	-- Border
	draw.Color(55, 55, 65, alpha)
	draw.OutlinedRect(boxX, boxY, boxX + boxW, boxY + boxH)

	-- Title bar
	draw.Color(30, 30, 38, alpha)
	draw.FilledRect(boxX + 1, boxY + 1, boxX + boxW - 1, boxY + 26)

	-- Title text
	draw.SetFont(font_title)
	draw.Color(255, 255, 255, alpha)
	local voteType = getVoteTypeText(activeVote.reason)
	local typeW = draw.GetTextSize(voteType)
	draw.Text(math.floor(boxX + (boxW - typeW) / 2), boxY + 5, voteType)

	-- Caller line
	local callerY = boxY + 32
	local callerTeamColor = TEAM_COLORS[activeVote.team] or TEAM_COLORS[TEAM_UNASSIGNED]
	draw.SetFont(font_body)
	draw.Color(100, 100, 110, alpha)
	draw.Text(boxX + pad, callerY, "By:")
	draw.Color(callerTeamColor[1], callerTeamColor[2], callerTeamColor[3], alpha)
	local callerName = truncateText(activeVote.caller, boxW - pad * 2 - 30, font_body)
	draw.Text(boxX + pad + 28, callerY, callerName)

	-- Target line (if kick vote)
	local contentY = callerY + 18
	if hasTarget then
		draw.Color(100, 100, 110, alpha)
		draw.Text(boxX + pad, contentY, "On:")
		draw.Color(255, 170, 70, alpha)
		local targetName = truncateText(activeVote.targetName, boxW - pad * 2 - 30, font_body)
		draw.Text(boxX + pad + 28, contentY, targetName)
		contentY = contentY + 20
	end

	-- Horizontal divider
	draw.Color(45, 45, 55, alpha)
	draw.Line(boxX + pad, contentY, boxX + boxW - pad, contentY)

	-- Column setup (floor to avoid sub-pixel)
	local colW = math.floor((boxW - pad * 2) / 2)
	local yesX = boxX + pad
	local noX = boxX + pad + colW

	-- YES / NO headers
	contentY = contentY + 6
	draw.SetFont(font_body)
	draw.Color(70, 180, 70, alpha)
	draw.Text(yesX, contentY, "YES")
	draw.Color(180, 70, 70, alpha)
	draw.Text(noX, contentY, "NO")

	-- Vertical divider
	local divX = math.floor(boxX + boxW / 2)
	draw.Color(45, 45, 55, math.floor(alpha * 0.6))
	draw.Line(divX, contentY + 18, divX, boxY + boxH - pad - 14)

	-- Voter lists
	draw.SetFont(font_small)
	local listY = contentY + 20
	local nameW = colW - 8

	-- Yes voters
	local sortedYes = {}
	for i, v in ipairs(activeVote.votes[1]) do
		sortedYes[i] = v
	end
	table.sort(sortedYes, function(a, b)
		return a.score > b.score
	end)

	for i = 1, math.min(#sortedYes, 8) do
		local v = sortedYes[i]
		local tc = TEAM_COLORS[v.team]
		draw.Color(tc[1], tc[2], tc[3], alpha)
		draw.Text(yesX, listY + (i - 1) * lineH, truncateText(v.name, nameW, font_small))
	end

	-- No voters
	local sortedNo = {}
	for i, v in ipairs(activeVote.votes[2]) do
		sortedNo[i] = v
	end
	table.sort(sortedNo, function(a, b)
		return a.score > b.score
	end)

	for i = 1, math.min(#sortedNo, 8) do
		local v = sortedNo[i]
		local tc = TEAM_COLORS[v.team]
		draw.Color(tc[1], tc[2], tc[3], alpha)
		draw.Text(noX, listY + (i - 1) * lineH, truncateText(v.name, nameW, font_small))
	end

	-- Vote count (bottom right)
	draw.SetFont(font_small)
	draw.Color(90, 90, 100, alpha)
	local countText = string.format("%d/%d", activeVote.counts[1] or 0, activeVote.counts[2] or 0)
	local countW = draw.GetTextSize(countText)
	draw.Text(boxX + boxW - countW - pad, boxY + boxH - 16, countText)
end

--[[ Event Handlers ]]

local function handleUserMessage(msg)
	local id = msg:GetID()

	if id == VoteStart then
		local team = msg:ReadByte()
		local voteidx = msg:ReadInt(32)
		local callerIdx = msg:ReadByte()
		local dispStr = msg:ReadString(64)
		local detailsStr = msg:ReadString(64)
		local targetPacked = msg:ReadByte()
		local targetIdx = math.floor(targetPacked / 2) -- bit shift right by 1

		startVote(team, voteidx, callerIdx, dispStr, detailsStr, targetIdx)
	elseif id == VotePass then
		local team = msg:ReadByte()
		local voteidx = msg:ReadInt(32)
		local dispStr = msg:ReadString(256)
		local detailsStr = msg:ReadString(256)

		local reason = localize(dispStr, detailsStr)
		endVote("Vote Passed: " .. reason)
	elseif id == VoteFailed then
		local team = msg:ReadByte()
		local voteidx = msg:ReadInt(32)
		local failReason = msg:ReadByte()

		endVote("Vote Failed")
	end
end

local function handleGameEvent(event)
	local eventName = event:GetName()

	if eventName == "vote_cast" then
		local option = event:GetInt("vote_option")
		local team = event:GetInt("team")
		local playerIdx = event:GetInt("entityid")
		local voteidx = event:GetInt("voteidx")

		castVote(option, team, playerIdx, voteidx)
	elseif eventName == "vote_changed" then
		local voteidx = event:GetInt("voteidx")
		local counts = {}
		for i = 1, 5 do
			counts[i] = event:GetInt("vote_option" .. i)
		end
		updateVoteCounts(voteidx, counts)
	elseif eventName == "vote_options" then
		-- Update option names if needed
		if activeVote then
			for i = 1, event:GetInt("count") do
				activeVote.options[i] = event:GetString("option" .. i)
			end
		end
	end
end

local function onDraw()
	local currentTime = globals.RealTime()
	local dt = currentTime - lastUpdateTime
	lastUpdateTime = currentTime

	lerpAlpha(dt)
	drawVoteUI()
end

--[[ Public API ]]

--- Get the current active vote data (for retaliation tracking)
function VoteReveal.GetActiveVote()
	return activeVote
end

--- Get who voted No on the current/last vote
--- Returns list of {idx, name, steamID} or empty table
function VoteReveal.GetNoVoters()
	if not activeVote or not activeVote.votes or not activeVote.votes[2] then
		return {}
	end

	local noVoters = {}
	for _, voter in ipairs(activeVote.votes[2]) do
		local steamID = nil
		if voter.idx then
			local info = client.GetPlayerInfo(voter.idx)
			if info and info.SteamID then
				-- Convert SteamID3 to SteamID64
				local accountID = tonumber(info.SteamID:match("%[U:1:(%d+)%]"))
				if accountID then
					steamID = tostring(76561197960265728 + accountID)
				end
			end
		end
		table.insert(noVoters, {
			idx = voter.idx,
			name = voter.name,
			steamID = steamID,
		})
	end
	return noVoters
end

--- Get who voted Yes on the current/last vote
--- Returns list of {idx, name, steamID} or empty table
function VoteReveal.GetYesVoters()
	if not activeVote or not activeVote.votes or not activeVote.votes[1] then
		return {}
	end

	local yesVoters = {}
	for _, voter in ipairs(activeVote.votes[1]) do
		local steamID = nil
		if voter.idx then
			local info = client.GetPlayerInfo(voter.idx)
			if info and info.SteamID then
				-- Convert SteamID3 to SteamID64
				local accountID = tonumber(info.SteamID:match("%[U:1:(%d+)%]"))
				if accountID then
					steamID = tostring(76561197960265728 + accountID)
				end
			end
		end
		table.insert(yesVoters, {
			idx = voter.idx,
			name = voter.name,
			steamID = steamID,
		})
	end
	return yesVoters
end

--[[ Registration ]]

callbacks.Unregister("DispatchUserMessage", "CD_VoteReveal_UserMsg")
callbacks.Register("DispatchUserMessage", "CD_VoteReveal_UserMsg", handleUserMessage)

callbacks.Unregister("FireGameEvent", "CD_VoteReveal_Event")
callbacks.Register("FireGameEvent", "CD_VoteReveal_Event", handleGameEvent)

callbacks.Unregister("Draw", "CD_VoteReveal_Draw")
callbacks.Register("Draw", "CD_VoteReveal_Draw", onDraw)

return VoteReveal

end)
__bundle_register("Cheater_Detection.Database.Sources", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Source definitions with safer processing options

--[[ Imports ]]
local ValveEmployees = require("Cheater_Detection.Database.ValveEmployees")
-- [[ Imported by: Fetcher.lua ]]

--[[ Module Declaration ]]
local Sources = {}

--[[ Local Variables/Utilities ]]
-- List of available sources
Sources.List = {
	{
		name = "d3fc0n6 Cheater List",
		url = "https://raw.githubusercontent.com/d3fc0n6/CheaterList/main/CheaterFriend/64ids",
		cause = "Cheater Friend",
		parser = "raw",
	},
	{
		name = "d3fc0n6 Tacobot List",
		url = "https://raw.githubusercontent.com/d3fc0n6/TacobotList/master/64ids",
		cause = "Cheater Tacobot",
		parser = "raw",
	},
	{
		name = "d3fc0n6 Group List",
		url = "https://raw.githubusercontent.com/d3fc0n6/CheaterList/main/Group/64ids",
		cause = "Suspected (Group Member)",
		parser = "raw",
	},
	{
		name = "Sleepy List RGL",
		url = "https://raw.githubusercontent.com/surepy/tf2db-sleepy-list/main/playerlist.rgl-gg.json",
		cause = "Sleepy RGL",
		parser = "tf2db",
	},
	{
		name = "bot detector (Official)",
		url = "https://raw.githubusercontent.com/PazerOP/tf2_bot_detector/master/staging/cfg/playerlist.official.json",
		cause = "Bot (bot detector)",
		parser = "tf2db", -- Use tf2db parser for this JSON source
	},
	{
		name = "MegaScaterbomb (Scraped)",
		url = "https://raw.githubusercontent.com/surepy/tf2db-sleepy-list/refs/heads/main/playerlist.megacheaterdb.json",
		cause = "Cheater (MegaScaterbomb)",
		parser = "tf2db", -- Use tf2db parser for this JSON source
	},
	{
		name = "qfoxb Player List",
		url = "https://raw.githubusercontent.com/qfoxb/tf2bd-lists/main/playerlist.qfoxb.json",
		cause = "TF2BD Community (qfoxb)",
		parser = "tf2db",
	},
	{
		name = "joekiller Player List",
		url = "https://raw.githubusercontent.com/joekiller/joekiller-list/main/playerlist.joekiller.json",
		cause = "TF2BD Community (joekiller)",
		parser = "tf2db",
	},
}

--[[ Helper/Private Functions (None) ]]

--[[ Public Module Functions ]]
-- Function to add a custom source
function Sources.AddSource(name, url, cause, parser)
	if not name or not url or not cause or not parser then
		print("[Database Fetcher] Error: Missing required fields for new source")
		return false
	end

	if parser ~= "raw" and parser ~= "tf2db" then
		print("[Database Fetcher] Error: Invalid parser type: " .. parser)
		return false
	end

	table.insert(Sources.List, {
		name = name,
		url = url,
		cause = cause,
		parser = parser,
	})

	print("[Database Fetcher] Added new source: " .. name)
	return true
end

-- Utility function to enable/disable sources (e.g. for testing)
function Sources.DisableSource(sourceIndex)
	if sourceIndex < 1 or sourceIndex > #Sources.List then
		print("[Database Fetcher] Invalid source index: " .. tostring(sourceIndex))
		return false
	end

	local source = Sources.List[sourceIndex]
	source.__disabled = true
	print("[Database Fetcher] Disabled source: " .. source.name)
	return true
end

-- Get active sources (not disabled)
function Sources.GetActiveSources()
	local active = {}
	for i, source in ipairs(Sources.List) do
		if not source.__disabled then
			table.insert(active, source)
		end
	end
	return active
end

-- Get Valve employee list from local database
function Sources.GetValveEmployees()
	return ValveEmployees.List
end

-- Check if SteamID is Valve employee
function Sources.IsValveEmployee(steamID)
	return ValveEmployees.IsValveEmployee(steamID)
end

--[[ Self-Initialization (None) ]]

--[[ Callback Registration (None) ]]

return Sources

end)
__bundle_register("Cheater_Detection.Database.ValveEmployees", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Valve Employee SteamID64 Database ]]
-- Source: https://steamdb.info/badge/11 (Valve Employee Badge)
-- Total: 20 confirmed (640 total available)

local ValveEmployees = {}

-- SteamID64 list of confirmed Valve employees
ValveEmployees.List = {
	["76561197960265729"] = "Valve Employee",
	["76561197960265730"] = "Valve Employee",
	["76561197960265731"] = "Valve Employee",
	["76561197960265733"] = "Valve Employee",
	["76561197960265738"] = "Valve Employee",
	["76561197960265740"] = "Valve Employee",
	["76561197960265743"] = "Valve Employee",
	["76561197960265749"] = "Valve Employee",
	["76561197960265754"] = "Valve Employee",
	["76561197960265838"] = "Valve Employee",
	["76561197960268402"] = "Valve Employee",
	["76561197960277670"] = "Valve Employee",
	["76561197960303386"] = "Valve Employee",
	["76561197960405535"] = "Valve Employee",
	["76561197960423941"] = "Valve Employee",
	["76561197960434622"] = "Valve Employee",
	["76561197960435530"] = "Valve Employee",
	["76561197960549564"] = "Valve Employee",
	["76561197960563532"] = "Valve Employee",
	["76561197960860649"] = "Valve Employee",
	["76561197962146232"] = "Valve Employee",
	["76561197962313932"] = "Valve Employee",
	["76561197962413930"] = "Valve Employee",
	["76561197962783665"] = "Valve Employee",
	["76561197962844216"] = "Valve Employee",
	["76561197963156385"] = "Valve Employee",
	["76561197964165126"] = "Valve Employee",
	["76561197964279229"] = "Valve Employee",
	["76561197964620212"] = "Valve Employee",
	["76561197966460010"] = "Valve Employee",
	["76561197966465612"] = "Valve Employee",
	["76561197967144365"] = "Valve Employee",
	["76561197967346751"] = "Valve Employee",
	["76561197967713982"] = "Valve Employee",
	["76561197968151197"] = "Valve Employee",
	["76561197968282875"] = "Valve Employee",
	["76561197968376527"] = "Valve Employee",
	["76561197968459473"] = "Valve Employee",
	["76561197968575517"] = "Valve Employee",
	["76561197969262523"] = "Valve Employee",
	["76561197969266938"] = "Valve Employee",
	["76561197969321754"] = "Valve Employee",
	["76561197969400141"] = "Valve Employee",
	["76561197969518075"] = "Valve Employee",
	["76561197970285523"] = "Valve Employee",
	["76561197970323416"] = "Valve Employee",
	["76561197970530062"] = "Valve Employee",
	["76561197970565175"] = "Valve Employee",
	["76561197970892150"] = "Valve Employee",
	["76561197970968871"] = "Valve Employee",
	["76561197971025345"] = "Valve Employee",
	["76561197971049296"] = "Valve Employee",
	["76561197971400048"] = "Valve Employee",
	["76561197972196250"] = "Valve Employee",
	["76561197972291076"] = "Valve Employee",
	["76561197972370889"] = "Valve Employee",
	["76561197972491988"] = "Valve Employee",
	["76561197972495328"] = "Valve Employee",
	["76561197972755855"] = "Valve Employee",
	["76561197974593417"] = "Valve Employee",
	["76561197975914763"] = "Valve Employee",
	["76561197978022608"] = "Valve Employee",
	["76561197978027217"] = "Valve Employee",
	["76561197978236369"] = "Valve Employee",
	["76561197978290786"] = "Valve Employee",
	["76561197980258575"] = "Valve Employee",
	["76561197980482295"] = "Valve Employee",
	["76561197980632230"] = "Valve Employee",
	["76561197980865448"] = "Valve Employee",
	["76561197981291930"] = "Valve Employee",
	["76561197982227246"] = "Valve Employee",
	["76561197982261816"] = "Valve Employee",
	["76561197983311154"] = "Valve Employee",
	["76561197984212648"] = "Valve Employee",
	["76561197984437106"] = "Valve Employee",
	["76561197984447638"] = "Valve Employee",
	["76561197984751122"] = "Valve Employee",
	["76561197984929530"] = "Valve Employee",
	["76561197985607672"] = "Valve Employee",
	["76561197985627266"] = "Valve Employee",
	["76561197985993448"] = "Valve Employee",
	["76561197988745128"] = "Valve Employee",
	["76561197989577350"] = "Valve Employee",
	["76561197989728462"] = "Valve Employee",
	["76561197989808853"] = "Valve Employee",
	["76561197991390878"] = "Valve Employee",
	["76561197991564203"] = "Valve Employee",
	["76561197991899002"] = "Valve Employee",
	["76561197992169608"] = "Valve Employee",
	["76561197992219796"] = "Valve Employee",
	["76561197992637080"] = "Valve Employee",
	["76561197992681877"] = "Valve Employee",
	["76561197993032363"] = "Valve Employee",
	["76561197993404877"] = "Valve Employee",
	["76561197993596757"] = "Valve Employee",
	["76561197994632741"] = "Valve Employee",
	["76561197994871291"] = "Valve Employee",
	["76561197995010660"] = "Valve Employee",
	["76561197995776067"] = "Valve Employee",
	["76561197996448297"] = "Valve Employee",
	["76561197998511283"] = "Valve Employee",
	["76561197999000345"] = "Valve Employee",
	["76561197999858467"] = "Valve Employee",
	["76561198000613142"] = "Valve Employee",
	["76561198000613320"] = "Valve Employee",
	["76561198001549544"] = "Valve Employee",
	["76561198002413878"] = "Valve Employee",
	["76561198002423550"] = "Valve Employee",
	["76561198003204775"] = "Valve Employee",
	["76561198003417858"] = "Valve Employee",
	["76561198005028443"] = "Valve Employee",
	["76561198005121830"] = "Valve Employee",
	["76561198005342326"] = "Valve Employee",
	["76561198007657496"] = "Valve Employee",
	["76561198007695232"] = "Valve Employee",
	["76561198007696304"] = "Valve Employee",
	["76561198007705538"] = "Valve Employee",
	["76561198008217263"] = "Valve Employee",
	["76561198010062752"] = "Valve Employee",
	["76561198011062689"] = "Valve Employee",
	["76561198011361633"] = "Valve Employee",
	["76561198012148855"] = "Valve Employee",
	["76561198014182596"] = "Valve Employee",
	["76561198014646169"] = "Valve Employee",
	["76561198015158492"] = "Valve Employee",
	["76561198015260835"] = "Valve Employee",
	["76561198018064800"] = "Valve Employee",
	["76561198024119021"] = "Valve Employee",
	["76561198024119077"] = "Valve Employee",
	["76561198024119145"] = "Valve Employee",
	["76561198024119167"] = "Valve Employee",
	["76561198024119209"] = "Valve Employee",
	["76561198024119233"] = "Valve Employee",
	["76561198024119271"] = "Valve Employee",
	["76561198024119297"] = "Valve Employee",
	["76561198024149438"] = "Valve Employee",
	["76561198024187698"] = "Valve Employee",
	["76561198024402255"] = "Valve Employee",
	["76561198025064924"] = "Valve Employee",
	["76561198025468274"] = "Valve Employee",
	["76561198028573551"] = "Valve Employee",
	["76561198032490515"] = "Valve Employee",
	["76561198033146086"] = "Valve Employee",
	["76561198034808425"] = "Valve Employee",
	["76561198035001517"] = "Valve Employee",
	["76561198035286712"] = "Valve Employee",
	["76561198035288254"] = "Valve Employee",
	["76561198035422241"] = "Valve Employee",
	["76561198036759436"] = "Valve Employee",
	["76561198036913483"] = "Valve Employee",
	["76561198037075467"] = "Valve Employee",
	["76561198040445104"] = "Valve Employee",
	["76561198040900440"] = "Valve Employee",
	["76561198041710321"] = "Valve Employee",
	["76561198042626325"] = "Valve Employee",
	["76561198043656028"] = "Valve Employee",
	["76561198044595610"] = "Valve Employee",
	["76561198049584723"] = "Valve Employee",
	["76561198050594319"] = "Valve Employee",
	["76561198050715070"] = "Valve Employee",
	["76561198053546821"] = "Valve Employee",
	["76561198054073580"] = "Valve Employee",
	["76561198057387218"] = "Valve Employee",
	["76561198058528666"] = "Valve Employee",
	["76561198059223364"] = "Valve Employee",
	["76561198059343190"] = "Valve Employee",
	["76561198059694970"] = "Valve Employee",
	["76561198060668058"] = "Valve Employee",
	["76561198062125817"] = "Valve Employee",
	["76561198063543351"] = "Valve Employee",
	["76561198067204391"] = "Valve Employee",
	["76561198071493110"] = "Valve Employee",
	["76561198072243069"] = "Valve Employee",
	["76561198078021748"] = "Valve Employee",
	["76561198078024435"] = "Valve Employee",
	["76561198078035812"] = "Valve Employee",
	["76561198078228212"] = "Valve Employee",
	["76561198080174103"] = "Valve Employee",
	["76561198080912220"] = "Valve Employee",
	["76561198082857351"] = "Valve Employee",
	["76561198083228609"] = "Valve Employee",
	["76561198085177245"] = "Valve Employee",
	["76561198087246319"] = "Valve Employee",
	["76561198088081180"] = "Valve Employee",
	["76561198092412249"] = "Valve Employee",
	["76561198099775662"] = "Valve Employee",
	["76561198105633837"] = "Valve Employee",
	["76561198106284854"] = "Valve Employee",
	["76561198109437065"] = "Valve Employee",
	["76561198113964952"] = "Valve Employee",
	["76561198114561718"] = "Valve Employee",
	["76561198131186854"] = "Valve Employee",
	["76561198135833552"] = "Valve Employee",
	["76561198140935475"] = "Valve Employee",
	["76561198151901386"] = "Valve Employee",
	["76561198166130601"] = "Valve Employee",
	["76561198198282850"] = "Valve Employee",
	["76561198213106087"] = "Valve Employee",
	["76561198226485216"] = "Valve Employee",
	["76561198229291124"] = "Valve Employee",
	["76561198261314581"] = "Valve Employee",
	["76561198263786141"] = "Valve Employee",
	["76561198264031608"] = "Valve Employee",
	["76561198288977529"] = "Valve Employee",
	["76561198302566477"] = "Valve Employee",
	["76561198317891370"] = "Valve Employee",
	["76561198321452086"] = "Valve Employee",
	["76561198343860118"] = "Valve Employee",
	["76561198348711414"] = "Valve Employee",
	["76561198393844333"] = "Valve Employee",
	["76561198434829252"] = "Valve Employee",
	["76561198438289006"] = "Valve Employee",
	["76561198450401134"] = "Valve Employee",
	["76561198451127273"] = "Valve Employee",
	["76561198452053414"] = "Valve Employee",
	["76561198452899854"] = "Valve Employee",
	["76561198802256302"] = "Valve Employee",
	["76561198833054485"] = "Valve Employee",
	["76561198846285573"] = "Valve Employee",
	["76561198859895108"] = "Valve Employee",
	["76561198870432598"] = "Valve Employee",
	["76561198870775610"] = "Valve Employee",
	["76561198873502276"] = "Valve Employee",
	["76561198913388547"] = "Valve Employee",
	["76561198963127805"] = "Valve Employee",
	["76561198965919037"] = "Valve Employee",
	["76561198966950608"] = "Valve Employee",
	["76561198967346694"] = "Valve Employee",
	["76561198973062365"] = "Valve Employee",
	["76561198976679037"] = "Valve Employee",
	["76561198985183773"] = "Valve Employee",
	["76561199020521906"] = "Valve Employee",
	["76561199022293871"] = "Valve Employee",
	["76561199040187169"] = "Valve Employee",
	["76561199043975533"] = "Valve Employee",
	["76561199087803912"] = "Valve Employee",
	["76561199089249923"] = "Valve Employee",
	["76561199090326330"] = "Valve Employee",
	["76561199094829145"] = "Valve Employee",
	["76561199113010392"] = "Valve Employee",
	["76561199113204258"] = "Valve Employee",
	["76561199113498441"] = "Valve Employee",
	["76561199114963316"] = "Valve Employee",
	["76561199118553400"] = "Valve Employee",
	["76561199144449036"] = "Valve Employee",
	["76561199149854583"] = "Valve Employee",
	["76561199163993853"] = "Valve Employee",
	["76561199181174636"] = "Valve Employee",
	["76561199195394860"] = "Valve Employee",
	["76561199211175744"] = "Valve Employee",
	["76561199215769499"] = "Valve Employee",
	["76561199273762413"] = "Valve Employee",
	["76561199333946732"] = "Valve Employee",
	["76561199370270521"] = "Valve Employee",
	["76561199392211477"] = "Valve Employee",
	["76561199499120513"] = "Valve Employee",
	["76561199524745654"] = "Valve Employee",
	["76561199526219225"] = "Valve Employee",
	["76561199544394428"] = "Valve Employee",
	["76561199557784411"] = "Valve Employee",
	["76561199571838040"] = "Valve Employee",
	["76561199690380138"] = "Valve Employee",
}

---Check if a SteamID64 belongs to a Valve employee
---@param steamID string|number SteamID64
---@return boolean isValve True if the player is a Valve employee
---@return string|nil name Valve employee name if found
function ValveEmployees.IsValveEmployee(steamID)
	local steamIDStr = tostring(steamID)
	local name = ValveEmployees.List[steamIDStr]
	return name ~= nil
end

return ValveEmployees

end)
__bundle_register("Cheater_Detection.Database.SteamHistory", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ SteamHistory.lua
	Performs SteamHistory API lookups for players in the current match.
	Scans all players once when enabled, then scans newcomers as they join.
]]

local SteamHistory = {}

--[[ Imports ]]
local G = require("Cheater_Detection.Utils.Globals")
local Common = require("Cheater_Detection.Utils.Common")
local FastPlayers = require("Cheater_Detection.Utils.FastPlayers")
local PlayerState = require("Cheater_Detection.Utils.PlayerState")
local Database = require("Cheater_Detection.Database.Database")
local JoinNotifications = require("Cheater_Detection.Misc.JoinNotifications")
local Json = Common.Json

--[[ Constants ]]
local KEYWORDS = {
	"[stac]",
	"smac ",
	"cheat",
	"hack",
	"aimbot",
}

local API_TEMPLATE = "https://steamhistory.net/api/sourcebans?key=%s&shouldkey=0&steamids=%s"
local MAX_BATCH = 100
local MIN_INTERVAL = 2.0 -- Increased interval to avoid rate limits with larger batches

--[[ Internal State ]]
local state = {
	enabled = false,
	initialQueued = false,
	pending = {},
	scanned = {},
	lastBatchTime = 0,
	scanning = false,
	apiKey = nil,
	-- Error handling
	errorCount = 0,
	nextRetryTime = 0,
	consecutiveFailures = 0,
	maxConsecutiveFailures = 5, -- Disable after 5 failures at max cooldown
	temporarilyDisabled = false,
	-- Adaptive batch size
	currentBatchSize = MAX_BATCH,
	rateLimitedRecently = false,
}

--[[ Helper Functions ]]
local function getConfig()
	local menu = G.Menu
	return menu and menu.Misc and menu.Misc.SteamHistory or nil
end

local function normalizeSteamID64(rawID)
	if not rawID then
		return nil
	end

	local steamID = tostring(rawID)
	if type(steamID) ~= "string" or not steamID:match("^7656119%d+$") then
		return nil
	end

	return steamID
end

local IGNORED_ID = "76561197960265728" -- [U:1:0]

local function getScoreboardName(steamID)
	local maxClients = (globals and globals.MaxClients and globals.MaxClients()) or 32
	for i = 1, maxClients do
		local info = client.GetPlayerInfo(i)
		if info and info.SteamID then
			local infoSteamID = info.SteamID
			local converted = nil
			if infoSteamID:match("^7656119%d+$") then
				converted = normalizeSteamID64(infoSteamID)
			elseif infoSteamID:match("%[U:1:%d+%]") then
				converted = normalizeSteamID64(Common.FromSteamid3To64(infoSteamID))
			end
			if converted == steamID then
				return info.Name
			end
		end
	end
	return nil
end

local function getPlayerNameBySteamID(steamID)
	local scoreboardName = getScoreboardName(steamID)
	if scoreboardName and scoreboardName ~= "" then
		return scoreboardName
	end

	for _, player in ipairs(FastPlayers.GetAll(true)) do
		local id = normalizeSteamID64(player:GetSteamID64())
		if id == steamID then
			local info = player:GetInfo()
			if info and info.Name and info.Name ~= "" then
				return info.Name
			end
			local raw = player.GetRawEntity and player:GetRawEntity() or nil
			if raw and raw.IsValid and raw:IsValid() and raw.GetName then
				local rawName = raw:GetName()
				if type(rawName) == "string" and rawName ~= "" then
					return rawName
				end
			end
		end
	end

	local stateEntry = PlayerState and PlayerState.Get(steamID)
	if stateEntry and stateEntry.info and stateEntry.info.Name and stateEntry.info.Name ~= "" then
		return stateEntry.info.Name
	end

	return nil
end

local function printInfo(color, text)
	printc(color[1], color[2], color[3], color[4], text)
end

local function queueSteamID(steamID, context)
	if not steamID then
		return false
	end
	steamID = normalizeSteamID64(steamID)
	if not steamID then
		return false
	end
	if steamID == IGNORED_ID then
		return false
	end
	if state.scanned[steamID] or state.pending[steamID] then
		return false
	end

	-- Check local database first
	local existing = Database.GetCheater(steamID)
	if existing then
		-- Already known as cheater, skip scanning
		state.scanned[steamID] = true
		return false
	end

	state.pending[steamID] = {
		name = context and context.name or nil,
		queuedAt = globals.RealTime(),
	}
	return true
end

local function resetState(clearScanned)
	state.pending = {}
	if clearScanned then
		state.scanned = {}
	end
	state.initialQueued = false
	state.lastBatchTime = 0
	state.scanning = false
	state.errorCount = 0
	state.nextRetryTime = 0
end

local function queueCurrentPlayers()
	local queued = 0
	local maxClients = (globals and globals.MaxClients and globals.MaxClients()) or 32
	for i = 1, maxClients do
		local info = client.GetPlayerInfo(i)
		if info and info.SteamID and not info.IsBot and not info.IsHLTV then
			-- Skip local player unless debug mode is enabled
			local isLocal = false
			local localPlayer = entities.GetLocalPlayer()
			if localPlayer and localPlayer:GetIndex() == i then
				isLocal = true
			end

			-- Check if player is on a valid team (Red=2, Blue=3)
			local entity = entities.GetByIndex(i)
			local teamNum = entity and entity:GetTeamNumber() or 0
			local isValidTeam = teamNum == 2 or teamNum == 3

			if (isValidTeam and not isLocal) or (G.Menu.Advanced and G.Menu.Advanced.debug) then
				local steamID64 = nil
				local steamIDStr = tostring(info.SteamID)
				if steamIDStr:match("^7656119%d+$") then
					steamID64 = normalizeSteamID64(steamIDStr)
				elseif steamIDStr:match("%[U:1:%d+%]") then
					steamID64 = normalizeSteamID64(Common.FromSteamid3To64(steamIDStr))
				end
				if steamID64 then
					local contextName = info.Name
					if queueSteamID(steamID64, { name = contextName }) then
						queued = queued + 1
					end
				end
			end
		end
	end

	if queued > 0 then
		printInfo(
			{ 0, 200, 255, 255 },
			string.format("[SteamHistory] Queued %d player%s for scanning", queued, queued == 1 and "" or "s")
		)
	end
end

local function popBatch()
	local ids = {}
	local contexts = {}
	local batchSize = state.currentBatchSize
	for steamID, ctx in pairs(state.pending) do
		ids[#ids + 1] = steamID
		contexts[steamID] = ctx
		state.pending[steamID] = nil
		if #ids >= batchSize then
			break
		end
	end
	return ids, contexts
end

local function matchesKeyword(reason)
	if not reason or reason == "" then
		return false
	end
	local lower = reason:lower()
	for _, keyword in ipairs(KEYWORDS) do
		if lower:find(keyword, 1, true) then
			return true
		end
	end
	return false
end

local function resolveName(steamID, context, entry, stateEntry)
	local contextName = context and context.name
	if contextName and contextName ~= "" then
		return contextName
	end
	if stateEntry and stateEntry.info and stateEntry.info.Name and stateEntry.info.Name ~= "" then
		return stateEntry.info.Name
	end
	if entry and entry.PersonaName and entry.PersonaName ~= "" then
		return entry.PersonaName
	end
	local scoreboardName = getPlayerNameBySteamID(steamID)
	if scoreboardName and scoreboardName ~= "" then
		return scoreboardName
	end
	return string.format("Player %s", steamID)
end

local function flagPlayer(steamID, context, entry)
	local reason = entry.BanReason or "Unknown reason"
	local stateEntry = PlayerState and PlayerState.GetOrCreate(steamID)
	if stateEntry and context and context.name and context.name ~= "" then
		stateEntry.info = stateEntry.info or {}
		stateEntry.info.Name = context.name
	end

	local name = resolveName(steamID, context, entry, stateEntry)

	printInfo({ 255, 120, 120, 255 }, string.format("[SteamHistory] %s flagged (%s)", name, reason))

	local formattedReason = string.format("SteamHistory (%s)", reason)
	if stateEntry then
		stateEntry.info = stateEntry.info or {}
		stateEntry.info.LastFlagReason = formattedReason
		stateEntry.info.LastFlagSource = "SteamHistory"
		local evidence = stateEntry.Evidence or {}
		evidence.Reasons = evidence.Reasons or {}
		evidence.Reasons.SteamHistory = {
			Weight = (evidence.Reasons.SteamHistory and evidence.Reasons.SteamHistory.Weight) or 0,
			Category = "Exploit",
			LastAddedTick = globals.TickCount(),
		}
		stateEntry.Evidence = evidence
	end

	Database.UpsertCheater(steamID, {
		name = name,
		reason = formattedReason,
	})

	-- Set priority 10 if AutoPriority enabled
	if G.Menu and G.Menu.Main and G.Menu.Main.AutoPriority then
		Database.SetPriority(steamID, 10, true)
	end

	JoinNotifications.SendCheaterAlert({
		name = name,
		reason = formattedReason,
		tail = string.format("is in the server (Suspected of: %s)", formattedReason),
		allowParty = false,
	})
end

local function handleError(message, contexts)
	state.errorCount = state.errorCount + 1
	state.consecutiveFailures = state.consecutiveFailures + 1

	-- Adaptive backoff based on error type
	local delay
	if message:match("Rate limited") or message:match("429") then
		-- Rate limit: longer backoff, start at 30s
		delay = math.min(300, 30 * (2 ^ (state.errorCount - 1))) -- Max 5 minutes

		-- Reduce batch size on rate limiting
		if state.currentBatchSize > 25 then
			state.currentBatchSize = math.max(25, math.floor(state.currentBatchSize / 2))
			printInfo(
				{ 255, 200, 100, 255 },
				string.format("[SteamHistory] Rate limited - reducing batch size to %d", state.currentBatchSize)
			)
		end
		state.rateLimitedRecently = true
	elseif message:match("Server error") or message:match("502") or message:match("503") or message:match("504") then
		-- Server errors: moderate backoff, start at 15s
		delay = math.min(120, 15 * (2 ^ (state.errorCount - 1))) -- Max 2 minutes

		-- Reduce batch size on server errors
		if state.currentBatchSize > 25 then
			state.currentBatchSize = math.max(25, math.floor(state.currentBatchSize * 0.75))
			printInfo(
				{ 255, 200, 100, 255 },
				string.format("[SteamHistory] Server errors - reducing batch size to %d", state.currentBatchSize)
			)
		end
	else
		-- Other errors: normal backoff, start at 10s
		delay = math.min(60, 10 * (2 ^ (state.errorCount - 1))) -- Max 1 minute
	end
	state.nextRetryTime = globals.RealTime() + delay

	-- If we've hit max cooldown (60s) and failed too many times, disable temporarily
	if delay >= 60 and state.consecutiveFailures >= state.maxConsecutiveFailures then
		state.temporarilyDisabled = true
		printInfo(
			{ 255, 80, 80, 255 },
			string.format(
				"[SteamHistory] API appears to be down (%d consecutive failures). Disabling SteamHistory scanning.",
				state.consecutiveFailures
			)
		)
		printInfo(
			{ 255, 120, 120, 255 },
			"[SteamHistory] Re-enable manually via menu or use console command: steamhistory_rescan"
		)
		-- Clear pending queue to avoid wasting memory
		state.pending = {}
		state.scanning = false
		return
	end

	printInfo(
		{ 255, 100, 100, 255 },
		string.format(
			"[SteamHistory] Error: %s. Retrying in %ds... (%d/%d failures)",
			message,
			delay,
			state.consecutiveFailures,
			state.maxConsecutiveFailures
		)
	)

	-- Requeue items
	if contexts then
		for steamID, ctx in pairs(contexts) do
			state.pending[steamID] = ctx
		end
	end
	state.scanning = false
end

local function handleBatchResponse(ids, contexts, responseTable)
	local responseMap = {}
	if type(responseTable) ~= "table" then
		handleError("Invalid response format (not a table)", contexts)
		return
	end

	-- Check for API error messages in response
	if responseTable.error or responseTable.message or responseTable.status == "error" then
		local errorMsg = responseTable.error or responseTable.message or "Unknown API error"
		handleError(string.format("API error: %s", errorMsg), contexts)
		return
	end

	-- Extract response array if wrapped
	if responseTable.response and type(responseTable.response) == "table" then
		responseTable = responseTable.response
	end

	-- Build response map from entries (empty array = all players clean, which is valid)
	for _, entry in pairs(responseTable) do
		if type(entry) == "table" then
			local steamID = normalizeSteamID64(entry.SteamID or entry.steamid or entry.id)
			if steamID then
				responseMap[steamID] = entry
			end
		end
	end

	-- Empty response is valid - means no bans found for queried players

	local flagged = 0
	for _, steamID in ipairs(ids) do
		if type(steamID) ~= "string" then
			steamID = tostring(steamID)
		end
		state.scanned[steamID] = true
		local entry = responseMap[steamID]
		local context = contexts[steamID] or {}
		if entry and matchesKeyword(entry.BanReason or "") then
			flagged = flagged + 1
			flagPlayer(steamID, context, entry)
		else
			-- Player is clean or not found in SteamHistory
		end
	end

	local passed = #ids - flagged
	printInfo(
		flagged > 0 and { 255, 200, 120, 255 } or { 0, 200, 255, 255 },
		string.format("[SteamHistory] Batch: %d flagged, %d clean", flagged, passed)
	)

	-- Success! Reset error count and consecutive failures
	state.errorCount = 0
	state.nextRetryTime = 0
	state.consecutiveFailures = 0
	state.scanning = false

	-- Gradually restore batch size on success
	if state.currentBatchSize < MAX_BATCH then
		-- Only increase if we weren't rate limited recently
		if not state.rateLimitedRecently then
			state.currentBatchSize = math.min(MAX_BATCH, state.currentBatchSize + 10)
			if state.currentBatchSize < MAX_BATCH then
				printInfo(
					{ 150, 255, 150, 255 },
					string.format("[SteamHistory] Success - increasing batch size to %d", state.currentBatchSize)
				)
			else
				printInfo({ 150, 255, 150, 255 }, "[SteamHistory] Success - batch size restored to maximum")
			end
		else
			state.rateLimitedRecently = false -- Reset flag after one successful batch
		end
	end
end

local function requestBatch()
	local cfg = getConfig()
	if not cfg or not cfg.ApiKey or cfg.ApiKey == "" then
		return
	end

	local ids, contexts = popBatch()
	if #ids == 0 then
		return
	end

	state.scanning = true
	state.lastBatchTime = globals.RealTime()

	local url = string.format(API_TEMPLATE, cfg.ApiKey, table.concat(ids, ","))

	-- Track request start time for timeout detection
	local requestStart = globals.RealTime()
	local success, body = pcall(http.Get, url)
	local requestDuration = globals.RealTime() - requestStart

	if not success or type(body) ~= "string" or body == "" then
		local errorMsg = "HTTP Request failed"
		if requestDuration > 10 then
			errorMsg = string.format("HTTP Request timed out (%.1fs)", requestDuration)
		end
		handleError(errorMsg, contexts)
		return
	end

	-- Warn about slow responses (potential rate limiting)
	if requestDuration > 5 then
		printInfo({ 255, 200, 100, 255 }, string.format("[SteamHistory] Slow response (%.1fs)", requestDuration))
	end

	-- Check for HTML/Error responses
	if
		body:match("<html>")
		or body:match("<title>")
		or body:match("502 Bad Gateway")
		or body:match("503 Service Unavailable")
		or body:match("504 Gateway Timeout")
		or body:match("429 Too Many Requests")
		or body:match("429 Rate Limited")
		or body:match("Rate limit exceeded")
		or body:match("error code:")
		or body:match("Cloudflare")
		or body:match("DDoS protection")
	then
		local errorMsg = "API returned HTML (likely down)"
		if body:match("429") or body:match("Rate limit") then
			errorMsg = "Rate limited (429)"
		elseif body:match("502") or body:match("503") or body:match("504") then
			errorMsg = "Server error (502/503/504)"
		elseif body:match("Cloudflare") or body:match("DDoS") then
			errorMsg = "Cloudflare/DDoS protection"
		end
		handleError(errorMsg, contexts)
		return
	end

	local ok, decoded = pcall(Json.decode, body)
	if not ok or type(decoded) ~= "table" then
		local preview = body:sub(1, 50):gsub("\n", " ")
		handleError(string.format("JSON Decode failed (%s...)", preview), contexts)
		return
	end

	-- Success! Reset error count
	state.errorCount = 0
	state.nextRetryTime = 0
	state.consecutiveFailures = 0

	handleBatchResponse(ids, contexts, decoded)
	state.scanning = false
end

local function refreshEnabled()
	local cfg = getConfig()
	local apiKey = cfg and cfg.ApiKey or nil
	apiKey = apiKey ~= "" and apiKey or nil

	if apiKey ~= state.apiKey then
		state.apiKey = apiKey
		resetState(true)
	end

	local enabled = cfg and cfg.Enable and apiKey ~= nil
	if enabled ~= state.enabled then
		state.enabled = enabled
		if enabled then
			printInfo({ 0, 200, 255, 255 }, "[SteamHistory] SteamHistory scanning enabled")
		else
			printInfo({ 200, 200, 200, 255 }, "[SteamHistory] SteamHistory scanning disabled")
			resetState(false)
		end
	end

	return state.enabled
end

--[[ Event Handlers ]]
local function onPlayerTeam(event)
	if event:GetName() ~= "player_team" then
		return
	end

	if not state.enabled then
		return
	end

	local team = event:GetInt("team")
	-- Only scan if joining Red (2) or Blue (3)
	if team ~= 2 and team ~= 3 then
		return
	end

	local userid = event:GetInt("userid")
	local playerEntity = entities.GetByUserID(userid)
	if not playerEntity then
		return
	end

	local playerIndex = playerEntity:GetIndex()
	local info = client.GetPlayerInfo(playerIndex)

	-- Check if bot via player info (bot field doesn't exist in event)
	if not info or info.IsBot or info.IsHLTV then
		return
	end

	-- Skip local player
	local localPlayer = entities.GetLocalPlayer()
	if localPlayer and localPlayer:GetIndex() == playerIndex then
		if not (G.Menu.Advanced and G.Menu.Advanced.debug) then
			return
		end
	end

	local steamIDStr = tostring(info.SteamID)
	local steamID = nil
	if steamIDStr:match("^7656119%d+$") then
		steamID = normalizeSteamID64(steamIDStr)
	elseif steamIDStr:match("%[U:1:%d+%]") then
		steamID = normalizeSteamID64(Common.FromSteamid3To64(steamIDStr))
	end

	if steamID then
		if queueSteamID(steamID, { name = info.Name }) then
			printInfo(
				{ 0, 200, 255, 255 },
				string.format("[SteamHistory] New player joined: %s - queued for scan", info.Name or steamID)
			)
		end
	end
end

local function onGameEvent(event)
	local name = event:GetName()
	if name == "player_team" then
		onPlayerTeam(event)
	elseif name == "game_newmap" or name == "teamplay_round_start" then
		resetState(true)
	end
end

local function onCreateMove()
	if not refreshEnabled() then
		return
	end

	if state.temporarilyDisabled then
		return
	end

	if not state.initialQueued then
		queueCurrentPlayers()
		state.initialQueued = true
	end

	if state.scanning then
		return
	end

	-- Check if we are in cooldown
	if globals.RealTime() < state.nextRetryTime then
		return
	end

	if next(state.pending) and globals.RealTime() - state.lastBatchTime >= MIN_INTERVAL then
		requestBatch()
	end
end

--[[ Public API ]]
function SteamHistory.OnApiKeyUpdated()
	resetState(true)
	refreshEnabled()
end

function SteamHistory.QueueRescan()
	resetState(true)
	state.temporarilyDisabled = false
	state.currentBatchSize = MAX_BATCH -- Reset to maximum
	state.rateLimitedRecently = false
	printInfo(
		{ 0, 200, 255, 255 },
		string.format("[SteamHistory] Re-enabled, queue reset, batch size restored to %d", MAX_BATCH)
	)
end

--[[ Callback Registration ]]
callbacks.Unregister("FireGameEvent", "CD_SteamHistory_Events")
callbacks.Register("FireGameEvent", "CD_SteamHistory_Events", onGameEvent)

callbacks.Unregister("CreateMove", "CD_SteamHistory_OnCreateMove")
callbacks.Register("CreateMove", "CD_SteamHistory_OnCreateMove", onCreateMove)

-- Check for API key on load
local function checkApiKey()
	local cfg = getConfig()
	if not cfg or not cfg.ApiKey or cfg.ApiKey == "" then
		printInfo({ 255, 100, 100, 255 }, "[SteamHistory] API Key missing! Get one at https://steamhistory.net")
		printInfo({ 255, 100, 100, 255 }, "[SteamHistory] Set it via console: steamhistory <your_key>")
	end
end
checkApiKey()

return SteamHistory

end)
__bundle_register("Cheater_Detection.Misc.JoinNotifications", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Join/Leave Notifications for Cheaters and Valve Employees ]]

--[[ Imports ]]
local G = require("Cheater_Detection.Utils.Globals")
local Database = require("Cheater_Detection.Database.Database")
local Sources = require("Cheater_Detection.Database.Sources")
local Common = require("Cheater_Detection.Utils.Common")

--[[ Module Declaration ]]
local JoinNotifications = {}

--[[ State ]]
local hasValidatedOnLoad = false

local function NormalizeSteamID64(rawID)
	if not rawID then
		return nil
	end

	local steamID = tostring(rawID)
	if steamID:match("^7656119%d+$") and #steamID == 17 then
		return steamID
	end

	return nil
end

--[[ Helper Functions ]]

local function escapeForCommand(text)
	return text and text:gsub("\\", "\\\\"):gsub('"', '\\"') or ""
end

local function SendPartyChatMessage(message)
	if not message or message == "" then
		return
	end
	client.Command(string.format('say_party "%s"', escapeForCommand(message)), true)
end

-- message configuration table expects:
-- { label = string, labelColor = string (color code), plainPrefix = string, name = string, tail = string, allowParty = boolean }
local function SendAlert(outputConfig, messageConfig)
	if not outputConfig or not messageConfig then
		return
	end

	local label = messageConfig.label or "CHEATER"
	local labelColor = messageConfig.labelColor or "\x07FFFFFF"
	local plainPrefix = messageConfig.plainPrefix or "Player"
	local name = messageConfig.name or "Unknown"
	local tail = messageConfig.tail or ""
	local allowParty = messageConfig.allowParty ~= false

	local tailText = tail ~= "" and (" " .. tail) or ""

	local messagePlain = string.format("%s %s%s", plainPrefix, name, tailText)
	local messageBracketed = string.format("[CD] [%s] %s%s", label, name, tailText)
	local messageColored =
		string.format("\x073EFF3E[CD]\x01 %s[%s]\x01 \x03%s\x01%s", labelColor, label, name, tailText)

	if outputConfig.Console then
		print(messageBracketed)
	end

	local sentToExternalChannel = false
	local allowParty = messageConfig.allowParty
	if allowParty == nil then
		allowParty = true
	end

	if allowParty and outputConfig.PartyChat then
		SendPartyChatMessage(messageColored)
		sentToExternalChannel = true
	end

	if outputConfig.ClientChat and not sentToExternalChannel then
		if not client.ChatPrintf(messageColored) then
			print("[CD] Failed to send client chat message")
		end
	elseif not outputConfig.PublicChat and not outputConfig.ClientChat then
		-- Ensure local feedback even if only console output was requested
		if not client.ChatPrintf(messageColored) then
			print("[CD] Failed to send fallback client chat message")
		end
	end
end

local function GetEffectiveOutput(defaultOutput, overrideOutput, useOverride)
	if useOverride and overrideOutput then
		return overrideOutput
	end
	return defaultOutput
end

local function GetJoinNotificationsConfig()
	local config = G.Menu and G.Menu.Misc and G.Menu.Misc.JoinNotifications
	if not config or not config.Enable then
		return nil
	end

	if type(config.ValveAutoDisconnect) ~= "boolean" then
		return nil
	end

	return config
end

local function DispatchCheaterAlert(config, params)
	if not config or not config.CheckCheater then
		return false
	end

	local reason = params.reason or "Unknown"
	local tail = params.tail or string.format("is in the server (Suspected of: %s)", reason)
	local allowParty = params.allowParty
	if allowParty == nil then
		allowParty = false
	end

	local output = GetEffectiveOutput(config.DefaultOutput, config.CheaterOverride, config.UseCheaterOverride)

	SendAlert(output, {
		label = "CHEATER",
		labelColor = "\x07FF0000",
		plainPrefix = params.plainPrefix or "Cheater",
		name = params.name or "Unknown",
		tail = tail,
		allowParty = allowParty,
	})

	return true
end

local function DispatchValveAlert(config, params)
	if not config or not config.CheckValve then
		return false
	end

	local tail = params.tail or "is in the server"
	local allowParty = params.allowParty
	if allowParty == nil then
		allowParty = false
	end

	local output = GetEffectiveOutput(config.DefaultOutput, config.ValveOverride, config.UseValveOverride)
	SendAlert(output, {
		label = "VALVE",
		labelColor = "\x078650AC",
		plainPrefix = params.plainPrefix or "Valve employee",
		name = params.name or "Unknown",
		tail = tail,
		allowParty = allowParty,
	})

	return true
end

function JoinNotifications.SendCheaterAlert(params)
	local config = GetJoinNotificationsConfig()
	if not config then
		return false
	end

	return DispatchCheaterAlert(config, params or {})
end

function JoinNotifications.SendValveAlert(params)
	local config = GetJoinNotificationsConfig()
	if not config then
		return false
	end

	return DispatchValveAlert(config, params or {})
end

-- Check all players currently in the game for Valve employees and cheaters
-- If Valve found and auto-disconnect enabled, leave server
local function ValidateAllPlayers()
	local config = GetJoinNotificationsConfig()
	if not config then
		return -- Config not fully loaded yet
	end

	local players = entities.FindByClass("CTFPlayer")
	for _, player in ipairs(players) do
		if player and player:IsValid() then
			local steamID64 = NormalizeSteamID64(Common.GetSteamID64(player))
			if steamID64 then
				-- Check Valve employee first (higher priority)
				if config.CheckValve and Sources.IsValveEmployee(steamID64) then
					local alertSent = DispatchValveAlert(config, {
						name = player:GetName(),
						tail = config.ValveAutoDisconnect and "is in the server - Leaving game" or "is in the server",
						allowParty = false,
					})
					if alertSent and config.ValveAutoDisconnect then
						client.Command("disconnect", true)
						return
					end
				-- Check if cheater in database
				elseif config.CheckCheater then
					local cheaterData = Database.GetCheater(steamID64)
					if cheaterData then
						DispatchCheaterAlert(config, {
							name = player:GetName(),
							reason = cheaterData.Reason,
							allowParty = false,
						})
					end
				end
			end
		end
	end
end

--[[ Event Handlers ]]

-- Handle player connect event
local function OnPlayerConnect(event)
	if event:GetName() ~= "player_connect" then
		return
	end

	local config = GetJoinNotificationsConfig()
	if not config then
		return
	end

	-- Get player info from event
	local name = event:GetString("name")
	local networkid = event:GetString("networkid")

	-- Extract SteamID64 from networkid (format: [U:1:XXXXXXXX])
	local steamID64 = NormalizeSteamID64(Common.FromSteamid3To64(networkid))
	if not steamID64 then
		return
	end

	-- Check if Valve employee (higher priority)
	if config.CheckValve and Sources.IsValveEmployee(steamID64) then
		local tail = config.ValveAutoDisconnect and "joined - Leaving game" or "joined"
		local alertSent = DispatchValveAlert(config, {
			name = name,
			tail = tail,
			allowParty = false,
		})
		if alertSent and config.ValveAutoDisconnect then
			client.Command("disconnect", true)
		end
		return
	end

	-- Check if cheater in database
	if config.CheckCheater then
		local cheaterData = Database.GetCheater(steamID64)
		if cheaterData then
			local reason = cheaterData.Reason or "Unknown"
			DispatchCheaterAlert(config, {
				name = name,
				reason = reason,
				tail = string.format("joined (Suspected of: %s)", reason),
				allowParty = false,
			})
		end
	end
end

-- Handle player disconnect event
local function OnPlayerDisconnect(event)
	if event:GetName() ~= "player_disconnect" then
		return
	end

	local config = GetJoinNotificationsConfig()
	if not config then
		return
	end

	-- Get player info from event
	local name = event:GetString("name")
	local networkid = event:GetString("networkid")

	-- Extract SteamID64 from networkid (format: [U:1:XXXXXXXX])
	local steamID64 = NormalizeSteamID64(Common.FromSteamid3To64(networkid))
	if not steamID64 then
		return
	end

	-- Don't show disconnect messages for Valve employees (we left the game)
	-- Only check cheaters
	if config.CheckCheater then
		local cheaterData = Database.GetCheater(steamID64)
		if cheaterData then
			local reason = cheaterData.Reason or "Unknown"
			DispatchCheaterAlert(config, {
				name = name,
				reason = reason,
				tail = string.format("left (Suspected of: %s)", reason),
			})
		end
	end
end

-- Master event handler for both connect and disconnect
local function OnGameEvent(event)
	local eventName = event:GetName()

	if eventName == "player_connect" then
		OnPlayerConnect(event)
	elseif eventName == "player_disconnect" then
		OnPlayerDisconnect(event)
	end
end

--[[ CreateMove Callback for Initial Validation ]]
local function OnCreateMove()
	-- Run validation once on first tick after config is loaded
	if not hasValidatedOnLoad then
		local config = G.Menu and G.Menu.Misc and G.Menu.Misc.JoinNotifications
		-- Check if config is loaded (has boolean ValveAutoDisconnect)
		if config and type(config.ValveAutoDisconnect) == "boolean" then
			ValidateAllPlayers()
			hasValidatedOnLoad = true
			-- Unregister after first run
			callbacks.Unregister("CreateMove", "CD_JoinNotifications_Init")
		end
	end
end

--[[ Callback Registration ]]
callbacks.Unregister("FireGameEvent", "CD_JoinNotifications")
callbacks.Register("FireGameEvent", "CD_JoinNotifications", OnGameEvent)

-- Register CreateMove to validate existing players on first tick
callbacks.Unregister("CreateMove", "CD_JoinNotifications_Init")
callbacks.Register("CreateMove", "CD_JoinNotifications_Init", OnCreateMove)

return JoinNotifications

end)
__bundle_register("Cheater_Detection.Utils.Commands", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Command bridge ]] 

local G = require("Cheater_Detection.Utils.Globals")
local Logger = require("Cheater_Detection.Utils.Logger")
local Common = require("Cheater_Detection.Utils.Common")

local lnxCommands = Common.Lib and Common.Lib.Utils and Common.Lib.Utils.Commands

local Commands = {}

local function ensureLnxCommands()
	if not lnxCommands then
		lnxCommands = Common.Lib and Common.Lib.Utils and Common.Lib.Utils.Commands
	end
	return lnxCommands
end

local function RegisterSteamHistory()
	local bridge = ensureLnxCommands()
	if not bridge or Commands._steamHistoryRegistered then
		return
	end

	Commands._steamHistoryRegistered = true
	bridge.Register("steamhistory", function(args)
		local shell = G.Menu and G.Menu.Misc and G.Menu.Misc.SteamHistory
		if not shell then
			Logger.Error("Commands", "SteamHistory menu state missing; config not initialised")
			return
		end

		local key = args and args:popFront() or nil
		if not key or key == "" then
			Logger.Warning("Commands", "Usage: steamhistory <api_key>")
			return
		end

		shell.ApiKey = key
		shell.Enable = false
		Logger.Info("Commands", "SteamHistory API key stored (scanning disabled until toggled)")
	end)
end

function Commands.Setup()
	if ensureLnxCommands() then
		RegisterSteamHistory()
	else
		Logger.Error("Commands", "lnxLib command subsystem unavailable; steam history command skipped")
	end
end

Commands.Setup()

return Commands

end)
__bundle_register("Cheater_Detection.Misc.ChatPrefix", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Chat Prefix Module ]]
-- Displays colored status tags before cheater names in chat

--[[ Imports ]]
local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local Evidence = require("Cheater_Detection.Core.Evidence_system")
local Database = require("Cheater_Detection.Database.Database")
local ValveEmployees = require("Cheater_Detection.Database.ValveEmployees")

local ChatPrefix = {}

-- SayText2 message ID from E_UserMessage enum
local SayText2 = 4

---@param playerName string
---@return Entity?
local function GetPlayerFromName(playerName)
	for _, player in pairs(entities.FindByClass("CTFPlayer")) do
		if player:GetName() == playerName then
			return player
		end
	end
	return nil
end

---Convert RGB to hex color code for Source engine
---@param r number Red (0-255)
---@param g number Green (0-255)
---@param b number Blue (0-255)
---@return string Hex color code
local function rgbToHex(r, g, b)
	local hexadecimal = "\x07"

	for _, value in pairs({ r, g, b }) do
		local hex = ""

		while value > 0 do
			local index = math.fmod(value, 16) + 1
			value = math.floor(value / 16)
			hex = string.sub("0123456789ABCDEF", index, index) .. hex
		end

		if string.len(hex) == 0 then
			hex = "00"
		elseif string.len(hex) == 1 then
			hex = "0" .. hex
		end

		hexadecimal = hexadecimal .. hex
	end

	return hexadecimal
end

---Clear the entire bit buffer
---@param bf BitBuffer
local function ClearBuffer(bf)
	local len = bf:GetDataBitsLength()
	bf:SetCurBit(0)
	for i = 0, len do
		bf:WriteBit(0)
	end
	bf:SetCurBit(0)
end

---Get cheater status for a player
---@param player Entity
---@return string|nil status "CHEATER", "SUSPICIOUS", "VALVE" or nil
---@return table color RGB color {r, g, b}
local function GetCheaterStatus(player)
	if not player then
		return nil, { 255, 255, 255 }
	end

	local steamID = tostring(Common.GetSteamID64(player))
	if not steamID then
		return nil, { 255, 255, 255 }
	end

	-- Check if Valve employee first (takes priority)
	local isValve, valveName = ValveEmployees.IsValveEmployee(steamID)
	if isValve then
		-- Purple for Valve employee (Valve quality item color #8650AC)
		return "VALVE", { 134, 80, 172 }
	end

	-- Check if marked by Evidence system
	local isMarkedCheater = Evidence.IsMarkedCheater(steamID)

	-- Check if player is in database
	local dbEntry = Database.GetCheater(steamID)
	local inDatabase = dbEntry ~= nil

	if isMarkedCheater or inDatabase then
		-- Red for confirmed cheater
		return "CHEATER", { 255, 0, 0 }
	end

	-- Check if has some evidence (suspicious)
	local evidence = Evidence.GetDetails(steamID)
	if evidence and evidence.TotalScore and evidence.TotalScore > 0 then
		-- Yellow for suspicious (has evidence but not marked yet)
		return "SUSPICIOUS", { 255, 255, 0 }
	end

	return nil, { 255, 255, 255 }
end

---UserMessage callback to modify chat messages
---@param msg UserMessage
local function OnUserMessage(msg)
	-- Check if feature is enabled
	if not G.Menu or not G.Menu.Main or not G.Menu.Main.Chat_Prefix then
		return
	end

	-- Only process SayText2 messages (chat)
	if msg:GetID() ~= SayText2 then
		return
	end

	local bf = msg:GetBitBuffer()
	if not bf then
		return
	end

	bf:SetCurBit(0)

	-- Read chat data (TF2's actual SayText2 structure)
	local wantsToChat = bf:ReadByte() -- Byte 0-7: wants to chat flag
	local clientIndex = bf:ReadByte() -- Byte 8-15: client index
	local isChat = bf:ReadByte() -- Byte 16-23: chat flag (THIS WAS MISSING!)
	local chatType = bf:ReadString(256) -- Now properly aligned - e.g. "TF_Chat_Team"
	local playerName = bf:ReadString(256)
	local messageText = bf:ReadString(256)

	-- Get player entity
	local player = GetPlayerFromName(playerName)
	if not player then
		return
	end

	-- Get cheater status
	local status, color = GetCheaterStatus(player)

	-- Check if this is a [CD] system message (after getting status to allow override)
	if messageText:find("%[CD%]") then
		-- System message - display without prefix
		if not client.ChatPrintf(messageText) then
			print("[CD] Failed to send system message")
		end

		-- Wipe original payload so nothing extra prints
		ClearBuffer(bf)
		bf:SetCurBit(0)
		return
	end

	if status then
		-- Build colored output for ChatPrintf
		local colorHex = rgbToHex(color[1], color[2], color[3])
		local tag = string.format("\x01[%s%s\x01]", colorHex, status)
		local teamColor = "\x01"
		local team = player:GetTeamNumber()
		if team == 2 then
			teamColor = "\x07FF4040"
		elseif team == 3 then
			teamColor = "\x0799CCFF"
		end
		local name = string.format("%s%s", teamColor, playerName)
		local formatted = string.format("%s %s\x01 :  %s", tag, name, messageText)

		if not client.ChatPrintf(formatted) then
			print("[CD] Failed to send chat prefix message")
		end

		-- Wipe original payload so nothing extra prints
		ClearBuffer(bf)
		bf:SetCurBit(0)
		return
	end
end

--[[ Callbacks ]]
callbacks.Unregister("DispatchUserMessage", "CD_ChatPrefix")
callbacks.Register("DispatchUserMessage", "CD_ChatPrefix", OnUserMessage)

return ChatPrefix

end)
__bundle_register("Cheater_Detection.Misc.Visuals.Menu", function(require, _LOADED, __bundle_register, __bundle_modules)
local Menu = {}

local Common = require("Cheater_Detection.Utils.Common")
local G = require("Cheater_Detection.Utils.Globals")
local TickProfiler = require("Cheater_Detection.Utils.TickProfiler")

local Lib = Common.Lib
local Fonts = Lib.UI.Fonts

-- Try to load TimMenu (assumes it's installed globally in Lmaobox)
local TimMenu = nil
local timMenuLoaded, timMenuModule = pcall(require, "TimMenu")
if timMenuLoaded and timMenuModule then
	TimMenu = timMenuModule
	print("[CD] TimMenu loaded successfully")
else
	error("[CD] TimMenu not found! Please install TimMenu to %localappdata%\\lmaobox\\Scripts\\TimMenu.lua")
end

local function DrawMenu()
	TickProfiler.BeginSection("Draw_Menu")

	-- Debug mode indicator (drawn outside TimMenu window)
	if G.Menu.Advanced.debug then
		draw.Color(255, 0, 0, 255)
		draw.SetFont(Fonts.Verdana)
		draw.Text(20, 120, "Debug Mode!!! Some Features Might malfunction")
	end

	-- Begin the menu - visibility directly tied to Lmaobox menu state
	if not TimMenu.Begin("Cheater Detection", gui.IsMenuOpen()) then
		return
	end

	-- Tabs for different sections
	local tabs = { "Main", "Advanced", "Misc" }
	G.Menu.currentTab = TimMenu.TabControl("cd_main_tabs", tabs, G.Menu.currentTab)
	TimMenu.NextLine()

	-- Main Configuration Tab
	if G.Menu.currentTab == "Main" then
		local Main = G.Menu.Main
		local Misc = G.Menu.Misc

		TimMenu.BeginSector("SteamHistory")
		G.Menu.Misc.SteamHistory = G.Menu.Misc.SteamHistory or {}
		local sh = G.Menu.Misc.SteamHistory
		sh.ApiKey = sh.ApiKey or ""
		if type(sh.Enable) ~= "boolean" then
			sh.Enable = false
		end
		local hasKey = sh.ApiKey ~= ""
		if not hasKey then
			sh.Enable = false
			TimMenu.Text("API Key Missing!")
			TimMenu.Text("Get key at: steamhistory.net")
			TimMenu.Text("Console cmd: steamhistory <key>")
		else
			sh.Enable = TimMenu.Checkbox("Enable SteamHistory", sh.Enable)
			TimMenu.Tooltip("Scan players via SteamHistory API.")
		end
		TimMenu.EndSector()
		TimMenu.NextLine()

		TimMenu.BeginSector("Detection Automation")
		TimMenu.Tooltip("Download external cheater lists on demand.")
		TimMenu.NextLine()
		if type(Main.AutoPriority) ~= "boolean" then
			Main.AutoPriority = true
		end
		Main.AutoPriority = TimMenu.Checkbox("Auto Priority", Main.AutoPriority)
		TimMenu.Tooltip("Set priority 10 on detected cheaters (from evidence, database, or SteamHistory)")
		TimMenu.NextLine()
		if type(Main.partyCallaut) ~= "boolean" then
			Main.partyCallaut = true
		end
		Main.partyCallaut = TimMenu.Checkbox("Party Callouts", Main.partyCallaut)
		TimMenu.Tooltip("Share detections with your party through chat.")
		TimMenu.EndSector()
		TimMenu.NextLine()

		TimMenu.BeginSector("Visual Feedback")
		if type(Main.Chat_Prefix) ~= "boolean" then
			Main.Chat_Prefix = true
		end
		Main.Chat_Prefix = TimMenu.Checkbox("Chat Prefix", Main.Chat_Prefix)
		TimMenu.Tooltip("Enable colored chat tags for cheaters, suspects, and Valve staff.")
		TimMenu.NextLine()
		if type(Main.Cheater_Tags) ~= "boolean" then
			Main.Cheater_Tags = true
		end
		Main.Cheater_Tags = TimMenu.Checkbox("Cheater Tags", Main.Cheater_Tags)
		TimMenu.Tooltip("Show floating world labels for confirmed cheaters.")
		TimMenu.EndSector()
		TimMenu.NextLine()

		Misc.JoinNotifications = Misc.JoinNotifications or {}
		local JNMain = Misc.JoinNotifications
		if type(JNMain.ValveAutoDisconnect) ~= "boolean" then
			JNMain.ValveAutoDisconnect = false
		end

		TimMenu.BeginSector("Valve Safety")
		JNMain.ValveAutoDisconnect = TimMenu.Checkbox("Auto Leave on Valve Join", JNMain.ValveAutoDisconnect)
		TimMenu.Tooltip("Disconnect automatically when a Valve employee enters the server")
		TimMenu.EndSector()
		TimMenu.NextLine()
	elseif G.Menu.currentTab == "Advanced" then
		local Advanced = G.Menu.Advanced

		TimMenu.BeginSector("Evidence System")
		-- Initialize with default value if nil
		Advanced.Evicence_Tolerance = Advanced.Evicence_Tolerance or 100
		Advanced.Evicence_Tolerance = TimMenu.Slider("Evidence Tolerance", Advanced.Evicence_Tolerance, 1, 200, 1)
		TimMenu.Tooltip("Threshold for marking players as cheaters (higher = more strict)")
		TimMenu.EndSector()
		TimMenu.NextLine()

		TimMenu.BeginSector("Exploit Detection")
		if type(Advanced.Choke) ~= "boolean" then
			Advanced.Choke = true
		end
		Advanced.Choke = TimMenu.Checkbox("Fake Lag Detection", Advanced.Choke)
		TimMenu.NextLine()
		if type(Advanced.Warp) ~= "boolean" then
			Advanced.Warp = true
		end
		Advanced.Warp = TimMenu.Checkbox("Warp/DT Detection", Advanced.Warp)
		TimMenu.NextLine()
		if type(Advanced.AntyAim) ~= "boolean" then
			Advanced.AntyAim = true
		end
		Advanced.AntyAim = TimMenu.Checkbox("Anti-Aim Detection", Advanced.AntyAim)
		TimMenu.EndSector()

		TimMenu.BeginSector("Aim Detection")
		if type(Advanced.SilentAimbot) ~= "boolean" then
			Advanced.SilentAimbot = true
		end
		Advanced.SilentAimbot = TimMenu.Checkbox("Silent Aimbot (Extrapolation)", Advanced.SilentAimbot)
		TimMenu.Tooltip("Detects silent aim using viewangle extrapolation (experimental)")
		TimMenu.EndSector()
		TimMenu.NextLine()

		TimMenu.BeginSector("Movement Detection")
		if type(Advanced.Bhop) ~= "boolean" then
			Advanced.Bhop = true
		end
		Advanced.Bhop = TimMenu.Checkbox("Bhop Detection", Advanced.Bhop)
		TimMenu.NextLine()
		if type(Advanced.DuckSpeed) ~= "boolean" then
			Advanced.DuckSpeed = true
		end
		Advanced.DuckSpeed = TimMenu.Checkbox("Duck Speed Detection", Advanced.DuckSpeed)
		TimMenu.EndSector()

		TimMenu.NextLine()

		TimMenu.BeginSector("Debug")
		if type(Advanced.debug) ~= "boolean" then
			Advanced.debug = false
		end
		Advanced.debug = TimMenu.Checkbox("Debug Mode", Advanced.debug)
		TimMenu.Tooltip("Enables debug features (auto-removes self from database, enables verbose logging)")

		local logLevels = { "Debug", "Info", "Warning", "Error" }
		Advanced.LogLevel = TimMenu.Combo("Log Level", Advanced.LogLevel, logLevels)
		TimMenu.Tooltip("Set console output verbosity (Debug = everything, Error = only critical)")

		TimMenu.EndSector()
		TimMenu.NextLine()
	elseif G.Menu.currentTab == "Misc" then
		local Misc = G.Menu.Misc

		TimMenu.BeginSector("Vote Automation")
		if type(Misc.Autovote) ~= "boolean" then
			Misc.Autovote = false
		end
		Misc.Autovote = TimMenu.Checkbox("Auto Vote", Misc.Autovote)
		TimMenu.Tooltip("Call votes automatically using your selected targets.")
		TimMenu.NextLine()
		if Misc.Autovote then
			Misc.intent = Misc.intent or {}
			-- Initialize if needed
			if type(Misc.intent.retaliation) ~= "boolean" then
				Misc.intent.retaliation = true
			end
			if type(Misc.intent.legit) ~= "boolean" then
				Misc.intent.legit = true
			end
			if type(Misc.intent.cheater) ~= "boolean" then
				Misc.intent.cheater = true
			end
			if type(Misc.intent.bot) ~= "boolean" then
				Misc.intent.bot = true
			end
			if type(Misc.intent.valve) ~= "boolean" then
				Misc.intent.valve = true
			end
			if type(Misc.intent.friend) ~= "boolean" then
				Misc.intent.friend = false
			end
			if type(Misc.AutovoteAutoCast) ~= "boolean" then
				Misc.AutovoteAutoCast = true
			end
			Misc.AutovoteAutoCast = TimMenu.Checkbox("Auto Cast Votes", Misc.AutovoteAutoCast)
			TimMenu.Tooltip("Continuously initiate votes using the configured target priority.")
			TimMenu.NextLine()

			-- Priority order: Retaliation > Bots > Cheaters > Valve > Legits > Friends
			local voteTargets =
				{ "Retaliation", "Bots (Cheat)", "Cheaters", "Valve Employees", "Legit Players", "Friends" }
			local voteTable = {
				Misc.intent.retaliation,
				Misc.intent.bot,
				Misc.intent.cheater,
				Misc.intent.valve,
				Misc.intent.legit,
				Misc.intent.friend,
			}
			voteTable = TimMenu.Combo("Vote Targets", voteTable, voteTargets)
			Misc.intent.retaliation = voteTable[1]
			Misc.intent.bot = voteTable[2]
			Misc.intent.cheater = voteTable[3]
			Misc.intent.valve = voteTable[4]
			Misc.intent.legit = voteTable[5]
			Misc.intent.friend = voteTable[6]
			TimMenu.NextLine()
		end
		TimMenu.EndSector()

		TimMenu.BeginSector("Vote Reveal Alerts")
		Misc.Vote_Reveal = Misc.Vote_Reveal or {}
		if type(Misc.Vote_Reveal.Enable) ~= "boolean" then
			Misc.Vote_Reveal.Enable = false
		end
		Misc.Vote_Reveal.TargetTeam = Misc.Vote_Reveal.TargetTeam or {}
		Misc.Vote_Reveal.Enable = TimMenu.Checkbox("Vote Reveal", Misc.Vote_Reveal.Enable)
		TimMenu.Tooltip("Announce teammate votes and their targets across selected channels.")
		TimMenu.NextLine()
		if Misc.Vote_Reveal.Enable then
			-- Initialize if needed
			if type(Misc.Vote_Reveal.TargetTeam.MyTeam) ~= "boolean" then
				Misc.Vote_Reveal.TargetTeam.MyTeam = true
			end
			if type(Misc.Vote_Reveal.TargetTeam.enemyTeam) ~= "boolean" then
				Misc.Vote_Reveal.TargetTeam.enemyTeam = true
			end

			-- Initialize new output options
			Misc.Vote_Reveal.Output = Misc.Vote_Reveal.Output or {}
			if type(Misc.Vote_Reveal.Output.PublicChat) ~= "boolean" then
				Misc.Vote_Reveal.Output.PublicChat = false
			end
			if type(Misc.Vote_Reveal.Output.PartyChat) ~= "boolean" then
				Misc.Vote_Reveal.Output.PartyChat = true
			end
			if type(Misc.Vote_Reveal.Output.ClientChat) ~= "boolean" then
				Misc.Vote_Reveal.Output.ClientChat = false
			end
			if type(Misc.Vote_Reveal.Output.Console) ~= "boolean" then
				Misc.Vote_Reveal.Output.Console = true
			end

			local teamOptions = { "My Team", "Enemy Team" }
			local teamTable = { Misc.Vote_Reveal.TargetTeam.MyTeam, Misc.Vote_Reveal.TargetTeam.enemyTeam }
			teamTable = TimMenu.Combo("Target Teams", teamTable, teamOptions)
			Misc.Vote_Reveal.TargetTeam.MyTeam = teamTable[1]
			Misc.Vote_Reveal.TargetTeam.enemyTeam = teamTable[2]
			TimMenu.NextLine()

			local outputOptions = { "Public Chat", "Party Chat", "Client Chat", "Console" }
			local outputTable = {
				Misc.Vote_Reveal.Output.PublicChat,
				Misc.Vote_Reveal.Output.PartyChat,
				Misc.Vote_Reveal.Output.ClientChat,
				Misc.Vote_Reveal.Output.Console,
			}
			outputTable = TimMenu.Combo("Vote Output", outputTable, outputOptions)
			Misc.Vote_Reveal.Output.PublicChat = outputTable[1]
			Misc.Vote_Reveal.Output.PartyChat = outputTable[2]
			Misc.Vote_Reveal.Output.ClientChat = outputTable[3]
			Misc.Vote_Reveal.Output.Console = outputTable[4]
			TimMenu.NextLine()
		end
		TimMenu.EndSector()
		TimMenu.NextLine()

		TimMenu.BeginSector("Join Alerts")
		-- Initialize JoinNotifications if needed
		Misc.JoinNotifications = Misc.JoinNotifications or {}
		local JN = Misc.JoinNotifications

		if type(JN.Enable) ~= "boolean" then
			JN.Enable = true
		end
		if type(JN.CheckCheater) ~= "boolean" then
			JN.CheckCheater = true
		end
		if type(JN.CheckValve) ~= "boolean" then
			JN.CheckValve = true
		end
		if type(JN.ValveAutoDisconnect) ~= "boolean" then
			JN.ValveAutoDisconnect = false
		end

		JN.Enable = TimMenu.Checkbox("Join Alerts", JN.Enable)
		TimMenu.Tooltip("Warn about cheaters or Valve employees joining the match.")
		TimMenu.NextLine()

		if JN.Enable then
			-- Target filters
			local notifTypes = { "Cheaters", "Valve" }
			local notifTable = { JN.CheckCheater, JN.CheckValve }
			notifTable = TimMenu.Combo("Notify For", notifTable, notifTypes)
			JN.CheckCheater = notifTable[1]
			JN.CheckValve = notifTable[2]
			TimMenu.NextLine()

			-- Default output channels
			JN.DefaultOutput = JN.DefaultOutput or {}
			if type(JN.DefaultOutput.PublicChat) ~= "boolean" then
				JN.DefaultOutput.PublicChat = false
			end
			if type(JN.DefaultOutput.PartyChat) ~= "boolean" then
				JN.DefaultOutput.PartyChat = true
			end
			if type(JN.DefaultOutput.ClientChat) ~= "boolean" then
				JN.DefaultOutput.ClientChat = false
			end
			if type(JN.DefaultOutput.Console) ~= "boolean" then
				JN.DefaultOutput.Console = true
			end

			local defaultOutputOptions = { "Public Chat", "Party Chat", "Client Chat", "Console" }
			local defaultOutputTable = {
				JN.DefaultOutput.PublicChat,
				JN.DefaultOutput.PartyChat,
				JN.DefaultOutput.ClientChat,
				JN.DefaultOutput.Console,
			}
			defaultOutputTable = TimMenu.Combo("Default Output", defaultOutputTable, defaultOutputOptions)
			JN.DefaultOutput.PublicChat = defaultOutputTable[1]
			JN.DefaultOutput.PartyChat = defaultOutputTable[2]
			JN.DefaultOutput.ClientChat = defaultOutputTable[3]
			JN.DefaultOutput.Console = defaultOutputTable[4]
			TimMenu.NextLine()

			-- Cheater override
			if type(JN.UseCheaterOverride) ~= "boolean" then
				JN.UseCheaterOverride = false
			end
			JN.UseCheaterOverride = TimMenu.Checkbox("Cheater Output Override", JN.UseCheaterOverride)
			TimMenu.Tooltip("Send cheater alerts to custom chat channels.")
			TimMenu.NextLine()

			if JN.UseCheaterOverride then
				JN.CheaterOverride = JN.CheaterOverride or {}
				if type(JN.CheaterOverride.PublicChat) ~= "boolean" then
					JN.CheaterOverride.PublicChat = false
				end
				if type(JN.CheaterOverride.PartyChat) ~= "boolean" then
					JN.CheaterOverride.PartyChat = true
				end
				if type(JN.CheaterOverride.ClientChat) ~= "boolean" then
					JN.CheaterOverride.ClientChat = false
				end
				if type(JN.CheaterOverride.Console) ~= "boolean" then
					JN.CheaterOverride.Console = true
				end

				local cheaterOutputTable = {
					JN.CheaterOverride.PublicChat,
					JN.CheaterOverride.PartyChat,
					JN.CheaterOverride.ClientChat,
					JN.CheaterOverride.Console,
				}
				cheaterOutputTable = TimMenu.Combo("Cheater Output", cheaterOutputTable, defaultOutputOptions)
				JN.CheaterOverride.PublicChat = cheaterOutputTable[1]
				JN.CheaterOverride.PartyChat = cheaterOutputTable[2]
				JN.CheaterOverride.ClientChat = cheaterOutputTable[3]
				JN.CheaterOverride.Console = cheaterOutputTable[4]
				TimMenu.NextLine()
			end

			-- Valve override
			if type(JN.UseValveOverride) ~= "boolean" then
				JN.UseValveOverride = false
			end
			JN.UseValveOverride = TimMenu.Checkbox("Valve Output Override", JN.UseValveOverride)
			TimMenu.Tooltip("Send Valve alerts to custom chat channels.")
			TimMenu.NextLine()

			if JN.UseValveOverride then
				JN.ValveOverride = JN.ValveOverride or {}
				if type(JN.ValveOverride.PublicChat) ~= "boolean" then
					JN.ValveOverride.PublicChat = false
				end
				if type(JN.ValveOverride.PartyChat) ~= "boolean" then
					JN.ValveOverride.PartyChat = false
				end
				if type(JN.ValveOverride.ClientChat) ~= "boolean" then
					JN.ValveOverride.ClientChat = true
				end
				if type(JN.ValveOverride.Console) ~= "boolean" then
					JN.ValveOverride.Console = true
				end

				local valveOutputTable = {
					JN.ValveOverride.PublicChat,
					JN.ValveOverride.PartyChat,
					JN.ValveOverride.ClientChat,
					JN.ValveOverride.Console,
				}
				valveOutputTable = TimMenu.Combo("Valve Output", valveOutputTable, defaultOutputOptions)
				JN.ValveOverride.PublicChat = valveOutputTable[1]
				JN.ValveOverride.PartyChat = valveOutputTable[2]
				JN.ValveOverride.ClientChat = valveOutputTable[3]
				JN.ValveOverride.Console = valveOutputTable[4]
				TimMenu.NextLine()
			end
		end
		TimMenu.EndSector()

		TimMenu.BeginSector("Class Change Alerts")
		Misc.Class_Change_Reveal.Enable = TimMenu.Checkbox("Class Change Reveal", Misc.Class_Change_Reveal.Enable)
		TimMenu.Tooltip("Notify when tracked players switch classes.")
		TimMenu.NextLine()
		if Misc.Class_Change_Reveal.Enable then
			-- Initialize if needed
			if type(Misc.Class_Change_Reveal.EnemyOnly) ~= "boolean" then
				Misc.Class_Change_Reveal.EnemyOnly = true
			end

			-- Initialize new output options
			Misc.Class_Change_Reveal.Output = Misc.Class_Change_Reveal.Output or {}
			if type(Misc.Class_Change_Reveal.Output.PublicChat) ~= "boolean" then
				Misc.Class_Change_Reveal.Output.PublicChat = false
			end
			if type(Misc.Class_Change_Reveal.Output.PartyChat) ~= "boolean" then
				Misc.Class_Change_Reveal.Output.PartyChat = true
			end
			if type(Misc.Class_Change_Reveal.Output.ClientChat) ~= "boolean" then
				Misc.Class_Change_Reveal.Output.ClientChat = false
			end
			if type(Misc.Class_Change_Reveal.Output.Console) ~= "boolean" then
				Misc.Class_Change_Reveal.Output.Console = true
			end

			Misc.Class_Change_Reveal.EnemyOnly = TimMenu.Checkbox("Enemy Team Only", Misc.Class_Change_Reveal.EnemyOnly)
			TimMenu.NextLine()

			local classOutputOptions = { "Public Chat", "Party Chat", "Client Chat", "Console" }
			local classOutputTable = {
				Misc.Class_Change_Reveal.Output.PublicChat,
				Misc.Class_Change_Reveal.Output.PartyChat,
				Misc.Class_Change_Reveal.Output.ClientChat,
				Misc.Class_Change_Reveal.Output.Console,
			}
			classOutputTable = TimMenu.Combo("Class Change Output", classOutputTable, classOutputOptions)
			Misc.Class_Change_Reveal.Output.PublicChat = classOutputTable[1]
			Misc.Class_Change_Reveal.Output.PartyChat = classOutputTable[2]
			Misc.Class_Change_Reveal.Output.ClientChat = classOutputTable[3]
			Misc.Class_Change_Reveal.Output.Console = classOutputTable[4]
			TimMenu.NextLine()
		end
		TimMenu.EndSector()
		TimMenu.NextLine()

		if TimMenu.Button("Fetch Database") then
			local Fetcher = require("Cheater_Detection.Database.Fetcher")
			Fetcher.Start()
		end

		TimMenu.NextLine()

		TimMenu.EndSector()
		TimMenu.NextLine()
	end

	-- Always end the menu
	TimMenu.End()

	TickProfiler.EndSection("Draw_Menu")
end

--[[ Callbacks ]]
callbacks.Unregister("Draw", "CD_MENU")
callbacks.Register("Draw", "CD_MENU", DrawMenu)

return Menu

end)
__bundle_register("Cheater_Detection.Database.Fetcher", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Cheater Detection - Database Fetcher - Synchronous Simplified Version ]]
local Common = require("Cheater_Detection.Utils.Common")
-- [[ Imported by: Main.lua ]]
local G = require("Cheater_Detection.Utils.Globals")
-- [[ Imported by: None ]]
local Json = Common.Json
-- [[ Imported by: Fetcher.lua (indirectly via Common) ]]
local Database = require("Cheater_Detection.Database.Database") -- For SaveDatabase
-- [[ Imported by: Fetcher.lua ]]
local Sources = require("Cheater_Detection.Database.Sources") -- Require Sources
-- [[ Imported by: Fetcher.lua ]]
local Parsers = require("Cheater_Detection.Database.Parsers") -- Require Parsers
-- [[ Imported by: Fetcher.lua ]]

local Fetcher = {}

-- Define LogLevel locally within Fetcher
local LogLevel = {
	ERROR = 1,
	WARNING = 2,
	SUCCESS = 3,
	INFO = 4,
	DEBUG = 5,
}

-- Local Log function for Fetcher module (Defined early)
local function Log(level, message, color)
	local isDebugMode = G and G.Menu and G.Menu.Advanced and G.Menu.Advanced.debug == true

	-- Determine if the message should be shown
	local shouldShow = false
	if isDebugMode then
		shouldShow = true -- Show all levels in debug mode
	elseif level <= LogLevel.SUCCESS then
		shouldShow = true -- Show ERROR, WARNING, SUCCESS in non-debug mode
	end

	if not shouldShow then
		return
	end

	local prefix = ""
	local defaultColor = { 255, 255, 255, 255 }

	if level == LogLevel.ERROR then
		prefix = "[FETCHER ERROR] "
		color = color or { 255, 100, 100, 255 } -- Red
	elseif level == LogLevel.WARNING then
		prefix = "[FETCHER WARNING] "
		color = color or { 255, 255, 100, 255 } -- Yellow
	elseif level == LogLevel.SUCCESS then
		prefix = "[FETCHER SUCCESS] "
		color = color or { 0, 255, 140, 255 } -- Bright Green
	elseif level == LogLevel.INFO then
		if not isDebugMode then
			return
		end
		prefix = "[FETCHER INFO] "
		color = color or { 100, 255, 255, 255 } -- Cyan
	elseif level == LogLevel.DEBUG then
		if not isDebugMode then
			return
		end
		prefix = "[FETCHER DEBUG] "
		color = color or { 180, 180, 180, 255 } -- Grey
	end

	color = color or defaultColor
	printc(color[1], color[2], color[3], color[4], prefix .. message)
end

-- Simplified State tracking
Fetcher.State = {
	isRunning = false,
	startTime = 0,
	results = {
		total_added = 0,
		total_updated = 0, -- Keep track of updates
		errors = 0,
	},
}

local function isDatabaseEmpty()
	if type(G) ~= "table" or type(G.DataBase) ~= "table" then
		return true
	end
	return next(G.DataBase) == nil
end

local function isFetchStale()
	local menu = G and G.Menu and G.Menu.Main
	if not menu then
		return true
	end
	local lastFetch = tonumber(menu.LastFetchTimestamp) or 0
	return (os.time() - lastFetch) >= 3600
end

-- Helper function to check if all required modules are properly loaded
local function checkRequirements()
	Log(LogLevel.DEBUG, "[FETCHER] Checking requirements...") -- Use Log
	if type(G) ~= "table" then
		Log(LogLevel.ERROR, "[FETCHER] CRITICAL ERROR: Globals module not loaded properly") -- Use Log
		return false
	end
	if type(G.DataBase) ~= "table" then
		Log(LogLevel.ERROR, "[FETCHER] CRITICAL ERROR: G.DataBase is not initialized") -- Use Log
		return false
	end
	if type(Database) ~= "table" then
		Log(LogLevel.ERROR, "[FETCHER] CRITICAL ERROR: Database module not loaded properly") -- Use Log
		return false
	end
	if type(Database.SaveDatabase) ~= "function" then
		Log(LogLevel.ERROR, "[FETCHER] CRITICAL ERROR: Database.SaveDatabase function missing") -- Use Log
		return false
	end
	if type(Sources) ~= "table" or type(Sources.GetActiveSources) ~= "function" then
		Log(LogLevel.ERROR, "[FETCHER] CRITICAL ERROR: Sources module not loaded properly") -- Use Log
		return false
	end
	if type(Parsers) ~= "table" then
		Log(LogLevel.ERROR, "[FETCHER] CRITICAL ERROR: Parsers module not loaded properly") -- Use Log
		return false
	end
	Log(LogLevel.DEBUG, "[FETCHER] All requirements satisfied") -- Use Log
	return true
end

-- Process a single source and add its entries to the database

local function fetchSource(source)
	Log(LogLevel.INFO, string.format("[FETCHER] Fetching source: %s (%s)", source.name, source.url))

	local fetch_success, response_or_error = pcall(http.Get, source.url)
	if not fetch_success then
		Log(
			LogLevel.WARNING,
			string.format("[FETCHER] Failed to fetch data from %s: %s", source.name, tostring(response_or_error))
		)
		return nil, "fetch_failed"
	end

	if type(response_or_error) ~= "string" or response_or_error == "" then
		Log(LogLevel.WARNING, string.format("[FETCHER] Empty or invalid content from %s", source.name))
		return nil, "empty_response"
	end

	Log(
		LogLevel.DEBUG,
		string.format("[FETCHER] Download successful from %s. Size: %d bytes", source.name, #response_or_error)
	)

	return response_or_error, nil
end

local function parseSource(source, response_content)
	Log(LogLevel.INFO, string.format("[FETCHER] Parsing source: %s", source.name))
	local sourceStats = { processed = 0, added = 0, existing = 0, updated = 0, errors = 0 }
	local added = 0
	local updated = 0
	local isDirtyBefore = Database.State.isDirty

	-- Parsing logic (remains the same)
	if source.parser == "raw" then
		local entries, errorMsg = Parsers.ParseRawIDs(response_content, source.cause)
		if entries then
			local processedCount, existingCount, addedCount, updatedCount = 0, 0, 0, 0
			for steamID64, entryData in pairs(entries) do
				processedCount = processedCount + 1
				if not G.DataBase[steamID64] then
					G.DataBase[steamID64] = entryData
					addedCount = addedCount + 1
				else
					existingCount = existingCount + 1
					local existingEntry = G.DataBase[steamID64]
					if
						(existingEntry.Name == "Unknown" or existingEntry.Name == nil)
						and entryData.Name
						and entryData.Name ~= "Unknown"
					then
						existingEntry.Name = entryData.Name
						updatedCount = updatedCount + 1
						Database.State.isDirty = true
					end
					if
						(existingEntry.Reason == "Unknown Source" or existingEntry.Reason == nil)
						and entryData.Reason
						and entryData.Reason ~= "Unknown Source"
					then
						existingEntry.Reason = entryData.Reason
						updatedCount = updatedCount + 1
						Database.State.isDirty = true
					end
				end
			end
			added = addedCount
			updated = updatedCount
			sourceStats.processed = processedCount
			sourceStats.added = addedCount
			sourceStats.existing = existingCount
			sourceStats.updated = updatedCount
		else
			Log(
				LogLevel.WARNING,
				string.format("[FETCHER] Error parsing %s: %s", source.name, errorMsg or "Unknown error")
			) -- Use Log
			sourceStats.errors = sourceStats.errors + 1
		end
	elseif source.parser == "tf2db" then
		if source.url:find("tf2_bot_detector") and source.url:find("playerlist%.official%.json") then
			local _, errorMsg, stats = Parsers.ParseTF2BotDetector(response_content, source.cause, G.DataBase)
			if stats then
				added, updated = stats.added, stats.updated
				sourceStats = stats
			else
				Log(
					LogLevel.WARNING,
					string.format("[FETCHER] Error parsing %s: %s", source.name, errorMsg or "Unknown error")
				) -- Use Log
				sourceStats.errors = sourceStats.errors + 1
			end
		else
			local data, errorMsg = Parsers.ParseJsonTF2DB(response_content)
			if data and data.players then
				local processedCount, existingCount, addedCount, updatedCount = 0, 0, 0, 0
				for _, player in ipairs(data.players) do
					processedCount = processedCount + 1
					local steamID64 = player.steamid and Parsers.GetSteamID64(player.steamid) or nil
					if steamID64 then
						local playerName = (player.last_seen and player.last_seen.player_name) or "Unknown"
						local reason = source.cause or "Unknown Source"
						if player.attributes and #player.attributes > 0 then
							reason = player.attributes[1]:gsub("^%l", string.upper)
						end
						if not G.DataBase[steamID64] then
							G.DataBase[steamID64] = { Name = playerName, Reason = reason }
							addedCount = addedCount + 1
						else
							existingCount = existingCount + 1
							local existingEntry = G.DataBase[steamID64]
							if
								(existingEntry.Name == "Unknown" or existingEntry.Name == nil)
								and playerName
								and playerName ~= "Unknown"
							then
								existingEntry.Name = playerName
								updatedCount = updatedCount + 1
								Database.State.isDirty = true
							end
							if reason and reason ~= "Unknown Source" then
								local existingReason = existingEntry.Reason
								if not existingReason or existingReason == "Unknown Source" then
									existingEntry.Reason = reason
									updatedCount = updatedCount + 1
									Database.State.isDirty = true
								elseif existingReason ~= reason and not existingReason:find(reason, 1, true) then
									existingEntry.Reason = existingReason .. " | " .. reason
									updatedCount = updatedCount + 1
									Database.State.isDirty = true
								end
							end
						end
					else
						sourceStats.errors = sourceStats.errors + 1
					end
				end
				added = addedCount
				updated = updatedCount
				sourceStats.processed = processedCount
				sourceStats.added = addedCount
				sourceStats.existing = existingCount
				sourceStats.updated = updatedCount
			else
				Log(
					LogLevel.WARNING,
					string.format("[FETCHER] Error parsing %s: %s", source.name, errorMsg or "Unknown error")
				) -- Use Log
				sourceStats.errors = sourceStats.errors + 1
			end
		end
	else
		Log( -- Use Log
			LogLevel.ERROR,
			string.format("[FETCHER] Error: Unknown parser type '%s' for source %s", source.parser, source.name)
		)
		return 0, 0, 1 -- added, updated, errors
	end

	Parsers.AddSourceStats(
		source.name,
		sourceStats.processed,
		sourceStats.added,
		sourceStats.existing,
		sourceStats.errors,
		sourceStats.updated
	)

	if (added > 0 or updated > 0) and not isDirtyBefore then
		Database.State.isDirty = true
	end

	if updated > 0 then
		Log(LogLevel.DEBUG, string.format("[FETCHER] %s: Added %d, Updated %d", source.name, added, updated)) -- Debug level
	elseif added > 0 then
		Log(LogLevel.DEBUG, string.format("[FETCHER] %s: Added %d", source.name, added)) -- Debug level
	else
		Log(LogLevel.DEBUG, string.format("[FETCHER] %s: No changes", source.name)) -- Debug level
	end

	return added, updated, sourceStats.errors
end

-- Public Module Functions
function Fetcher.Start()
	Log(LogLevel.INFO, "[FETCHER] Starting SYNC database fetch process") -- Use Log

	if Fetcher.State.isRunning then
		Log(LogLevel.WARNING, "[FETCHER] Fetch process already running, ignoring request") -- Use Log
		return
	end

	if not checkRequirements() then
		Log(LogLevel.ERROR, "[FETCHER] Requirements check failed, aborting fetch") -- Use Log
		return
	end

	Parsers.ResetStats()

	Fetcher.State.isRunning = true
	Fetcher.State.startTime = globals.RealTime()
	Fetcher.State.results.total_added = 0
	Fetcher.State.results.total_updated = 0
	Fetcher.State.results.errors = 0

	local active_sources = Sources.GetActiveSources()
	Log(LogLevel.INFO, string.format("[FETCHER] Found %d active sources", #active_sources)) -- Use Log

	if #active_sources == 0 then
		Log(LogLevel.INFO, "[FETCHER] No active sources found, finishing immediately.") -- Use Log
		Fetcher.FinishFetch()
		return
	end

	local fetchedResponses = {}

	for i, source in ipairs(active_sources) do
		Log(
			LogLevel.DEBUG,
			string.format("[FETCHER] [Pass 1] Fetching source %d/%d: %s", i, #active_sources, source.name)
		)
		local response_content = nil
		response_content = select(1, fetchSource(source))
		if response_content then
			table.insert(fetchedResponses, { source = source, response = response_content })
		else
			Fetcher.State.results.errors = Fetcher.State.results.errors + 1
			Parsers.AddSourceStats(source.name, 0, 0, 0, 1, 0)
		end
	end

	for index, payload in ipairs(fetchedResponses) do
		Log(
			LogLevel.DEBUG,
			string.format("[FETCHER] [Pass 2] Parsing source %d/%d: %s", index, #fetchedResponses, payload.source.name)
		)
		local added, updated, errors = parseSource(payload.source, payload.response)
		Fetcher.State.results.total_added = Fetcher.State.results.total_added + added
		Fetcher.State.results.total_updated = Fetcher.State.results.total_updated + updated
		Fetcher.State.results.errors = Fetcher.State.results.errors + errors
	end

	-- Fetch completed, call FinishFetch directly
	Fetcher.FinishFetch()
end

function Fetcher.FinishFetch()
	if not Fetcher.State.isRunning then
		return
	end

	local elapsedTime = globals.RealTime() - Fetcher.State.startTime

	-- Only show detailed debug output in debug mode (via Parsers.PrintStatsSummary)
	local isDebugMode = G and G.Menu and G.Menu.Advanced and G.Menu.Advanced.debug == true
	if isDebugMode then
		-- Log the full details only in debug mode
		Log(
			LogLevel.INFO,
			string.format(
				"SYNC Fetch completed in %.2f seconds. Total Added: %d, Total Updated: %d, Errors: %d",
				elapsedTime,
				Fetcher.State.results.total_added,
				Fetcher.State.results.total_updated,
				Fetcher.State.results.errors
			)
		)

		-- Show detailed stats in debug mode
		Parsers.PrintStatsSummary()
	else
		-- User-friendly output with color coding and separate lines for key metrics
		-- Always show processed and added counts in green
		printc(0, 255, 140, 255, string.format("Database entries processed: %d", Parsers.ParseStats.totalProcessed))
		printc(0, 255, 140, 255, string.format("Database entries added: %d", Parsers.ParseStats.totalAdded))

		-- Only show errors if there are any (in red)
		if Parsers.ParseStats.totalErrors > 0 then
			printc(255, 100, 100, 255, string.format("Database errors: %d", Parsers.ParseStats.totalErrors))
		end

		-- Show database entry count in green
		local dbCount = 0
		if type(G.DataBase) == "table" then
			for _ in pairs(G.DataBase) do
				dbCount = dbCount + 1
			end
		end
		printc(0, 255, 140, 255, string.format("Total database entries: %d", dbCount))
	end

	if Database.State.isDirty then
		Log(LogLevel.INFO, "Changes detected, saving database")
		Database.SaveDatabase()
	else
		Log(LogLevel.INFO, "No changes detected, skipping database save")
	end

	local mainMenu = G and G.Menu and G.Menu.Main
	if mainMenu then
		mainMenu.LastFetchTimestamp = os.time()
	end

	Fetcher.State.isRunning = false
	Log(LogLevel.DEBUG, "Fetch process finished")
end

function Fetcher.GetStatus()
	return {
		running = Fetcher.State.isRunning,
	}
end

-- InitializeFetcher removed (Manual fetch only)
-- local function InitializeFetcher() ... end
-- InitializeFetcher()

Log(LogLevel.DEBUG, "[FETCHER] >>> Module execution finished. Returning Fetcher table.") -- Use Log (Debug)
return Fetcher

end)
__bundle_register("Cheater_Detection.Database.Parsers", function(require, _LOADED, __bundle_register, __bundle_modules)
local Common = require("Cheater_Detection.Utils.Common")
-- [[ Imported by: Fetcher.lua (indirectly) ]]
local Json = Common.Json
-- [[ Imported by: Parsers.lua ]]

local G = require("Cheater_Detection.Utils.Globals")
-- [[ Imported by: Fetcher.lua, Parsers.lua ]]

local Parsers = {}

-- Stats tracking for parser operations
Parsers.ParseStats = {
	sources = {},
	totalProcessed = 0,
	totalAdded = 0,
	totalExisting = 0,
	totalErrors = 0,
	totalUpdated = 0,
}

-- Reset stats for a new parsing session
function Parsers.ResetStats()
	Parsers.ParseStats = {
		sources = {},
		totalProcessed = 0,
		totalAdded = 0,
		totalExisting = 0,
		totalErrors = 0,
		totalUpdated = 0,
	}
end

-- Add stats for a source
function Parsers.AddSourceStats(sourceName, processed, added, existing, errors, updated)
	Parsers.ParseStats.sources[sourceName] = {
		processed = processed or 0,
		added = added or 0,
		existing = existing or 0,
		errors = errors or 0,
		updated = updated or 0,
	}

	-- Update totals
	Parsers.ParseStats.totalProcessed = Parsers.ParseStats.totalProcessed + processed
	Parsers.ParseStats.totalAdded = Parsers.ParseStats.totalAdded + added
	Parsers.ParseStats.totalExisting = Parsers.ParseStats.totalExisting + existing
	Parsers.ParseStats.totalErrors = Parsers.ParseStats.totalErrors + errors
	-- Add updating to totals if it exists
	Parsers.ParseStats.totalUpdated = (Parsers.ParseStats.totalUpdated or 0) + (updated or 0)
end

-- Get a formatted summary of all parsing statistics
function Parsers.GetStatsSummary()
	local summary = "[PARSE STATS SUMMARY]\n"

	-- Add per-source stats
	for sourceName, stats in pairs(Parsers.ParseStats.sources) do
		-- Check if source has any updates to report
		local updatesInfo = ""
		if stats.updated and stats.updated > 0 then
			updatesInfo = string.format(", Updated: %d", stats.updated)
		end

		summary = summary
			.. string.format(
				"[Source: %s] Processed: %d, Added: %d, Already Exists: %d%s, Errors: %d\n",
				sourceName,
				stats.processed,
				stats.added,
				stats.existing,
				updatesInfo,
				stats.errors
			)
	end

	-- Calculate total updates
	local totalUpdated = 0
	for _, stats in pairs(Parsers.ParseStats.sources) do
		totalUpdated = totalUpdated + (stats.updated or 0)
	end

	-- Add total stats with updates info
	local totalUpdatesInfo = ""
	if totalUpdated > 0 then
		totalUpdatesInfo = string.format(", Updated: %d", totalUpdated)
	end

	summary = summary
		.. string.format(
			"[TOTAL] Processed: %d, Added: %d, Already Exists: %d%s, Errors: %d",
			Parsers.ParseStats.totalProcessed,
			Parsers.ParseStats.totalAdded,
			Parsers.ParseStats.totalExisting,
			totalUpdatesInfo,
			Parsers.ParseStats.totalErrors
		)

	return summary
end

-- Formats and prints a statistics bundle for all parsing operations
--[[ DEPRECATED: Printing is now handled by Fetcher using GetStatsSummary and Database.Log
function Parsers.PrintStatsSummary()
	print(Parsers.GetStatsSummary())
end
]]
-- Restore the function
function Parsers.PrintStatsSummary()
	local isDebugMode = G and G.Menu and G.Menu.Advanced and G.Menu.Advanced.debug == true
	-- Only print the summary if in debug mode
	if isDebugMode then
		local summary = Parsers.GetStatsSummary()
		if summary then
			print(summary) -- Keep using plain print for multi-line debug summary
		end
	end
end

-- Robust SteamID conversion function (moved from Fetcher)
-- Handles SteamID64, SteamID3 ([U:1:xxxx]), SteamID2 (STEAM_0:x:xxxx)
function Parsers.GetSteamID64(input)
	if not input then
		return nil
	end

	local id_str = tostring(input):match("^%s*(.-)%s*$") -- Trim
	if not id_str then
		return nil
	end

	-- 1. Check if it's a plain numeric ID that's in the valid SteamID64 range
	if id_str:match("^%d+$") then
		local num = tonumber(id_str)
		if num and num >= 76500000000000000 and num <= 77000000000000000 then
			return id_str
		end
	end

	-- 2. Validate against standard SteamID64 format
	if id_str:match("^7656119%d+$") and string.len(id_str) >= 17 then
		return id_str
	end

	-- 3. Try conversion using built-in function (handles SteamID2, SteamID3)
	local steamID64_from_pcall = nil
	if steam and steam.ToSteamID64 then -- Ensure steam API is available
		local success, result = pcall(steam.ToSteamID64, id_str)

		-- Check if pcall succeeded AND the result is usable (string or number)
		local result_str = nil
		if success and result then
			-- Convert to string if necessary
			if type(result) == "number" then
				result_str = tostring(result)
			elseif type(result) == "string" then
				result_str = result
			end

			-- If we got a usable string, trim and validate it
			if result_str then
				local trimmed_result = result_str:match("^%s*(.-)%s*$")

				-- Check if this is a valid SteamID64 by numeric range instead of strict pattern
				if trimmed_result and trimmed_result:match("^%d+$") then
					local num = tonumber(trimmed_result)
					if num and num >= 76561197960265728 and num <= 77000000000000000 then -- Corrected range
						return trimmed_result
					end
				end
			end
		else
			-- Debug print statement removed
			-- Log(LogLevel.DEBUG, "[PARSERS] steam API or steam.ToSteamID64 not available for conversion attempt")
		end
	else
		-- Debug print statement removed
		-- Log(LogLevel.DEBUG, "[PARSERS] steam API or steam.ToSteamID64 not available for conversion attempt")
	end

	-- If conversion via pcall was successful, return that result
	if steamID64_from_pcall then
		return steamID64_from_pcall
	end

	-- 4. Manual fallback for SteamID3 (only if steps 1 & 2 failed)
	local accountID = id_str:match("%[U:1:(%d+)%]")
	if accountID then
		accountID = tonumber(accountID)
		if accountID then
			local steamID64 = tostring(76561197960265728 + accountID)
			return steamID64
		end
	end

	-- 5. All attempts failed
	return nil
end

-- Parses a JSON string (specifically bots.tf format expected)
-- Returns: { players = { { steamid="...", attributes={...}, last_seen={player_name="..."} }, ... } } or nil, errorMsg
function Parsers.ParseJsonTF2DB(contentString)
	if not contentString or contentString == "" then
		return nil, "Empty content string"
	end

	-- Ensure the JSON decoder is available before calling pcall
	if not Json or type(Json.decode) ~= "function" then
		return nil, "JSON decode function is unavailable"
	end

	local success, data = pcall(Json.decode, contentString)

	if not success or type(data) ~= "table" then
		return nil, "JSON decode failed: " .. tostring(data)
	end

	if not data.players or type(data.players) ~= "table" then
		-- Allow if the root object itself is the list of players
		if type(data) == "table" and #data > 0 and type(data[1]) == "table" and data[1].steamid then
			return { players = data }, nil -- Wrap it for consistency
		end
		return nil, "JSON missing 'players' array"
	end

	return data, nil
end

-- Parses a single line from a raw list
-- Returns: steamID64 string or nil
function Parsers.ParseRawLine(lineString)
	if not lineString then
		return nil
	end

	local trimmedLine = lineString:match("^%s*(.-)%s*$") or ""

	-- Skip comments, empty lines
	if trimmedLine == "" or trimmedLine:match("^%-%-") or trimmedLine:match("^#") or trimmedLine:match("^//") then
		return nil
	end

	-- Attempt to get SteamID64
	local steamID64 = Parsers.GetSteamID64(trimmedLine)
	return steamID64
end

-- Parses a raw text file containing one SteamID per line
-- Returns: { [steamId64] = { Name="Unknown", Reason=cause }, ... } or nil, errorMsg
function Parsers.ParseRawIDs(contentString, cause)
	local entries = {}
	if not contentString or contentString == "" then
		return entries -- Return empty table, not an error
	end

	local default_reason = cause or "Unknown Source"
	local lineCount = 0
	local addedCount = 0

	-- Iterate over each line in the content string
	for line in contentString:gmatch("[^\n\r]+") do
		lineCount = lineCount + 1
		local steamID64 = Parsers.ParseRawLine(line)
		if steamID64 then
			if not entries[steamID64] then -- Avoid duplicates within the same file
				entries[steamID64] = {
					Name = "Unknown", -- Raw lists usually don't have names
					Reason = default_reason,
				}
				addedCount = addedCount + 1
			end
		end
	end

	return entries, nil -- Return the table of entries
end

-- Parse TF2 Bot Detector JSON format and convert to our database format
-- Returns: { [steamid64] = { Name="...", Reason="..." }, ... } or nil, errorMsg
function Parsers.ParseTF2BotDetector(contentString, defaultReason, existingEntries, sourceStats)
	if not contentString or contentString == "" then
		if sourceStats then
			sourceStats.errors = (sourceStats.errors or 0) + 1
		end
		return nil, "Empty content string"
	end

	local entries = existingEntries or {}
	local stats = {
		processed = 0,
		added = 0,
		existing = 0,
		updated = 0, -- New field to track updated entries
		errors = 0,
	}

	-- Try to decode JSON
	-- Ensure the JSON decoder is available before calling pcall
	if not Json or type(Json.decode) ~= "function" then
		if sourceStats then
			sourceStats.errors = (sourceStats.errors or 0) + 1
		end
		return nil, "JSON decode function is unavailable"
	end

	local success, data = pcall(Json.decode, contentString)

	if not success or type(data) ~= "table" then
		if sourceStats then
			sourceStats.errors = (sourceStats.errors or 0) + 1
		end
		return nil, "JSON decode failed: " .. tostring(data)
	end

	-- Find the players array
	local players = data.players
	if not players then
		if sourceStats then
			sourceStats.errors = (sourceStats.errors or 0) + 1
		end
		return nil, "JSON missing 'players' array"
	end

	-- Process each player
	for _, player in ipairs(players) do
		stats.processed = stats.processed + 1

		-- Get the SteamID and convert to SteamID64
		local steamID64 = Parsers.GetSteamID64(player.steamid)
		if steamID64 then
			-- Determine player name (from last_seen if available)
			local playerName = "Unknown"
			if player.last_seen and player.last_seen.player_name then
				playerName = player.last_seen.player_name
			end

			-- Get the first attribute as the reason
			local reason = defaultReason or "Unknown Source"
			if player.attributes and #player.attributes > 0 then
				-- Use first attribute, capitalized
				local firstAttribute = player.attributes[1]
				reason = firstAttribute:gsub("^%l", string.upper) -- Capitalize first letter

				-- Only use default reason if no attributes available
				-- NOT overriding attribute with defaultReason anymore
			end

			-- Add to entries if not already there
			if entries[steamID64] then
				stats.existing = stats.existing + 1

				-- "Stealer mode" - Update entry if it has better information
				local existingEntry = entries[steamID64]
				local updated = false

				-- If existing entry has unknown name and this one has a name
				if
					(existingEntry.Name == "Unknown" or existingEntry.Name == nil)
					and playerName
					and playerName ~= "Unknown"
				then
					existingEntry.Name = playerName
					updated = true
				end

				-- If existing entry has unknown reason and this one has a reason
				if
					(existingEntry.Reason == "Unknown Source" or existingEntry.Reason == nil)
					and reason
					and reason ~= "Unknown Source"
				then
					existingEntry.Reason = reason
					updated = true
				end

				-- Increment update counter if we made changes
				if updated then
					stats.updated = stats.updated + 1
				end
			else
				entries[steamID64] = {
					Name = playerName,
					Reason = reason,
				}
				stats.added = stats.added + 1
			end
		else
			stats.errors = stats.errors + 1
		end
	end

	-- Update source stats if provided
	if sourceStats then
		sourceStats.processed = (sourceStats.processed or 0) + stats.processed
		sourceStats.added = (sourceStats.added or 0) + stats.added
		sourceStats.existing = (sourceStats.existing or 0) + stats.existing
		sourceStats.updated = (sourceStats.updated or 0) + stats.updated
		sourceStats.errors = (sourceStats.errors or 0) + stats.errors
	end

	return entries, nil, stats
end

return Parsers

end)
__bundle_register("Cheater_Detection.Utils.EventManager", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ EventManager.lua - Centralized event handling ]]
--
-- Manages all game events with single callback registration per event type.
-- Allows multiple handlers per event without redundant hook overhead.

local EventManager = {}

-- Handler storage: [eventType][handlerName] = { filter = "event_name", callback = function }
local handlers = {
	CreateMove = {},
	Draw = {},
	FireGameEvent = {},
	DispatchUserMessage = {},
	Unload = {},
}

-- Registered callback names for cleanup
local registeredCallbacks = {}

--[[ Private Functions ]]

-- Dispatcher for FireGameEvent (filters by event name)
local function dispatchFireGameEvent(event)
	local eventName = event:GetName()
	for _, handler in pairs(handlers.FireGameEvent) do
		if not handler.filter or handler.filter == eventName or handler.filter == "*" then
			local success, err = pcall(handler.callback, event)
			if not success then
				print(string.format("[EventManager] Error in FireGameEvent handler: %s", err))
			end
		end
	end
end

-- Generic dispatcher (no filtering)
local function dispatchGeneric(eventType, ...)
	for _, handler in pairs(handlers[eventType]) do
		local success, err = pcall(handler.callback, ...)
		if not success then
			print(string.format("[EventManager] Error in %s handler: %s", eventType, err))
		end
	end
end

--[[ Public API ]]

--- Register a handler for an event
---@param eventType string Event type: "CreateMove", "Draw", "FireGameEvent", etc.
---@param handlerName string Unique handler name (e.g., "Database_MapChange")
---@param callback function Handler function
---@param filter string? Optional event name filter (for FireGameEvent only)
function EventManager.Register(eventType, handlerName, callback, filter)
	if not handlers[eventType] then
		print(string.format("[EventManager] Unknown event type: %s", eventType))
		return false
	end

	-- Store handler
	handlers[eventType][handlerName] = {
		callback = callback,
		filter = filter,
	}

	-- Register actual callback if not already registered
	if not registeredCallbacks[eventType] then
		local callbackName = "CD_EventManager_" .. eventType

		-- Unregister old callback if exists
		callbacks.Unregister(eventType, callbackName)

		-- Register new callback with dispatcher
		if eventType == "FireGameEvent" then
			callbacks.Register(eventType, callbackName, dispatchFireGameEvent)
		else
			callbacks.Register(eventType, callbackName, function(...)
				dispatchGeneric(eventType, ...)
			end)
		end

		registeredCallbacks[eventType] = callbackName
	end

	return true
end

--- Unregister a handler
---@param eventType string Event type
---@param handlerName string Handler name to remove
function EventManager.Unregister(eventType, handlerName)
	if handlers[eventType] then
		handlers[eventType][handlerName] = nil
	end
end

--- Get count of registered handlers for debugging
---@param eventType string? Optional event type, nil = all types
---@return number|table Count or table of counts
function EventManager.GetHandlerCount(eventType)
	if eventType then
		local count = 0
		for _ in pairs(handlers[eventType] or {}) do
			count = count + 1
		end
		return count
	else
		local counts = {}
		for evType, handlerList in pairs(handlers) do
			local count = 0
			for _ in pairs(handlerList) do
				count = count + 1
			end
			counts[evType] = count
		end
		return counts
	end
end

-- NOTE: No cleanup needed on Unload.
-- Lmaobox automatically cleans up all callbacks when the script unloads.
-- Calling callbacks.Unregister() during Unload causes crashes.

return EventManager

end)
__bundle_register("Cheater_Detection.Utils.Config", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[ Imports ]]
local G = require("Cheater_Detection.Utils.Globals")
local Common = require("Cheater_Detection.Utils.Common")
local Default_Config = require("Cheater_Detection.Utils.DefaultConfig")

local Config = {}

--[[ Constants ]]
local Lua__fullPath = GetScriptName()
local Lua__fileName = Lua__fullPath:match("([^/\\]+)%.lua$"):gsub("%.lua$", "")
local folder_name = string.format([[Lua %s]], Lua__fileName)

--[[ Config Path Helper ]]
-- Build full path once from script name
local function GetConfigPath()
	local _, fullPath = filesystem.CreateDirectory(folder_name) -- succeeds even if already exists
	local sep = package.config:sub(1, 1) -- Get OS path separator
	return fullPath .. sep .. "config.cfg"
end

--[[ Serialize a Lua table (readable output, ordered by iteration) ]]
local function serializeTable(tbl, level)
	level = level or 0
	local indent = string.rep("    ", level)
	local out = indent .. "{\n"
	for k, v in pairs(tbl) do
		local keyRepr = (type(k) == "string") and string.format('["%s"]', k) or string.format("[%s]", k)
		out = out .. indent .. "    " .. keyRepr .. " = "
		if type(v) == "table" then
			out = out .. serializeTable(v, level + 1) .. ",\n"
		elseif type(v) == "string" then
			out = out .. string.format('"%s",\n', v)
		else
			out = out .. tostring(v) .. ",\n"
		end
	end
	out = out .. indent .. "}"
	return out
end

--[[ Recursive key presence check (ensures loaded config has all required keys) ]]
local function keysMatch(template, loaded)
	for k, v in pairs(template) do
		if loaded[k] == nil then
			return false
		end
		if type(v) == "table" and type(loaded[k]) == "table" then
			if not keysMatch(v, loaded[k]) then
				return false
			end
		end
	end
	return true
end

--[[ Deep copy table (for default initialization) ]]
local function deepCopy(orig)
	if type(orig) ~= "table" then
		return orig
	end
	local copy = {}
	for k, v in pairs(orig) do
		copy[k] = deepCopy(v)
	end
	return copy
end

--[[ Ensure all Menu settings have defaults (handles partial configs) ]]
local function SafeInitMenu()
	if not G.Menu then
		G.Menu = deepCopy(Default_Config)
		return
	end

	-- Helper to ensure a field exists with default value
	local function ensureField(parent, key, default)
		if parent[key] == nil then
			parent[key] = deepCopy(default)
		elseif type(default) == "table" and type(parent[key]) == "table" then
			-- Recursively ensure nested tables
			for k, v in pairs(default) do
				ensureField(parent[key], k, v)
			end
		end
	end

	-- Ensure all top-level and nested fields exist
	for key, value in pairs(Default_Config) do
		ensureField(G.Menu, key, value)
	end
end

--[[ Save config to file ]]
function Config.CreateCFG(cfgTable)
	cfgTable = cfgTable or G.Menu or Default_Config
	local path = GetConfigPath()

	local file = io.open(path, "w")
	if not file then
		printc(255, 0, 0, 255, "[Config] Failed to write: " .. path)
		return false
	end

	file:write(serializeTable(cfgTable))
	file:close()
	printc(100, 183, 0, 255, "[Config] Saved: " .. path)
	return true
end

--[[ Load config; regenerate if invalid/outdated/SHIFT bypass ]]
function Config.LoadCFG()
	local path = GetConfigPath()
	local file = io.open(path, "r")

	if not file then
		-- First run – make directory & default cfg
		printc(255, 200, 100, 255, "[Config] No config found, creating default...")
		G.Menu = deepCopy(Default_Config)
		Config.CreateCFG(G.Menu)
		SafeInitMenu()
		return G.Menu
	end

	local content = file:read("*a")
	file:close()

	-- Parse as Lua table
	local chunk, err = load("return " .. content)
	if not chunk then
		printc(255, 100, 100, 255, "[Config] Compile error, regenerating: " .. tostring(err))
		G.Menu = deepCopy(Default_Config)
		Config.CreateCFG(G.Menu)
		SafeInitMenu()
		return G.Menu
	end

	local ok, cfg = pcall(chunk)

	-- Validate: Must be table, keys must match, SHIFT bypass for reset
	local shiftHeld = input.IsButtonDown(KEY_LSHIFT)
	if not ok or type(cfg) ~= "table" or not keysMatch(Default_Config, cfg) or shiftHeld then
		if shiftHeld then
			printc(255, 200, 100, 255, "[Config] SHIFT held – regenerating config...")
		else
			printc(255, 100, 100, 255, "[Config] Invalid or outdated config – regenerating...")
		end
		G.Menu = deepCopy(Default_Config)
		Config.CreateCFG(G.Menu)
		SafeInitMenu()
		return G.Menu
	end

	-- Success
	printc(0, 255, 140, 255, "[Config] Loaded: " .. path)
	G.Menu = cfg
	SafeInitMenu() -- Ensure any new fields from Default_Config are added
	return G.Menu
end

--[[ Get filepath (public API) ]]
function Config.GetFilePath()
	return GetConfigPath()
end

--[[ Auto-load config on require ]]
Config.LoadCFG()

-- Set G.Config with key settings for other modules
G.Config = G.Config or {}
G.Config.AutoFetch = G.Menu and G.Menu.Main and G.Menu.Main.AutoFetch or true

--[[ Save configuration automatically when the script unloads ]]
local function ConfigAutoSaveOnUnload()
	print("[CONFIG] Unloading script, saving configuration...")

	-- Safety check
	if not G or not G.Menu then
		print("[CONFIG] Warning: G.Menu is nil, cannot save config")
		return
	end

	-- Use the same serializer (it's self-contained, no GC issues)
	local success, result = pcall(function()
		local path = GetConfigPath()
		local file = io.open(path, "w")
		if file then
			file:write(serializeTable(G.Menu))
			file:close()
			print("[CONFIG] Config saved successfully to: " .. path)
			return true
		else
			print("[CONFIG] ERROR: Cannot open file for writing: " .. tostring(path))
			return false
		end
	end)

	if not success then
		print("[CONFIG] ERROR during save: " .. tostring(result))
	end
end

callbacks.Register("Unload", "ConfigAutoSaveOnUnload", ConfigAutoSaveOnUnload)

return Config

end)
return __bundle_require("__root")