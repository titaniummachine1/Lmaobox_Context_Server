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
local GameConstants = require("constants.game_constants")
local MovementSim = require("simulation.Player.movement_sim")
local WishdirEstimator = require("simulation.Player.wishdir_estimator")
local StrafePrediction = require("simulation.Player.strafe_prediction")
local StrafeRotation = require("simulation.Player.strafe_rotation")
local PlayerSimState = require("simulation.Player.player_sim_state")
local WishdirDebug = require("simulation.Player.wishdir_debug")

local consolas = draw.CreateFont("Consolas", 17, 500)

local MAX_PREDICTION_TICKS = 66
local MIN_STRAFE_SAMPLES = 6

local state = {
	enabled = true,
	showWishdirDebug = true,
	predictions = {},
	lastUpdateTime = 0,
	updateInterval = 0.1,
	wishdirDebugResults = nil,
}

local function getLocalPlayer()
	local ply = entities.GetLocalPlayer()
	if not ply or not ply:IsAlive() then
		return nil
	end
	return ply
end

local function simulatePlayerPath(entity, useStrafePred)
	local predictions = {}

	local playerState = PlayerSimState.getOrCreate(entity)
	if not playerState then
		return predictions
	end

	local sim = PlayerSimState.getSimContext()

	local vel = entity:EstimateAbsVelocity()
	if vel then
		local estimatedWishdir = WishdirEstimator.estimateFromVelocity(vel, playerState.yaw)
		playerState.relativeWishDir = estimatedWishdir
	else
		playerState.relativeWishDir = { x = 0, y = 0, z = 0 }
	end

	local avgYawDelta = 0
	if useStrafePred then
		local maxSpeed = vel and vel:Length2D() or 320
		if maxSpeed < 10 then
			maxSpeed = 320
		end
		avgYawDelta = StrafePrediction.calculateAverageYaw(entity:GetIndex(), maxSpeed, MIN_STRAFE_SAMPLES) or 0
	end
	playerState.yawDeltaPerTick = avgYawDelta

	if avgYawDelta and math.abs(avgYawDelta) > 0.001 then
		StrafeRotation.initState(entity:GetIndex(), playerState.yaw, avgYawDelta)
	end

	table.insert(
		predictions,
		{ x = playerState.origin.x, y = playerState.origin.y, z = playerState.origin.z, tick = 0 }
	)

	for tick = 1, MAX_PREDICTION_TICKS do
		MovementSim.simulateTick(playerState, sim)
		table.insert(
			predictions,
			{ x = playerState.origin.x, y = playerState.origin.y, z = playerState.origin.z, tick = tick }
		)
	end

	return predictions
end

local function recordMovementHistory(entity)
	if not entity or not entity:IsValid() or not entity:IsAlive() then
		return
	end
	local origin = entity:GetAbsOrigin()
	local velocity = entity:EstimateAbsVelocity()
	if not origin or not velocity then
		return
	end
	local flags = entity:GetPropInt("m_fFlags") or 0
	local isOnGround = (flags & GameConstants.FL_ONGROUND) ~= 0
	local mode = isOnGround and 0 or 1
	StrafePrediction.recordMovement(entity:GetIndex(), origin, velocity, mode, globals.CurTime(), velocity:Length2D())
end

local function updatePredictions()
	local currentTime = globals.RealTime()
	if currentTime - state.lastUpdateTime < state.updateInterval then
		return
	end
	state.lastUpdateTime = currentTime

	local plocal = getLocalPlayer()
	if plocal then
		recordMovementHistory(plocal)
		state.predictions = simulatePlayerPath(plocal, true)
	else
		state.predictions = {}
	end
end

local function update9DirectionDebug(entity)
	if not state.showWishdirDebug or not entity then
		return
	end
	local playerState = PlayerSimState.getOrCreate(entity)
	local sim = PlayerSimState.getSimContext()
	if not playerState or not sim then
		return
	end
	-- Use new update function: finds best match from last tick, sims 9 new, stores for next tick
	state.wishdirDebugResults = WishdirDebug.update(entity, playerState, sim)
end

