--[[
    Advanced Prediction Path Visualizer
    Faithful replication of Source engine movement physics
]]

-- Config
local PREDICT_TICKS = 120
local DOT_SIZE = 4

-- Constants
local FL_ONGROUND = (1 << 0)

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
local function PredictPath(player, ticks)
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
	local wishdir = velocity / velocity:Length()
	local mins, maxs = player:GetMins(), player:GetMaxs()
	local index = player:GetIndex()

	path[0] = Vector3(origin.x, origin.y, origin.z)

	for tick = 1, ticks do
		local is_on_ground = CheckIsOnGround(origin, mins, maxs, index)

		Friction(velocity, is_on_ground, tickinterval)

		if is_on_ground then
			Accelerate(velocity, wishdir, maxspeed, accelerate, tickinterval)
			velocity.z = 0
		else
			AirAccelerate(velocity, wishdir, maxspeed, airAccelerate, tickinterval, 0, player)
			velocity.z = velocity.z - gravity * tickinterval
		end

		-- Perform collision-aware movement
		origin = TryPlayerMove(origin, velocity, mins, maxs, index, tickinterval)

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

	-- Predict path
	local path = PredictPath(me, PREDICT_TICKS)
	if not path then
		return
	end

	-- First pass: draw lines connecting all points
	for i = 0, PREDICT_TICKS - 1 do
		local pos1 = path[i]
		local pos2 = path[i + 1]
		if not pos1 or not pos2 then
			break
		end

		local screen1 = client.WorldToScreen(pos1)
		local screen2 = client.WorldToScreen(pos2)

		if screen1 and screen2 then
			-- Calculate color for this segment (green -> yellow -> red)
			local t = i / PREDICT_TICKS
			local r = math.floor(255 * t)
			local g = math.floor(255 * (1 - t * 0.5))

			draw.Color(r, g, 0, 200)
			draw.Line(screen1[1], screen1[2], screen2[1], screen2[2])
		end
	end

	-- Second pass: draw dots on top of lines
	for i = 0, PREDICT_TICKS do
		local pos = path[i]
		if not pos then
			break
		end

		local screen = client.WorldToScreen(pos)
		if screen then
			-- Calculate color (green -> yellow -> red)
			local t = i / PREDICT_TICKS
			local r = math.floor(255 * t)
			local g = math.floor(255 * (1 - t * 0.5))

			-- Draw dot with outline
			draw.Color(r, g, 0, 255)
			draw.FilledRect(
				screen[1] - DOT_SIZE / 2,
				screen[2] - DOT_SIZE / 2,
				screen[1] + DOT_SIZE / 2,
				screen[2] + DOT_SIZE / 2
			)

			-- Draw outline for better visibility
			draw.Color(0, 0, 0, 255)
			draw.OutlinedRect(
				screen[1] - DOT_SIZE / 2,
				screen[2] - DOT_SIZE / 2,
				screen[1] + DOT_SIZE / 2,
				screen[2] + DOT_SIZE / 2
			)
		end
	end
end

-- Register callback
callbacks.Unregister("Draw", "AdvancedPredictionVisualizer")
callbacks.Register("Draw", "AdvancedPredictionVisualizer", OnDraw)

print("[Advanced Prediction Visualizer] Loaded - Full physics simulation (" .. PREDICT_TICKS .. " ticks)")
