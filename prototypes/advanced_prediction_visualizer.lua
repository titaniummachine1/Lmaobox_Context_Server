--[[
    Advanced Prediction Path Visualizer
    Faithful replication of Source engine movement physics
]]

-- Config
local PREDICT_TICKS = 66
local DOT_SIZE = 4

-- Constants
local FL_ONGROUND = (1 << 0)
local IN_FORWARD = (1 << 3)
local IN_BACK = (1 << 4)
local IN_MOVELEFT = (1 << 9)
local IN_MOVERIGHT = (1 << 10)

local RuneTypes_t = {
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

-- Get server cvars
local sv_gravity = client.GetConVar("sv_gravity")
local sv_stepsize = client.GetConVar("sv_stepsize")
local sv_friction = client.GetConVar("sv_friction")
local sv_stopspeed = client.GetConVar("sv_stopspeed")
local sv_accelerate = client.GetConVar("sv_accelerate")
local sv_airaccelerate = client.GetConVar("sv_airaccelerate")

local gravity = sv_gravity or 800
local stepSize = sv_stepsize or 18
local friction = sv_friction or 4
local stopSpeed = sv_stopspeed or 100
local accelerate = sv_accelerate or 10
local airAccelerate = sv_airaccelerate or 10

-- Yaw tracking for prediction (store history of yaw changes)
local lastYaw = {}
local yawChangeHistory = {} -- Stores recent yaw deltas (degrees per tick)
local YAW_HISTORY_SIZE = 33

-- Calculate wishdir from cmd input
local function CalculateWishDir(cmd)
	local fwd = cmd:GetForwardMove()
	local side = cmd:GetSideMove()

	-- Ignore minimal movements
	if math.abs(fwd) < 5 and math.abs(side) < 5 then
		return nil
	end

	-- Get view yaw
	local _, yaw = cmd:GetViewAngles()

	-- Calculate angle from forward/side (NOTE: sidemove is inverted in TF2!)
	local moveAngle = math.atan(-side, fwd) * (180 / math.pi)

	-- Convert to world space
	local worldAngle = (yaw + moveAngle) * (math.pi / 180)

	-- Return normalized wishdir vector
	return Vector3(math.cos(worldAngle), math.sin(worldAngle), 0)
end

-- Wishdir tracking (stores actual wishdir vectors)
local currentWishdirVector = {} -- Current wishdir vector per player
local lastWishdirIndex = {}
local wishdirChangeHistory = {} -- Stores recent changes (+1, -1, +4, -4, etc.)
local WISHDIR_HISTORY_SIZE = 33

-- Pattern types
local PATTERN_NONE = 0
local PATTERN_CLOCKWISE = 1        -- +1
local PATTERN_COUNTERCLOCKWISE = 2 -- -1
local PATTERN_VERTICAL_OSC = 3     -- 0↔4, 1↔5, etc.
local PATTERN_HORIZONTAL_OSC = 4   -- 2↔6, 3↔7

local detectedPattern = {}
local patternStrength = {} -- How consistent is the pattern (0-1)

-- Normalize angle to -180 to 180
local function NormalizeAngle(angle)
	return ((angle + 180) % 360) - 180
end

-- 8 directional movement relative to view
local DIRECTIONS = {
	[0] = { x = 1, y = 0 }, -- Forward (W)
	[1] = { x = 1, y = 1 }, -- Forward-Right (W+D)
	[2] = { x = 0, y = 1 }, -- Right (D)
	[3] = { x = -1, y = 1 }, -- Back-Right (S+D)
	[4] = { x = -1, y = 0 }, -- Back (S)
	[5] = { x = -1, y = -1 }, -- Back-Left (S+A)
	[6] = { x = 0, y = -1 }, -- Left (A)
	[7] = { x = 1, y = -1 } -- Forward-Left (W+A)
}

-- Get wishdir index from cmd (0-7, relative to view)
local function GetWishdirIndex(cmd)
	local fwd = cmd:GetForwardMove()
	local side = cmd:GetSideMove()

	-- Check if there's any input
	if math.abs(fwd) < 5 and math.abs(side) < 5 then
		return nil -- No movement
	end

	-- Calculate angle from forward/side move (sidemove is inverted in TF2)
	local angle = math.atan(-side, fwd) * (180 / math.pi)

	-- Snap to 8 directions (every 45 degrees)
	local dirIndex = (math.floor((angle + 22.5) / 45) % 8 + 8) % 8

	return dirIndex
end

-- Convert direction index + yaw to world-space wishdir
local function IndexToWishDir(dirIndex, yaw)
	dirIndex = math.floor(dirIndex + 0.5) % 8
	local dir = DIRECTIONS[dirIndex]

	-- Rotate by yaw to get world-space wishdir
	local yawRad = yaw * (math.pi / 180)
	local cosYaw = math.cos(yawRad)
	local sinYaw = math.sin(yawRad)

	local worldX = dir.x * cosYaw - dir.y * sinYaw
	local worldY = dir.x * sinYaw + dir.y * cosYaw

	-- Normalize
	local len = math.sqrt(worldX * worldX + worldY * worldY)
	if len > 0.01 then
		worldX = worldX / len
		worldY = worldY / len
	end

	return Vector3(worldX, worldY, 0)
end

-- Detect pattern from change history (pick most likely, no thresholds)
local function DetectPattern(idx)
	local history = wishdirChangeHistory[idx]
	if not history or #history < 3 then
		return PATTERN_NONE, 0
	end

	-- Count evidence for each pattern type
	local clockwiseCount = 0
	local counterClockwiseCount = 0
	local noChangeCount = 0

	for i = 1, #history do
		if history[i] == 1 then
			clockwiseCount = clockwiseCount + 1
		elseif history[i] == -1 then
			counterClockwiseCount = counterClockwiseCount + 1
		elseif history[i] == 0 then
			noChangeCount = noChangeCount + 1
		end
	end

	-- Check for oscillation (changes alternate between +4 and -4)
	local oscillationCount = 0
	for i = 2, #history do
		local curr = history[i]
		local prev = history[i - 1]

		-- Check if alternating between opposite directions
		if (curr == 4 and prev == -4) or (curr == -4 and prev == 4) then
			oscillationCount = oscillationCount + 1
		end
	end

	local total = #history

	-- Find most likely pattern (highest count wins)
	local maxCount = math.max(clockwiseCount, counterClockwiseCount, oscillationCount, noChangeCount)

	-- If mostly no change, it's walking straight
	if maxCount == noChangeCount then
		return PATTERN_NONE, noChangeCount / total
	end

	-- Pick pattern with highest evidence
	if maxCount == clockwiseCount then
		return PATTERN_CLOCKWISE, clockwiseCount / total
	elseif maxCount == counterClockwiseCount then
		return PATTERN_COUNTERCLOCKWISE, counterClockwiseCount / total
	elseif maxCount == oscillationCount then
		-- Determine if vertical or horizontal
		local lastIdx = lastWishdirIndex[idx]
		if lastIdx == 0 or lastIdx == 4 or lastIdx == 1 or lastIdx == 5 then
			return PATTERN_VERTICAL_OSC, oscillationCount / (total - 1)
		else
			return PATTERN_HORIZONTAL_OSC, oscillationCount / (total - 1)
		end
	end

	return PATTERN_NONE, 0
end

local function UpdateTracking(entity, cmd)
	if not entity then return end

	local idx = entity:GetIndex()

	-- Get current yaw
	local angles
	if entity == entities.GetLocalPlayer() then
		angles = engine.GetViewAngles()
	else
		angles = entity:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]")
	end

	if angles then
		local currentYaw = angles.y

		-- Track yaw changes (store deltas in history)
		if lastYaw[idx] then
			local yawDelta = NormalizeAngle(currentYaw - lastYaw[idx])

			-- Store in history
			if not yawChangeHistory[idx] then
				yawChangeHistory[idx] = {}
			end
			table.insert(yawChangeHistory[idx], 1, yawDelta)

			-- Keep only recent history
			if #yawChangeHistory[idx] > YAW_HISTORY_SIZE then
				table.remove(yawChangeHistory[idx])
			end
		end
		lastYaw[idx] = currentYaw
	end

	-- Track wishdir index changes (relative to view)
	local currentWishdirIndex = GetWishdirIndex(cmd)
	if currentWishdirIndex and lastWishdirIndex[idx] and currentWishdirIndex ~= lastWishdirIndex[idx] then
		local dirDelta = currentWishdirIndex - lastWishdirIndex[idx]

		-- Normalize to shortest path in 8-direction circular space (-4 to 4)
		dirDelta = ((dirDelta + 4) % 8) - 4

		-- Store change in history
		if not wishdirChangeHistory[idx] then
			wishdirChangeHistory[idx] = {}
		end
		table.insert(wishdirChangeHistory[idx], 1, dirDelta)

		-- Keep only last N changes
		while #wishdirChangeHistory[idx] > WISHDIR_HISTORY_SIZE do
			table.remove(wishdirChangeHistory[idx])
		end

		-- Detect pattern
		local pattern, strength = DetectPattern(idx)
		detectedPattern[idx] = pattern
		patternStrength[idx] = strength
	end

	if currentWishdirIndex then
		lastWishdirIndex[idx] = currentWishdirIndex
	end