local function drawPath(path, r, g, b, a, thickness)
	if not path or #path < 2 then
		return
	end
	thickness = thickness or 2
	local step = math.max(1, math.floor(#path / 50))
	for i = 1, #path - step, step do
		local p1 = path[i]
		local p2 = path[math.min(i + step, #path)]
		local w2s1 = client.WorldToScreen(Vector3(p1.x, p1.y, p1.z))
		local w2s2 = client.WorldToScreen(Vector3(p2.x, p2.y, p2.z))
		if w2s1 and w2s2 then
			local progress = i / #path
			local alpha = math.floor(a * (1 - progress * 0.5))
			draw.Color(r, g, b, alpha)
			for offset = -thickness, thickness do
				draw.Line(w2s1[1] + offset, w2s1[2], w2s2[1] + offset, w2s2[2])
				draw.Line(w2s1[1], w2s1[2] + offset, w2s2[1], w2s2[2] + offset)
			end
		end
	end
	local lastPred = path[#path]
	local w2sLast = client.WorldToScreen(Vector3(lastPred.x, lastPred.y, lastPred.z))
	if w2sLast then
		draw.Color(r, g, b, a)
		local size = 4
		draw.FilledRect(w2sLast[1] - size, w2sLast[2] - size, w2sLast[1] + size, w2sLast[2] + size)
		draw.Color(0, 0, 0, a)
		draw.OutlinedRect(w2sLast[1] - size, w2sLast[2] - size, w2sLast[1] + size, w2sLast[2] + size)
	end
end

local function onCreateMove()
	if not state.enabled then
		return
	end
	updatePredictions()
	local plocal = getLocalPlayer()
	if plocal then
		update9DirectionDebug(plocal)
	end
end

local function onDraw()
	if not state.enabled then
		return
	end
	if state.predictions and #state.predictions > 0 then
		drawPath(state.predictions, 100, 200, 255, 200, 2)
	end
	local plocal = getLocalPlayer()
	if state.showWishdirDebug and plocal and state.wishdirDebugResults then
		local sim = PlayerSimState.getSimContext()
		if sim then
			WishdirDebug.draw9Directions(plocal, state.wishdirDebugResults, sim.tickinterval)
		end
	end
	draw.Color(255, 255, 255, 255)
	draw.SetFont(consolas)
	draw.Text(10, 10, "SimTest - Local Player Only")
	plocal = getLocalPlayer()
	if plocal then
		draw.Text(10, 30, "Predictions: " .. #state.predictions)
		if state.showWishdirDebug then
			draw.Text(10, 50, "9-Dir Debug: ON")
		end
	else
		draw.Text(10, 30, "No local player")
	end
end

callbacks.Register("CreateMove", "simtest_createmove", onCreateMove)
callbacks.Register("Draw", "simtest_draw", onDraw)
printc(100, 255, 100, 255, "[SimTest] Local player simulation loaded")

end)
__bundle_register("simulation.Player.wishdir_debug", function(require, _LOADED, __bundle_register, __bundle_modules)
local GameConstants = require("constants.game_constants")
local MovementSim = require("simulation.Player.movement_sim")

local WishdirDebug = {}

local LINE_LENGTH = 15
local MAX_INPUT = 450

local DIRECTIONS = {
	{ name = "F", dir = { 1, 0 }, angle = 0 },
	{ name = "FR", dir = { 0.707, -0.707 }, angle = 45 },
	{ name = "R", dir = { 0, -1 }, angle = 90 },
	{ name = "BR", dir = { -0.707, -0.707 }, angle = 135 },
	{ name = "B", dir = { -1, 0 }, angle = 180 },
	{ name = "BL", dir = { -0.707, 0.707 }, angle = 225 },
	{ name = "L", dir = { 0, 1 }, angle = 270 },
	{ name = "FL", dir = { 0.707, 0.707 }, angle = 315 },
	{ name = "C", dir = { 0, 0 }, angle = nil },
}

-- Store last tick's simulations for comparison
local lastTickResults = {}

local function dirToRawWishdir(dirInfo)
	local d = dirInfo.dir
	if dirInfo.name == "C" then
		return { x = 0, y = 0, z = 0 }
	else
		return { x = d[1] * MAX_INPUT, y = d[2] * MAX_INPUT, z = 0 }
	end
end

local function getVelocityYaw(velocity)
	return math.atan(velocity.y, velocity.x) * (180 / math.pi)
end

---Simulate one tick with specific wishdir
function WishdirDebug.simulateDirection(state, simCtx, relDir)
	local testState = {
		origin = { x = state.origin.x, y = state.origin.y, z = state.origin.z },
		velocity = { x = state.velocity.x, y = state.velocity.y, z = state.velocity.z },
		yaw = state.yaw,
		mins = state.mins,
		maxs = state.maxs,
		index = state.index,
		maxspeed = state.maxspeed,
		relativeWishDir = { x = relDir.x, y = relDir.y, z = 0 },
		onGround = state.onGround,
	}

	MovementSim.simulateTick(testState, simCtx)

	return {
		origin = testState.origin,
		velocity = testState.velocity,
		onGround = testState.onGround,
	}
end

---Simulate all 9 directions
function WishdirDebug.simulateAll9(state, simCtx)
	local results = {}
	for i, dirInfo in ipairs(DIRECTIONS) do
		local rawDir = dirToRawWishdir(dirInfo)
		results[i] = {
			dirInfo = dirInfo,
			result = WishdirDebug.simulateDirection(state, simCtx, rawDir),
		}
	end
	return results
end

---Find closest match by velocity direction AND magnitude
function WishdirDebug.findClosestByVelocity(actualVel, prevResults)
	if not prevResults or #prevResults == 0 then
		return nil
	end

	local actualYaw = getVelocityYaw(actualVel)
	local actualSpeed = math.sqrt(actualVel.x * actualVel.x + actualVel.y * actualVel.y)

	local bestMatch = nil
	local bestScore = math.huge

	for i, data in ipairs(prevResults) do
		local simVel = data.result.velocity
		local simSpeed = math.sqrt(simVel.x * simVel.x + simVel.y * simVel.y)
		local simYaw = getVelocityYaw(simVel)

		-- Calculate angle difference
		local yawDiff = actualYaw - simYaw
		while yawDiff > 180 do
			yawDiff = yawDiff - 360
		end
		while yawDiff < -180 do
			yawDiff = yawDiff + 360
		end

		-- Calculate speed difference
		local speedDiff = math.abs(actualSpeed - simSpeed)

		-- Combined score: angle weighted more heavily
		local score = math.abs(yawDiff) * 2 + speedDiff * 0.1

		if score < bestScore then
			bestScore = score
			bestMatch = data
		end
	end

	return bestMatch
end

---Draw 9-direction visualization with 15-unit velocity lines
function WishdirDebug.draw9Directions(entity, results, tickInterval)
	if not results or #results == 0 then
		return
	end

	local origin = entity:GetAbsOrigin()
	local playerPos = client.WorldToScreen(origin)
	if not playerPos then
		return
	end

	-- Set font for text labels
	local font = draw.CreateFont("Consolas", 12, 500)
	draw.SetFont(font)

	-- Draw 15-unit velocity lines for each direction
	for i, data in ipairs(results) do
		local vel = data.result.velocity
		local speed2D = math.sqrt(vel.x * vel.x + vel.y * vel.y)

		-- Normalize to LINE_LENGTH
		local drawVel = { x = 0, y = 0, z = 0 }
		if speed2D > 0.1 then
			local scale = LINE_LENGTH / speed2D
			drawVel.x = vel.x * scale
			drawVel.y = vel.y * scale
			drawVel.z = vel.z * scale
		end

		local endPos = Vector3(origin.x + drawVel.x, origin.y + drawVel.y, origin.z + drawVel.z)
		local endScreen = client.WorldToScreen(endPos)

		if endScreen then
			-- Color: Green=ground, Yellow=air, Gray=coast, White=best match
			if data.isBestMatch then
				draw.Color(255, 255, 255, 255) -- White for best match
			elseif data.dirInfo.name == "C" then
				draw.Color(150, 150, 150, 180)
			elseif data.result.onGround then
				draw.Color(100, 255, 100, 200)
			else
				draw.Color(255, 255, 100, 200)
			end

			draw.Line(playerPos[1], playerPos[2], endScreen[1], endScreen[2])

			-- Label at end
			draw.Color(255, 255, 255, 255)
			draw.Text(endScreen[1] + 3, endScreen[2] - 5, data.dirInfo.name)
		end
	end

	-- Draw actual velocity arrow (red)
	local actualVel = entity:EstimateAbsVelocity()
	if actualVel then
		local speed2D = actualVel:Length2D()
		if speed2D > 0.1 then
			local scale = LINE_LENGTH / speed2D
			local actualEnd =
				Vector3(origin.x + actualVel.x * scale, origin.y + actualVel.y * scale, origin.z + actualVel.z * scale)
			local actualScreen = client.WorldToScreen(actualEnd)
			if actualScreen then
				draw.Color(255, 50, 50, 255)
				draw.Line(playerPos[1], playerPos[2], actualScreen[1], actualScreen[2])
				draw.Text(actualScreen[1] + 3, actualScreen[2] - 5, "ACTUAL")
			end
		end
	end
end

---Update with current entity state - find best match from last tick, simulate new 9
function WishdirDebug.update(entity, state, simCtx)
	local entityIndex = entity:GetIndex()

	-- Find closest match from last tick's simulations
	local actualVel = entity:EstimateAbsVelocity()
	local bestMatch = nil
	if actualVel and lastTickResults[entityIndex] then
		bestMatch = WishdirDebug.findClosestByVelocity(actualVel, lastTickResults[entityIndex])
	end

	-- Simulate all 9 directions for this tick
	local results = WishdirDebug.simulateAll9(state, simCtx)

	-- Mark best match
	if bestMatch then
		for i, data in ipairs(results) do
			if data.dirInfo.name == bestMatch.dirInfo.name then
				data.isBestMatch = true
				break
			end
		end
	end

	-- Store for next tick
	lastTickResults[entityIndex] = results

	return results
end

function WishdirDebug.clear(entityIndex)
	lastTickResults[entityIndex] = nil
end

return WishdirDebug

end)
__bundle_register("simulation.Player.movement_sim", function(require, _LOADED, __bundle_register, __bundle_modules)
---@module movement_sim
---Player movement simulation with friction, acceleration, and strafe rotation
---Properly handles wishdir to continue movement in same direction

local GameConstants = require("constants.game_constants")
local StrafeRotation = require("simulation.Player.strafe_rotation")

local MovementSim = {}

local vUp = Vector3(0, 0, 1)
local STEP_SIZE = 18
local MASK_PLAYERSOLID = GameConstants.MASK_PLAYERSOLID

local function length2D(vec)
	return math.sqrt(vec.x * vec.x + vec.y * vec.y)
end

local function friction(vel, onGround, tickInterval, sv_friction, sv_stopspeed)
	if not onGround then
		return
	end

	local speed = length2D(vel)
	if speed < 0.1 then
		return
	end

	local drop = 0
	local control = speed < sv_stopspeed and sv_stopspeed or speed
	drop = drop + control * sv_friction * tickInterval

	local newspeed = math.max(speed - drop, 0)
	if newspeed ~= speed then
		newspeed = newspeed / speed
		vel.x = vel.x * newspeed
		vel.y = vel.y * newspeed
	end
end

local function accelerate(vel, wishdir, wishspeed, accel, tickInterval)
	local currentspeed = vel.x * wishdir.x + vel.y * wishdir.y
	local addspeed = wishspeed - currentspeed

	if addspeed <= 0 then
		return
	end

	local accelspeed = accel * tickInterval * wishspeed
	if accelspeed > addspeed then
		accelspeed = addspeed
	end

	vel.x = vel.x + accelspeed * wishdir.x
	vel.y = vel.y + accelspeed * wishdir.y
end

local function airAccelerate(vel, wishdir, wishspeed, accel, tickInterval)
	-- Air acceleration caps effective wishspeed to 30 (sv_airaccelerate behavior)
	local AIR_CAP = 30
	if wishspeed > AIR_CAP then
		wishspeed = AIR_CAP
	end

	local currentspeed = vel.x * wishdir.x + vel.y * wishdir.y
	local addspeed = wishspeed - currentspeed

	if addspeed <= 0 then
		return
	end

	local accelspeed = accel * tickInterval * wishspeed
	if accelspeed > addspeed then
		accelspeed = addspeed
	end

	vel.x = vel.x + accelspeed * wishdir.x
	vel.y = vel.y + accelspeed * wishdir.y
end

local function relativeToWorldWishDir(relWishdir, yaw)
	local yawRad = yaw * GameConstants.DEG2RAD
	local cosYaw = math.cos(yawRad)
	local sinYaw = math.sin(yawRad)

	local worldX = cosYaw * relWishdir.x - sinYaw * relWishdir.y
	local worldY = sinYaw * relWishdir.x + cosYaw * relWishdir.y

	local len = math.sqrt(worldX * worldX + worldY * worldY)
	if len > 0.001 then
		return {
			x = worldX / len,
			y = worldY / len,
			z = 0,
			magnitude = len,
		}
	end
	return { x = 0, y = 0, z = 0, magnitude = 0 }
end

local function normalizeVector(vec)
	return vec / vec:Lenght()
end

local function shouldHitEntity(entity, playerIndex)
	if not entity then
		return false
	end
	if entity:GetIndex() == playerIndex then
		return false
	end
	if entity:IsPlayer() then
		return false
	end

	local class = entity:GetClass()
	if class == "CTFAmmoPack" or class == "CTFDroppedWeapon" then
		return false
	end

	return true
end

-- ============================================================================
-- COLLISION SYSTEM (ported from src/player_tick.lua)
-- ============================================================================

local function dotProduct(a, b)
	return a.x * b.x + a.y * b.y + a.z * b.z
end

local function clipVelocity(velocity, normal, overbounce)
	local backoff = dotProduct(velocity, normal) * overbounce
	velocity.x = velocity.x - normal.x * backoff
	velocity.y = velocity.y - normal.y * backoff
	velocity.z = velocity.z - normal.z * backoff

	if math.abs(velocity.x) < 0.01 then
		velocity.x = 0
	end
	if math.abs(velocity.y) < 0.01 then
		velocity.y = 0
	end
	if math.abs(velocity.z) < 0.01 then
		velocity.z = 0
	end
end

local function checkIsOnGround(origin, velocity, mins, maxs, index)
	if velocity and velocity.z > GameConstants.NON_JUMP_VELOCITY then
		return false
	end

	local down = Vector3(origin.x, origin.y, origin.z - GameConstants.GROUND_CHECK_OFFSET)
	local trace = engine.TraceHull(origin, down, mins, maxs, GameConstants.MASK_PLAYERSOLID, function(ent)
		return ent:GetIndex() ~= index
	end)

	return trace and trace.fraction < 1.0 and not trace.startsolid and trace.plane and trace.plane.z >= 0.7
end

local function tryPlayerMove(origin, velocity, mins, maxs, index, tickinterval)
	local MAX_CLIP_PLANES = GameConstants.DEFAULT_MAX_CLIP_PLANES
	local time_left = tickinterval
	local planes = {}
	local numplanes = 0

	for bumpcount = 0, 3 do
		if time_left <= 0 then
			break
		end

		local end_pos = Vector3(
			origin.x + velocity.x * time_left,
			origin.y + velocity.y * time_left,
			origin.z + velocity.z * time_left
		)

		local trace = engine.TraceHull(origin, end_pos, mins, maxs, GameConstants.MASK_PLAYERSOLID, function(ent)
			return ent:GetIndex() ~= index
		end)

		if trace.fraction > 0 then
			origin.x, origin.y, origin.z = trace.endpos.x, trace.endpos.y, trace.endpos.z
			numplanes = 0
		end

		if trace.fraction == 1 then
			break
		end
		time_left = time_left - time_left * trace.fraction

		if trace.plane and numplanes < MAX_CLIP_PLANES then
			planes[numplanes] = trace.plane
			numplanes = numplanes + 1
		end

		if trace.plane then
			if trace.plane.z > 0.7 and velocity.z < 0 then
				velocity.z = 0
			end

			local i = 0
			while i < numplanes do
				clipVelocity(velocity, planes[i], 1.0)
				local j = 0
				while j < numplanes do
					if j ~= i and dotProduct(velocity, planes[j]) < 0 then
						break
					end
					j = j + 1
				end
				if j == numplanes then
					break
				end
				i = i + 1
			end

			if i == numplanes then
				if numplanes >= 2 then
					local dir = Vector3(
						planes[0].y * planes[1].z - planes[0].z * planes[1].y,
						planes[0].z * planes[1].x - planes[0].x * planes[1].z,
						planes[0].x * planes[1].y - planes[0].y * planes[1].x
					)
					local d = dotProduct(dir, velocity)
					velocity.x, velocity.y, velocity.z = dir.x * d, dir.y * d, dir.z * d
				end
				if dotProduct(velocity, planes[0]) < 0 then
					velocity.x, velocity.y, velocity.z = 0, 0, 0
					break
				end
			end
		else
			break
		end
	end
	return origin
end

local function stepMove(origin, velocity, mins, maxs, index, tickinterval, stepheight)
	local original_pos = Vector3(origin.x, origin.y, origin.z)
	local original_vel = Vector3(velocity.x, velocity.y, velocity.z)

	tryPlayerMove(origin, velocity, mins, maxs, index, tickinterval)
	local down_pos = Vector3(origin.x, origin.y, origin.z)
	local down_vel = Vector3(velocity.x, velocity.y, velocity.z)

	origin.x, origin.y, origin.z = original_pos.x, original_pos.y, original_pos.z
	velocity.x, velocity.y, velocity.z = original_vel.x, original_vel.y, original_vel.z

	local step_up_dest = Vector3(origin.x, origin.y, origin.z + stepheight + GameConstants.DIST_EPSILON)
	local step_trace = engine.TraceHull(origin, step_up_dest, mins, maxs, GameConstants.MASK_PLAYERSOLID, function(ent)
		return ent:GetIndex() ~= index
	end)

	if not step_trace.startsolid and not step_trace.allsolid then
		origin.x, origin.y, origin.z = step_trace.endpos.x, step_trace.endpos.y, step_trace.endpos.z
		tryPlayerMove(origin, velocity, mins, maxs, index, tickinterval)

		local step_down_dest = Vector3(origin.x, origin.y, origin.z - stepheight - GameConstants.DIST_EPSILON)
		local step_down_trace = engine.TraceHull(
			origin,
			step_down_dest,
			mins,
			maxs,
			GameConstants.MASK_PLAYERSOLID,
			function(ent)
				return ent:GetIndex() ~= index
			end
		)

		if step_down_trace.plane and step_down_trace.plane.z < 0.7 then
			origin.x, origin.y, origin.z = down_pos.x, down_pos.y, down_pos.z
			velocity.x, velocity.y, velocity.z = down_vel.x, down_vel.y, down_vel.z
			return origin
		end

		if not step_down_trace.startsolid and not step_down_trace.allsolid then
			origin.x, origin.y, origin.z = step_down_trace.endpos.x, step_down_trace.endpos.y, step_down_trace.endpos.z
		end

		local up_pos = Vector3(origin.x, origin.y, origin.z)
		local down_dist = (down_pos.x - original_pos.x) ^ 2 + (down_pos.y - original_pos.y) ^ 2
		local up_dist = (up_pos.x - original_pos.x) ^ 2 + (up_pos.y - original_pos.y) ^ 2

		if down_dist > up_dist then
			origin.x, origin.y, origin.z = down_pos.x, down_pos.y, down_pos.z
			velocity.x, velocity.y, velocity.z = down_vel.x, down_vel.y, down_vel.z
		else
			velocity.z = down_vel.z
		end
	else
		origin.x, origin.y, origin.z = down_pos.x, down_pos.y, down_pos.z
		velocity.x, velocity.y, velocity.z = down_vel.x, down_vel.y, down_vel.z
	end
	return origin
end

local function stayOnGround(origin, mins, maxs, stepheight, index)
	local start_pos = Vector3(origin.x, origin.y, origin.z + 2)
	local up_trace = engine.TraceHull(origin, start_pos, mins, maxs, GameConstants.MASK_PLAYERSOLID, function(ent)
		return ent:GetIndex() ~= index
	end)
	local end_pos = Vector3(up_trace.endpos.x, up_trace.endpos.y, origin.z - stepheight)
	local down_trace = engine.TraceHull(
		up_trace.endpos,
		end_pos,
		mins,
		maxs,
		GameConstants.MASK_PLAYERSOLID,
		function(ent)
			return ent:GetIndex() ~= index
		end
	)
	if
		down_trace.fraction > 0
		and down_trace.fraction < 1.0
		and not down_trace.startsolid
		and down_trace.plane
		and down_trace.plane.z >= 0.7
	then
		if math.abs(origin.z - down_trace.endpos.z) > 0.5 then
			origin.x, origin.y, origin.z = down_trace.endpos.x, down_trace.endpos.y, down_trace.endpos.z
			return true
		end
	end
	return false
end

---Simulate one tick of player movement
---@param state table Player state (from PlayerSimState.getOrCreate)
---@param simCtx table Simulation context (from PlayerSimState.getSimContext)
---@return Vector3 New origin position
function MovementSim.simulateTick(state, simCtx)
	assert(state, "simulateTick: state missing")
	assert(simCtx, "simulateTick: simCtx missing")

	local tickInterval = simCtx.tickinterval
	local gravity = simCtx.sv_gravity
	local yawDelta = state.yawDeltaPerTick or 0

	local vel = state.velocity
	local onGround = state.onGround

	-- Phase 1: Friction (only on ground)
	friction(vel, onGround, tickInterval, simCtx.sv_friction, simCtx.sv_stopspeed)

	-- Phase 2: Gravity (first half if in air)
	if not onGround then
		vel.z = vel.z - (gravity * 0.5 * tickInterval)
	end

	-- Phase 3: Wishdir acceleration
	-- Amalgam-style: apply strafe rotation to yaw BEFORE calculating wishdir
	local simYaw = StrafeRotation.applyRotation(state.index, state.yaw)
	local wishdirInfo = relativeToWorldWishDir(state.relativeWishDir, simYaw)
	local wishdir = { x = wishdirInfo.x, y = wishdirInfo.y, z = 0 }
	local inputMagnitude = wishdirInfo.magnitude

	if onGround then
		-- Ground: clamp wishspeed to maxspeed (class-specific cap)
		local wishspeed = math.min(inputMagnitude, state.maxspeed)
		accelerate(vel, wishdir, wishspeed, simCtx.sv_accelerate, tickInterval)
	else
		-- Air: airAccelerate caps to 30 internally
		airAccelerate(vel, wishdir, inputMagnitude, simCtx.sv_airaccelerate, tickInterval)
	end

	-- Phase 5: Movement with collision (using src collision system)
	local origin = Vector3(state.origin.x, state.origin.y, state.origin.z)

	if onGround then
		stepMove(origin, vel, state.mins, state.maxs, state.index, tickInterval, STEP_SIZE)
		stayOnGround(origin, state.mins, state.maxs, STEP_SIZE, state.index)
	else
		tryPlayerMove(origin, vel, state.mins, state.maxs, state.index, tickInterval)
	end

	-- Phase 6: Re-check ground state and final gravity
	onGround = checkIsOnGround(origin, vel, state.mins, state.maxs, state.index)

	if not onGround then
		vel.z = vel.z - (gravity * 0.5 * tickInterval)
	else
		if vel.z < 0 then
			vel.z = 0
		end
	end

	-- Update state
	state.origin.x = origin.x
	state.origin.y = origin.y
	state.origin.z = origin.z

	state.velocity.x = vel.x
	state.velocity.y = vel.y
	state.velocity.z = vel.z

	state.onGround = onGround

	return state.origin
end

---Simulate multiple ticks and return path
---@param state table Player state (from PlayerSimState.getOrCreate)
---@param simCtx table Simulation context (from PlayerSimState.getSimContext)
---@param numTicks integer Number of ticks to simulate
---@return Vector3[] Array of positions (path[1] = initial, path[numTicks+1] = final)
function MovementSim.simulatePath(state, simCtx, numTicks)
	assert(state, "simulatePath: state missing")
	assert(simCtx, "simulatePath: simCtx missing")

	local path = {}
	path[1] = Vector3(state.origin.x, state.origin.y, state.origin.z)

	for tick = 1, numTicks do
		MovementSim.simulateTick(state, simCtx)
		path[tick + 1] = Vector3(state.origin.x, state.origin.y, state.origin.z)
	end

	return path
end

return MovementSim

end)
__bundle_register("simulation.Player.strafe_rotation", function(require, _LOADED, __bundle_register, __bundle_modules)
---@module strafe_rotation
---Amalgam-style strafe prediction: calculate average yaw from direction history
---Apply directly to viewangle each tick, no accumulation

local StrafeRotation = {}

local rotationState = {}

---Initialize strafe rotation state
function StrafeRotation.initState(entityIndex, anchorYaw, yawDeltaPerTick)
	local enabled = math.abs(yawDeltaPerTick or 0) > 0.36 -- Amalgam threshold
	rotationState[entityIndex] = {
		anchorYaw = anchorYaw,
		yawDeltaPerTick = yawDeltaPerTick or 0,
		enabled = enabled,
	}
end

---Apply Amalgam-style strafe rotation
---Directly rotates viewangle by averageYaw each tick (no accumulation)
---@return number new yaw angle
function StrafeRotation.applyRotation(entityIndex, currentYaw)
	local state = rotationState[entityIndex]
	if not state or not state.enabled then
		return currentYaw
	end

	-- Amalgam style: just add the average yaw to viewangle
	-- No accumulation, no velocity checking - simple and direct
	return currentYaw + state.yawDeltaPerTick
end

---Check if strafe prediction is active
function StrafeRotation.isActive(entityIndex)
	local state = rotationState[entityIndex]
	return state and state.enabled or false
end

function StrafeRotation.getYawDelta(entityIndex)
	local state = rotationState[entityIndex]
	return state and state.yawDeltaPerTick or 0
end

function StrafeRotation.clear(entityIndex)
	rotationState[entityIndex] = nil
end

function StrafeRotation.clearAll()
	rotationState = {}
end

return StrafeRotation

end)
__bundle_register("constants.game_constants", function(require, _LOADED, __bundle_register, __bundle_modules)
-- Module declaration
local GameConstants = {}

-- Engine & System Constants -----
GameConstants.TICK_INTERVAL = globals.TickInterval()
GameConstants.SV_GRAVITY = 800
GameConstants.SV_MAXVELOCITY = 3500
GameConstants.SV_STOPSPEED = 100
GameConstants.SV_FRICTION = 4
GameConstants.SV_ACCELERATE = 10
GameConstants.SV_AIRACCELERATE = 10

-- Math Constants -----
GameConstants.RAD2DEG = 180 / math.pi
GameConstants.DEG2RAD = math.pi / 180

-- Physics Defaults -----
GameConstants.DEFAULT_STEP_SIZE = 18
GameConstants.DEFAULT_MAX_CLIP_PLANES = 5
GameConstants.DIST_EPSILON = 0.03125
GameConstants.GROUND_CHECK_OFFSET = 2.0
GameConstants.NON_JUMP_VELOCITY = 140.0
GameConstants.STILL_SPEED_THRESHOLD = 50.0

-- Game Masks and Flags -----
GameConstants.MASK_PLAYERSOLID = MASK_PLAYERSOLID
GameConstants.MASK_SHOT_HULL = MASK_SHOT_HULL
GameConstants.MASK_SHOT = MASK_SHOT
GameConstants.MASK_VISIBLE = MASK_VISIBLE
GameConstants.MASK_SOLID = 33570827
GameConstants.MASK_WATER = 0x4018 -- CONTENTS_WATER | CONTENTS_SLIME

GameConstants.FL_ONGROUND = 1 << 0
GameConstants.FL_DUCKING = 1 << 1

-- TF2 Specific Enums -----
GameConstants.TF_Class = {
	Scout = 1,
	Sniper = 2,
	Soldier = 3,
	Demoman = 4,
	Medic = 5,
	Heavy = 6,
	Pyro = 7,
	Spy = 8,
	Engineer = 9,
}

GameConstants.TF_Cond = {
	Cloaked = 16,
	Charging = 17,
	BlastJumping = 81,
	ParachuteDeployed = 108,
	HalloweenKart = 114,
	HalloweenKartDash = 115,
}

GameConstants.RuneTypes = {
	RUNE_NONE = -1,
	RUNE_STRENGTH = 0,
	RUNE_HASTE = 1,
	RUNE_REGEN = 2,
	RUNE_RESIST = 3,
	RUNE_VAMPIRE = 4,
	RUNE_REFLECT = 5,
	RUNE_PRECISION = 6,
	RUNE_AGILITY = 7,
	RUNE_KNOCKOUT = 8,
	RUNE_KING = 9,
	RUNE_PLAGUE = 10,
	RUNE_SUPERNOVA = 11,
}

-- Water levels
GameConstants.WaterLevel = {
	NotInWater = 0,
	Feet = 1,
	Waist = 2,
	Eyes = 3,
}

-- Input Buttons
GameConstants.Buttons = {
	ATTACK = 1,
	ATTACK2 = 2048,
	DUCK = 2,
	JUMP = 4,
}

return GameConstants

end)
__bundle_register("simulation.Player.player_sim_state", function(require, _LOADED, __bundle_register, __bundle_modules)
---@module player_sim_state
---Cached player simulation state management
---Caches static data (mins, maxs, index) per entity
---Caches cvars globally (updated every 1 second)
---Maintains per-player dynamic state between frames

local GameConstants = require("constants.game_constants")

local PlayerSimState = {}

-- Cache of simulation states per entity index
local stateCache = {}

-- Simulation context (cvars) - cached globally since they rarely change
local globalSimCtx = nil
local lastCvarUpdate = 0
local CVAR_UPDATE_INTERVAL = 1.0 -- Update cvars every 1 second

---@class SimState
---@field index integer
---@field entity Entity
---@field mins Vector3
---@field maxs Vector3
---@field stepheight number
---@field origin Vector3
---@field velocity Vector3
---@field yaw number
---@field maxspeed number
---@field yawDeltaPerTick number
---@field relativeWishDir table
---@field onGround boolean
---@field lastUpdateTime number

local function getOrCreateSimContext()
	local now = globals.RealTime()
	if not globalSimCtx or (now - lastCvarUpdate) > CVAR_UPDATE_INTERVAL then
		globalSimCtx = {
			tickinterval = globals.TickInterval() or GameConstants.TICK_INTERVAL,
			sv_gravity = client.GetConVar("sv_gravity") or GameConstants.SV_GRAVITY,
			sv_friction = client.GetConVar("sv_friction") or GameConstants.SV_FRICTION,
			sv_stopspeed = client.GetConVar("sv_stopspeed") or GameConstants.SV_STOPSPEED,
			sv_accelerate = client.GetConVar("sv_accelerate") or GameConstants.SV_ACCELERATE,
			sv_airaccelerate = client.GetConVar("sv_airaccelerate") or GameConstants.SV_AIRACCELERATE,
			curtime = now,
		}
		lastCvarUpdate = now
	else
		-- Just update curtime
		globalSimCtx.curtime = now
	end
	return globalSimCtx
end

---Initialize or get cached simulation state for entity
---@param entity Entity
---@return SimState|nil
function PlayerSimState.getOrCreate(entity)
	if not entity or not entity:IsValid() or not entity:IsAlive() then
		return nil
	end

	local index = entity:GetIndex()
	local now = globals.RealTime()

	local state = stateCache[index]

	-- Create new state if doesn't exist
	if not state then
		local mins, maxs = entity:GetMins(), entity:GetMaxs()
		if not mins or not maxs then
			return nil
		end

		state = {
			index = index,
			entity = entity,
			mins = mins,
			maxs = maxs,
			stepheight = 18,
			origin = Vector3(0, 0, 0),
			velocity = Vector3(0, 0, 0),
			yaw = 0,
			maxspeed = 320,
			yawDeltaPerTick = 0,
			relativeWishDir = { x = 0, y = 0, z = 0 },
			onGround = false,
			lastUpdateTime = 0,
		}
		stateCache[index] = state
	end

	-- Update dynamic data
	local origin = entity:GetAbsOrigin()
	local velocity = entity:EstimateAbsVelocity()

	if origin and velocity then
		-- Add small offset to prevent ground clipping
		state.origin.x = origin.x
		state.origin.y = origin.y
		state.origin.z = origin.z + 1

		state.velocity.x = velocity.x
		state.velocity.y = velocity.y
		state.velocity.z = velocity.z

		local maxspeed = entity:GetPropFloat("m_flMaxspeed")
		if maxspeed and maxspeed > 0 then
			state.maxspeed = maxspeed
		end

		-- Get yaw
		local localPlayer = entities.GetLocalPlayer()
		if localPlayer and index == localPlayer:GetIndex() then
			local angles = engine.GetViewAngles()
			if angles then
				state.yaw = angles.y
			end
		else
			local eyeYaw = entity:GetPropFloat("m_angEyeAngles[1]")
			if eyeYaw then
				state.yaw = eyeYaw
			end
		end

		state.lastUpdateTime = now
	end

	return state
end

---Get simulation context (cvars)
---@return table
function PlayerSimState.getSimContext()
	return getOrCreateSimContext()
end

---Clear cached state for entity
---@param index integer
function PlayerSimState.clear(index)
	stateCache[index] = nil
end

---Clear all cached states
function PlayerSimState.clearAll()
	stateCache = {}
end

---Cleanup stale states
function PlayerSimState.cleanup()
	local players = entities.FindByClass("CTFPlayer")
	local activeIndices = {}
	for _, ply in ipairs(players) do
		if ply and ply:IsValid() then
			activeIndices[ply:GetIndex()] = true
		end
	end

	for index, _ in pairs(stateCache) do
		if not activeIndices[index] then
			stateCache[index] = nil
		end
	end
end

return PlayerSimState

end)
__bundle_register("simulation.Player.strafe_prediction", function(require, _LOADED, __bundle_register, __bundle_modules)
local GameConstants = require("constants.game_constants")

local StrafePrediction = {}

local HISTORY_SIZE = 66
local STRAIGHT_FUZZY_VALUE_GROUND = 10.0
local STRAIGHT_FUZZY_VALUE_AIR = 5.0
local MAX_CHANGES_GROUND = 2
local MAX_CHANGES_AIR = 4
local MIN_STRAFES = 6

local history = {}

local function sign(x)
	if x > 0 then
		return 1
	end
	if x < 0 then
		return -1
	end
	return 0
end

local function normalizeAngle(angle)
	return ((angle + 180) % 360) - 180
end

local function vectorToYaw(vec)
	return math.atan(vec.y, vec.x) * GameConstants.RAD2DEG
end

function StrafePrediction.recordMovement(entityIndex, origin, velocity, mode, simTime, maxSpeed)
	assert(entityIndex, "StrafePrediction.recordMovement: entityIndex missing")

	if not history[entityIndex] then
		history[entityIndex] = {}
	end

	local records = history[entityIndex]

	local dirX, dirY = velocity.x, velocity.y
	local len = math.sqrt(dirX * dirX + dirY * dirY)
	if len > 0.1 then
		dirX = dirX / len
		dirY = dirY / len
	else
		dirX, dirY = 0, 0
	end

	table.insert(records, 1, {
		origin = { x = origin.x, y = origin.y, z = origin.z },
		velocity = { x = velocity.x, y = velocity.y, z = velocity.z },
		direction = { x = dirX, y = dirY, z = 0 },
		mode = mode,
		simTime = simTime,
		speed = len,
	})

	while #records > HISTORY_SIZE do
		table.remove(records)
	end
end

function StrafePrediction.clearHistory(entityIndex)
	history[entityIndex] = nil
end

local function getYawDifference(record1, record2, isGround, maxSpeed)
	-- Use velocity delta for more reliable angle calculation
	local vel1 = record1.velocity
	local vel2 = record2.velocity

	-- Calculate angle between velocity vectors
	local dot = vel1.x * vel2.x + vel1.y * vel2.y
	local len1 = math.sqrt(vel1.x * vel1.x + vel1.y * vel1.y)
	local len2 = math.sqrt(vel2.x * vel2.x + vel2.y * vel2.y)

	if len1 < 0.1 or len2 < 0.1 then
		return 0, 1
	end

	local cosAngle = dot / (len1 * len2)
	cosAngle = math.max(-1, math.min(1, cosAngle)) -- Clamp to [-1, 1]
	local angleRad = math.acos(cosAngle)
	local angleDeg = angleRad * GameConstants.RAD2DEG

	-- Determine rotation direction using cross product
	local cross = vel1.x * vel2.y - vel1.y * vel2.x
	if cross < 0 then
		angleDeg = -angleDeg
	end

	local deltaTime = record1.simTime - record2.simTime
	local ticks = math.max(math.floor(deltaTime / GameConstants.TICK_INTERVAL), 1)

	local yawDelta = angleDeg

	if maxSpeed and maxSpeed > 0 and record1.mode ~= 1 then
		local speedRatio = math.min(record1.speed / maxSpeed, 1.0)
		yawDelta = yawDelta * speedRatio
	end

	return yawDelta, ticks
end

local function isStraightMovement(yawDelta, speed, ticks, isGround)
	local fuzzyValue = isGround and STRAIGHT_FUZZY_VALUE_GROUND or STRAIGHT_FUZZY_VALUE_AIR
	return math.abs(yawDelta) * speed * ticks < fuzzyValue
end

function StrafePrediction.calculateAverageYaw(entityIndex, maxSpeed, minSamples)
	local records = history[entityIndex]
	if not records or #records < MIN_STRAFES then
		return nil
	end

	minSamples = minSamples or 4
	local isGround = records[1].mode ~= 1
	local maxChanges = isGround and MAX_CHANGES_GROUND or MAX_CHANGES_AIR

	local totalYaw = 0
	local totalTicks = 0
	local changes = 0
	local lastSign = 0
	local lastWasZero = false
	local validStrafes = 0

	for i = 2, math.min(#records, 30) do
		local r1 = records[i - 1]
		local r2 = records[i]

		if r1.mode ~= r2.mode then
			break
		end

		local yawDelta, ticks = getYawDifference(r1, r2, isGround, maxSpeed)
		local isStraight = isStraightMovement(yawDelta, r1.speed, ticks, isGround)

		if math.abs(yawDelta) > 45 then
			break
		end

		local currSign = sign(yawDelta)
		local currZero = math.abs(yawDelta) < 0.1

		if i > 2 then
			if currSign ~= lastSign or (currZero and lastWasZero) or isStraight then
				changes = changes + 1
				if changes > maxChanges then
					break
				end
			end
		end

		lastSign = currSign
		lastWasZero = currZero

		totalYaw = totalYaw + yawDelta
		totalTicks = totalTicks + ticks
		validStrafes = validStrafes + 1
	end

	if validStrafes < minSamples then
		return nil
	end

	local avgYaw = totalYaw / math.max(totalTicks, minSamples)

	if math.abs(avgYaw) < 0.36 then
		return nil
	end

	return avgYaw
end

function StrafePrediction.applyYawCorrection(playerCtx, simCtx, avgYaw)
	assert(playerCtx, "applyYawCorrection: playerCtx missing")
	assert(simCtx, "applyYawCorrection: simCtx missing")

	if not avgYaw or math.abs(avgYaw) < 0.01 then
		return
	end

	local isAir = playerCtx.velocity.z ~= 0 or not playerCtx.onGround

	local correction = 0
	if isAir then
		correction = 90 * sign(avgYaw)
	end

	playerCtx.yaw = playerCtx.yaw + avgYaw + correction
end

return StrafePrediction

end)
__bundle_register("simulation.Player.wishdir_estimator", function(require, _LOADED, __bundle_register, __bundle_modules)
---@module wishdir_estimator
---Estimates player movement direction from velocity
---Does NOT use player's actual input - derives from observed movement
---Snaps to 8 directions for realistic prediction

local GameConstants = require("constants.game_constants")

local WishdirEstimator = {}

local STILL_SPEED_THRESHOLD = 50

local MAX_SPEED_INPUT = 450
local DIAGONAL_INPUT = 450 / math.sqrt(2) -- ≈ 318.2

local function normalizeAngle(angle)
	return ((angle + 180) % 360) - 180
end

---Estimate view-relative wishdir from velocity
---Returns raw cmd-scale values (0-450), NOT normalized
---@param velocity Vector3 Player's current velocity
---@param yaw number Player's view yaw angle
---@return table {x, y, z} View-relative wishdir (raw cmd values)
function WishdirEstimator.estimateFromVelocity(velocity, yaw)
	assert(velocity, "estimateFromVelocity: velocity missing")
	assert(yaw, "estimateFromVelocity: yaw missing")

	local horizLen = math.sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
	if horizLen < STILL_SPEED_THRESHOLD then
		return { x = 0, y = 0, z = 0 }
	end

	local yawRad = yaw * GameConstants.DEG2RAD
	local cosYaw = math.cos(yawRad)
	local sinYaw = math.sin(yawRad)

	local velNormX = velocity.x / horizLen
	local velNormY = velocity.y / horizLen

	local relForward = cosYaw * velNormX + sinYaw * velNormY
	local relLeft = -sinYaw * velNormX + cosYaw * velNormY

	local rawX = 0
	local rawY = 0

	if relForward > 0.3 then
		rawX = MAX_SPEED_INPUT
	elseif relForward < -0.3 then
		rawX = -MAX_SPEED_INPUT
	end

	if relLeft > 0.3 then
		rawY = MAX_SPEED_INPUT
	elseif relLeft < -0.3 then
		rawY = -MAX_SPEED_INPUT
	end

	local len = math.sqrt(rawX * rawX + rawY * rawY)
	if len > 0.0001 then
		if len > MAX_SPEED_INPUT + 1 then
			local scale = MAX_SPEED_INPUT / len
			rawX = rawX * scale
			rawY = rawY * scale
		end
	else
		rawX = 0
		rawY = 0
	end

	return { x = rawX, y = rawY, z = 0 }
end

---Convert view-relative wishdir to world space
---Preserves magnitude (0-450) for proper acceleration math
---@param relativeWishdir table {x, y, z} View-relative direction (raw values)
---@param yaw number Player's view yaw angle
---@return table {x, y, z, magnitude} World-space direction (normalized) + magnitude
function WishdirEstimator.toWorldSpace(relativeWishdir, yaw)
	assert(relativeWishdir, "toWorldSpace: relativeWishdir missing")
	assert(yaw, "toWorldSpace: yaw missing")

	local yawRad = yaw * GameConstants.DEG2RAD
	local cosYaw = math.cos(yawRad)
	local sinYaw = math.sin(yawRad)

	local worldX = cosYaw * relativeWishdir.x - sinYaw * relativeWishdir.y
	local worldY = sinYaw * relativeWishdir.x + cosYaw * relativeWishdir.y

	local magnitude = math.sqrt(worldX * worldX + worldY * worldY)
	if magnitude > 0.001 then
		return {
			x = worldX / magnitude,
			y = worldY / magnitude,
			z = 0,
			magnitude = magnitude,
		}
	end

	return { x = 0, y = 0, z = 0, magnitude = 0 }
end

return WishdirEstimator

end)
return __bundle_require("__root")