end

-- Update tracking every frame
local function OnCreateMove(cmd)
	local me = entities.GetLocalPlayer()
	if not me or not me:IsAlive() then return end

	UpdateTracking(me, cmd)

	-- Store actual wishdir vector for use in prediction
	local wishdirVec = CalculateWishDir(cmd)
	if wishdirVec then
		currentWishdirVector[me:GetIndex()] = wishdirVec
	end
end

---@param velocity Vector3
---@param wishdir Vector3
---@param wishspeed number
---@param accel number
---@param frametime number
local function Accelerate(velocity, wishdir, wishspeed, accel, frametime)
	local currentspeed = velocity:Dot(wishdir)
	local addspeed = wishspeed - currentspeed

	if addspeed <= 0 then
		return
	end

	local accelspeed = accel * frametime * wishspeed
	if accelspeed > addspeed then
		accelspeed = addspeed
	end

	velocity.x = velocity.x + wishdir.x * accelspeed
	velocity.y = velocity.y + wishdir.y * accelspeed
	velocity.z = velocity.z + wishdir.z * accelspeed
end

---@param target Entity
---@return number
local function GetAirSpeedCap(target)
	local m_hGrapplingHookTarget = target:GetPropEntity("m_hGrapplingHookTarget")
	if m_hGrapplingHookTarget then
		if target:GetCarryingRuneType() == RuneTypes_t.RUNE_AGILITY then
			local m_iClass = target:GetPropInt("m_iClass")
			return (m_iClass == 2 or m_iClass == 6) and 850 or 950 -- Soldier or Heavy
		end
		local tf_grapplinghook_move_speed = client.GetConVar("tf_grapplinghook_move_speed")
		return tf_grapplinghook_move_speed or 750
	elseif target:InCond(76) then -- TFCond_Charging
		local tf_max_charge_speed = client.GetConVar("tf_max_charge_speed")
		return tf_max_charge_speed or 750
	else
		local flCap = 30.0
		if target:InCond(71) then -- TFCond_ParachuteDeployed
			local tf_parachute_aircontrol = client.GetConVar("tf_parachute_aircontrol")
			flCap = flCap * (tf_parachute_aircontrol or 1.0)
		end
		if target:InCond(79) then -- TFCond_HalloweenKart
			if target:InCond(80) then -- TFCond_HalloweenKartDash
				local tf_halloween_kart_dash_speed = client.GetConVar("tf_halloween_kart_dash_speed")
				return tf_halloween_kart_dash_speed or 750
			end
			local tf_hallowen_kart_aircontrol = client.GetConVar("tf_hallowen_kart_aircontrol")
			flCap = flCap * (tf_hallowen_kart_aircontrol or 1.0)
		end
		return flCap * (target:AttributeHookFloat("mod_air_control") or 1.0)
	end
end

---@param v Vector3 Velocity
---@param wishdir Vector3
---@param wishspeed number
---@param accel number
---@param dt number
---@param surf number
---@param target Entity
local function AirAccelerate(v, wishdir, wishspeed, accel, dt, surf, target)
	wishspeed = math.min(wishspeed, GetAirSpeedCap(target))
	local currentspeed = v:Dot(wishdir)
	local addspeed = wishspeed - currentspeed
	if addspeed <= 0 then
		return
	end

	local accelspeed = math.min(accel * wishspeed * dt * surf, addspeed)
	v.x = v.x + accelspeed * wishdir.x
	v.y = v.y + accelspeed * wishdir.y
	v.z = v.z + accelspeed * wishdir.z
end

local function CheckIsOnGround(origin, mins, maxs, index)
	local down = Vector3(origin.x, origin.y, origin.z - 18)
	local trace = engine.TraceHull(origin, down, mins, maxs, MASK_PLAYERSOLID, function(ent, contentsMask)
		return ent:GetIndex() ~= index
	end)

	return trace and trace.fraction < 1.0 and not trace.startsolid and trace.plane and trace.plane.z >= 0.7
end

---@param index integer
local function StayOnGround(origin, mins, maxs, step_size, index)
	local vstart = Vector3(origin.x, origin.y, origin.z + 2)
	local vend = Vector3(origin.x, origin.y, origin.z - step_size)

	local trace = engine.TraceHull(vstart, vend, mins, maxs, MASK_PLAYERSOLID, function(ent, contentsMask)
		return ent:GetIndex() ~= index
	end)

	if trace and trace.fraction < 1.0 and not trace.startsolid and trace.plane and trace.plane.z >= 0.7 then
		local delta = math.abs(origin.z - trace.endpos.z)
		if delta > 0.5 then
			origin.x = trace.endpos.x
			origin.y = trace.endpos.y
			origin.z = trace.endpos.z
			return true
		end
	end

	return false
end

---@param velocity Vector3
---@param is_on_ground boolean
---@param frametime number
local function Friction(velocity, is_on_ground, frametime)
	local speed = velocity:LengthSqr()
	if speed < 0.01 then
		return
	end

	local drop = 0

	if is_on_ground then
		local control = speed < stopSpeed and stopSpeed or speed
		drop = drop + control * friction * frametime
	end

	local newspeed = speed - drop
	if newspeed ~= speed then
		newspeed = newspeed / speed
		velocity.x = velocity.x * newspeed
		velocity.y = velocity.y * newspeed
		velocity.z = velocity.z * newspeed
	end
end

-- Clip velocity along a plane normal
local function ClipVelocity(velocity, normal, overbounce)
	local backoff = velocity:Dot(normal) * overbounce

	velocity.x = velocity.x - normal.x * backoff
	velocity.y = velocity.y - normal.y * backoff
	velocity.z = velocity.z - normal.z * backoff

	-- Zero out small components
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

-- Perform collision-aware movement
local function TryPlayerMove(origin, velocity, mins, maxs, index, tickinterval)
	local MAX_CLIP_PLANES = 5
	local time_left = tickinterval
	local planes = {}
	local numplanes = 0

	-- Try moving up to 4 times (with bumps)
	for bumpcount = 0, 3 do
		if time_left <= 0 then
			break
		end

		-- Calculate end position
		local end_pos = Vector3(
			origin.x + velocity.x * time_left,
			origin.y + velocity.y * time_left,
			origin.z + velocity.z * time_left
		)

		-- Trace from current position to desired position
		local trace = engine.TraceHull(origin, end_pos, mins, maxs, MASK_PLAYERSOLID, function(ent, contentsMask)
			return ent:GetIndex() ~= index
		end)

		-- If we made it all the way, we're done
		if trace.fraction > 0 then
			origin.x = trace.endpos.x
			origin.y = trace.endpos.y
			origin.z = trace.endpos.z
			numplanes = 0
		end

		if trace.fraction == 1 then
			break
		end

		-- Update time remaining
		time_left = time_left - time_left * trace.fraction

		-- Record this plane
		if trace.plane and numplanes < MAX_CLIP_PLANES then
			planes[numplanes] = trace.plane
			numplanes = numplanes + 1
		end

		-- Modify velocity to slide along the plane
		if trace.plane then
			-- If we hit the ground and going down, stop vertical movement
			if trace.plane.z > 0.7 and velocity.z < 0 then
				velocity.z = 0
			end

			-- Clip velocity against all planes we've hit
			local i = 0
			while i < numplanes do
				ClipVelocity(velocity, planes[i], 1.0)

				-- Check if velocity is still going into any plane
				local j = 0
				while j < numplanes do
					if j ~= i then
						local dot = velocity:Dot(planes[j])
						if dot < 0 then
							break
						end
					end
					j = j + 1
				end

				if j == numplanes then
					break
				end

				i = i + 1
			end

			-- If we're going into all planes, stop
			if i == numplanes then
				if numplanes >= 2 then
					-- Slide along the crease between planes
					local dir = Vector3(
						planes[0].y * planes[1].z - planes[0].z * planes[1].y,
						planes[0].z * planes[1].x - planes[0].x * planes[1].z,
						planes[0].x * planes[1].y - planes[0].y * planes[1].x
					)

					local d = dir:Dot(velocity)
					velocity.x = dir.x * d
					velocity.y = dir.y * d
					velocity.z = dir.z * d
				end

				-- Still going into a plane, stop all movement
				local dot = velocity:Dot(planes[0])
				if dot < 0 then
					velocity.x = 0
					velocity.y = 0
					velocity.z = 0
					break
				end
			end
		else
			-- No plane, just stop
			break
		end
	end

	return origin
end

-- Predict full physics simulation
---@param player Entity
---@param ticks integer
---@param wishdir? Vector3 Optional wishdir (if nil, will predict input)
local function PredictPath(player, ticks, wishdir)
	assert(player, "PredictPath: nil player")

	local path = {}
	local velocity = player:GetPropVector("localdata", "m_vecVelocity[0]") or player:EstimateAbsVelocity()
	local origin = player:GetAbsOrigin() + Vector3(0, 0, 1)

	if not velocity or velocity:Length() <= 0.01 then
		path[0] = origin
		return path
	end

	local maxspeed = player:GetPropFloat("m_flMaxspeed") or 450
	local tickinterval = globals.TickInterval()
	local mins, maxs = player:GetMins(), player:GetMaxs()
	local index = player:GetIndex()

	-- DEBUG: Print history status
	if not _DEBUG_COUNTER then _DEBUG_COUNTER = 0 end
	_DEBUG_COUNTER = _DEBUG_COUNTER + 1
	if _DEBUG_COUNTER % 66 == 1 then -- Print once per second
		local yawHistSize = yawHistory and #yawHistory or 0
		local wishdirHistSize = (wishdirChangeHistory[index] and #wishdirChangeHistory[index]) or 0
		print(string.format("[DEBUG] Yaw hist: %d | Wishdir hist: %d | YawRate: %.3f",
			yawHistSize, wishdirHistSize, yawRotationPerTick))
	end

	-- Get yaw directly from entity (always available for all players)
	local isLocalPlayer = (player == entities.GetLocalPlayer())
	local angles
	if isLocalPlayer then
		angles = engine.GetViewAngles()
	else
		angles = player:GetPropVector("tfnonlocaldata", "m_angEyeAngles[0]")
	end
	local currentYaw = angles and angles.y or 0

	-- Calculate yaw rotation rate from history (average recent changes)
	-- For local player: don't predict yaw changes (we're not predicting mouse movement)
	-- For enemies: predict based on history
	local yawRotationPerTick = 0
	if not isLocalPlayer then
		local yawHistory = yawChangeHistory[index]
		if yawHistory and #yawHistory > 0 then
			local sum = 0
			for i = 1, math.min(5, #yawHistory) do
				sum = sum + yawHistory[i]
			end
			yawRotationPerTick = sum / math.min(5, #yawHistory)
		end
	end

	-- Wishdir prediction setup
	local currentWishdirIndex
	local wishdirRotation = 0 -- Continuous rotation per tick

	if wishdir then
		-- Convert provided wishdir to direction index (keep constant in world space)
		currentWishdirIndex = nil -- Will recalculate each tick from constant wishdir
	else
		-- Use tracked wishdir index
		currentWishdirIndex = lastWishdirIndex[index] or 0

		-- Get wishdir rotation from history
		local history = wishdirChangeHistory[index]
		local historyRotation = 0
		if history and #history > 0 then
			-- Average recent changes to get rotation tendency
			local sum = 0
			for i = 1, math.min(5, #history) do
				sum = sum + history[i]
			end
			historyRotation = sum / math.min(5, #history)
		end

		-- For enemies: use wishdir history directly (no rate limiting!)
		wishdirRotation = historyRotation
	end

	path[0] = Vector3(origin.x, origin.y, origin.z)

	-- Start with ACTUAL current velocity (make a COPY, not reference)
	local currentVel = Vector3(velocity.x, velocity.y, velocity.z)

	for tick = 1, ticks do
		-- Update yaw based on predicted change rate (from history average)
		currentYaw = currentYaw + yawRotationPerTick

		-- Get current wishdir
		local currentWishdir
		if wishdir then
			-- Use provided constant wishdir
			currentWishdir = wishdir
		else
			-- Smoothly rotate wishdir index (continuous, not discrete jumps)
			currentWishdirIndex = currentWishdirIndex + wishdirRotation

			-- Convert index + yaw to world-space wishdir (auto-snaps to 8 directions)
			currentWishdir = IndexToWishDir(currentWishdirIndex, currentYaw)
		end

		local is_on_ground = CheckIsOnGround(origin, mins, maxs, index)

		Friction(currentVel, is_on_ground, tickinterval)

		if is_on_ground then
			Accelerate(currentVel, currentWishdir, maxspeed, accelerate, tickinterval)
			currentVel.z = 0
		else
			AirAccelerate(currentVel, currentWishdir, maxspeed, airAccelerate, tickinterval, 0, player)
			currentVel.z = currentVel.z - gravity * tickinterval
		end

		-- Perform collision-aware movement
		origin = TryPlayerMove(origin, currentVel, mins, maxs, index, tickinterval)

		-- If on ground, stick to it
		if is_on_ground then
			StayOnGround(origin, mins, maxs, stepSize, index)
		end

		path[tick] = Vector3(origin.x, origin.y, origin.z)
	end

	return path
end

-- Draw callback
local function OnDraw()
	local me = entities.GetLocalPlayer()
	if not me or not me:IsAlive() then
		return
	end

	-- Predict path using actual tracked wishdir (accurate for local player)
	local myWishdir = currentWishdirVector[me:GetIndex()]
	local path = PredictPath(me, PREDICT_TICKS, myWishdir)
	if not path then
		return
	end

	-- Draw gradient path (green -> yellow -> red, fading alpha)
	for i = 0, PREDICT_TICKS - 1 do
		local pos1 = path[i]
		local pos2 = path[i + 1]
		if not pos1 or not pos2 then
			break
		end

		local screen1 = client.WorldToScreen(pos1)
		local screen2 = client.WorldToScreen(pos2)

		if screen1 and screen2 then
			-- Calculate color gradient (green -> yellow -> red)
			local t = i / PREDICT_TICKS
			local r = math.floor(255 * t)
			local g = math.floor(255 * (1 - t * 0.5))

			-- Fade alpha toward end of prediction
			local alpha = math.floor(255 * (1 - t * 0.6))
			alpha = math.max(alpha, 80) -- Minimum visibility

			draw.Color(r, g, 0, alpha)
			draw.Line(
				math.floor(screen1[1]),
				math.floor(screen1[2]),
				math.floor(screen2[1]),
				math.floor(screen2[2])
			)
		end
	end

	-- Draw dots only at key points (every 10 ticks) for cleaner look
	for i = 0, PREDICT_TICKS, 10 do
		local pos = path[i]
		if not pos then
			break
		end

		local screen = client.WorldToScreen(pos)
		if screen then
			-- Calculate color
			local t = i / PREDICT_TICKS
			local r = math.floor(255 * t)
			local g = math.floor(255 * (1 - t * 0.5))
			local alpha = math.floor(255 * (1 - t * 0.6))
			alpha = math.max(alpha, 100)

			-- Draw dot
			draw.Color(r, g, 0, alpha)
			draw.FilledRect(
				math.floor(screen[1] - DOT_SIZE / 2),
				math.floor(screen[2] - DOT_SIZE / 2),
				math.floor(screen[1] + DOT_SIZE / 2),
				math.floor(screen[2] + DOT_SIZE / 2)
			)
		end
	end
end

-- Register callbacks
callbacks.Unregister("CreateMove", "AdvancedPredictionVisualizer_Yaw")
callbacks.Unregister("Draw", "AdvancedPredictionVisualizer")
callbacks.Register("CreateMove", "AdvancedPredictionVisualizer_Yaw", OnCreateMove)
callbacks.Register("Draw", "AdvancedPredictionVisualizer", OnDraw)

print("[Advanced Prediction Visualizer] Loaded - Full physics simulation with yaw prediction (" ..
	PREDICT_TICKS .. " ticks)")
