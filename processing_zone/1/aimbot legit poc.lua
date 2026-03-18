local mouse_speed_threshold = 7 -- Adjust this value as needed
local aimbot_fov_limit = 90 -- Max FOV for targeting
local legitimacy_dot_threshold = 0.5 -- Adjust this sensitivity (0 to 1). Higher = more sensitive (disables aimbot sooner when moving towards target).

-- Triggerbot Settings (Adjust as needed)
local trigger_key = gui.GetValue("trigger key") -- Set your desired triggerbot keybind (e.g., MOUSE4, MOUSE5, KEY_F) or KEY_NONE for always on
local enable_body_trigger = true -- Set to true to allow trigger on body shots, false for headshots only

-- Helper Functions --

-- Calculate angle vectors (Forward, Right, Up) from EulerAngles
local function AngleVectors(angles)
	local sp, sy, sr = math.sin(math.rad(angles.pitch)), math.sin(math.rad(angles.yaw)), math.sin(math.rad(angles.roll))
	local cp, cy, cr = math.cos(math.rad(angles.pitch)), math.cos(math.rad(angles.yaw)), math.cos(math.rad(angles.roll))

	local forward = Vector3(cp * cy, cp * sy, -sp)
	local right = Vector3(-sr * sp * cy + cr * sy, -sr * sp * sy - cr * cy, -sr * cp)
	local up = Vector3(cr * sp * cy + sr * sy, cr * sp * sy - sr * cy, cr * cp)

	return forward, right, up
end

-- Calculate FOV between two direction vectors
local function CalculateFOV(viewForward, targetDirection)
	local dot = viewForward:Dot(targetDirection)
	-- Clamp dot product to avoid math domain errors
	dot = math.max(-1.0, math.min(1.0, dot))
	return math.deg(math.acos(dot))
end

-- Get estimated head position (center of head hitbox)
local function GetPlayerHeadPos(player)
	if not player or not player:IsValid() then
		return nil
	end
	local hitboxes = player:GetHitboxes() -- Returns table { [index] = { mins, maxs }, ... }
	if not hitboxes then
		return nil
	end

	-- Try hitbox index 0 (often head in TF2 hitbox enum)
	local headHitbox = hitboxes[0]
	if not headHitbox then
		-- Fallback: try index 1 if 0 doesn't exist
		headHitbox = hitboxes[1]
	end

	if headHitbox and headHitbox[1] and headHitbox[2] then
		-- Calculate center of the hitbox
		return (headHitbox[1] + headHitbox[2]) * 0.5
	end

	-- Fallback: eye position if hitboxes fail
	local viewOffset = player:GetPropVector("localdata", "m_vecViewOffset[0]")
	if viewOffset then
		return player:GetAbsOrigin() + viewOffset
	end

	return nil -- Couldn't get a head position
end

-- Find the best target based on lowest FOV
local function GetBestTargetByFOV(me, max_fov)
	local bestTarget = nil
	local lowestFov = max_fov + 1 -- Start higher than max

	local myOrigin = me:GetAbsOrigin()
	-- Ensure myEyePos is calculated correctly
	local viewOffset = me:GetPropVector("localdata", "m_vecViewOffset[0]")
	if not viewOffset then
		return nil
	end -- Cannot proceed without view offset
	local myEyePos = myOrigin + viewOffset
	local myViewAngles = engine.GetViewAngles()
	local myForward, _, _ = AngleVectors(myViewAngles)

	local players = entities.FindByClass("CTFPlayer")
	if not players then
		return nil
	end

	for _, player in pairs(players) do
		if
			player
			and player:IsValid()
			and player:IsAlive()
			and not player:IsDormant()
			and player:GetTeamNumber() ~= me:GetTeamNumber()
			and player ~= me
		then
			local headPos = GetPlayerHeadPos(player)
			if headPos then
				-- Make sure target direction vector is normalized
				local directionToTarget = (headPos - myEyePos)
				if directionToTarget:LengthSqr() > 0 then -- Avoid normalizing zero vector
					directionToTarget:Normalize()
					local fov = CalculateFOV(myForward, directionToTarget)

					if fov < lowestFov and fov <= max_fov then
						lowestFov = fov
						bestTarget = player
					end
				end
			end
		end
	end
	return bestTarget
end

-- Normalize a 2D vector (table {x, y})
local function Normalize2D(vec)
	local len = math.sqrt(vec.x * vec.x + vec.y * vec.y)
	if len == 0 then
		return { x = 0, y = 0 }
	end
	return { x = vec.x / len, y = vec.y / len }
end

-- Dot product of two 2D vectors (tables {x, y})
local function DotProduct2D(vec1, vec2)
	return vec1.x * vec2.x + vec1.y * vec2.y
end

-- Main Function --

local function MinimalCrash_CreateMove(cmd)
	-- 1. Get Local Player
	local me = entities.GetLocalPlayer()
	if not me or not me:IsValid() or not me:IsAlive() then
		-- Ensure aimbot is off if we can't get local player
		gui.SetValue("aim bot", 0)
		return
	end

	-- *** Triggerbot Logic Start ***
	local source = me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]")
	local destination = source + engine.GetViewAngles():Forward() * 8192 -- Use a long trace distance
	local trace = engine.TraceLine(source, destination, MASK_SHOT_HULL) -- Use MASK_SHOT_HULL for better accuracy

	local trigger_activated = false
	if
		trace.entity
		and trace.entity:IsValid()
		and trace.entity:IsPlayer()
		and trace.entity:GetTeamNumber() ~= me:GetTeamNumber()
		and trace.entity:IsAlive()
	then
		local key_pressed = (trigger_key == KEY_NONE or input.IsButtonDown(trigger_key))
		local is_headshot = trace.hitgroup == 1 -- Lmaobox uses hitgroup 1 for head typically
		local is_bodyshot = trace.hitgroup >= 2 -- Assuming hitgroups 2+ are body

		if key_pressed then
			if is_headshot or (enable_body_trigger and is_bodyshot) then
				-- Trigger condition met!
				gui.SetValue("aim bot", 0) -- Disable aimbot
				pCmd:SetButtons(pCmd:GetButtons() | IN_ATTACK) -- Fire weapon
				-- print("Triggerbot Activated!") -- Optional debug
				trigger_activated = true -- Flag that triggerbot took over
				-- return -- Immediately exit to prevent aimbot logic THIS TICK
				-- Note: Decided against immediate return. If aimbot was already disabled due to legitimacy,
				--       letting it run won't hurt and might re-enable if conditions change next tick.
				--       If aimbot *would* have been enabled, we explicitly disabled it above.
			end
		end
	end
	-- *** Triggerbot Logic End ***

	-- Find best target by FOV (only needed if trigger didn't activate)
	local target = nil
	if not trigger_activated then
		target = GetBestTargetByFOV(me, aimbot_fov_limit)
	end

	local enable_aimbot = false -- Default to off unless conditions met

	-- Calculate mouse speed check first
	local mouse_delta_x = cmd.mousedx or 0
	local mouse_delta_y = cmd.mousedy or 0
	local total_mouse_delta = math.abs(mouse_delta_x) + math.abs(mouse_delta_y)
	local is_mouse_fast_enough = total_mouse_delta >= mouse_speed_threshold

	-- Run aimbot legitimacy check ONLY if triggerbot didn't activate
	if not trigger_activated and target and is_mouse_fast_enough then
		-- Target found and mouse is moving fast enough, now do legitimacy check
		local headPosWorld = GetPlayerHeadPos(target)
		if headPosWorld then
			local headPosScreen = client.WorldToScreen(headPosWorld)

			if headPosScreen then
				local screenW, screenH = draw.GetScreenSize()
				local screenCenterX = screenW / 2
				local screenCenterY = screenH / 2

				-- Vector from screen center to head position
				local vectorToHead = { x = headPosScreen[1] - screenCenterX, y = headPosScreen[2] - screenCenterY }

				-- Mouse movement vector
				local mouseVector = { x = mouse_delta_x, y = mouse_delta_y }

				-- Only perform dot product check if mouse is actually moving AND target is not exactly at crosshair
				if (mouseVector.x ~= 0 or mouseVector.y ~= 0) and (vectorToHead.x ~= 0 or vectorToHead.y ~= 0) then
					local normalizedVectorToHead = Normalize2D(vectorToHead)
					local normalizedMouseVector = Normalize2D(mouseVector)

					-- Calculate dot product
					local dot = DotProduct2D(normalizedMouseVector, normalizedVectorToHead)

					-- If dot product is low enough (mouse not moving directly towards head), enable aimbot
					if dot < legitimacy_dot_threshold then
						enable_aimbot = true
						-- print("MinimalCrash: Aimbot Enabled (Legit Move, Dot: ".. string.format("%.2f", dot) .. ")")
					else
						-- print("MinimalCrash: Aimbot Disabled (Too Direct, Dot: ".. string.format("%.2f", dot) .. ")")
					end
				else
					-- If mouse isn't moving OR head is exactly at center, allow aimbot (as the dot product check is meaningless here)
					enable_aimbot = true
					-- print("MinimalCrash: Aimbot Enabled (Center/No Mouse Move)")
				end
			else
				-- Head off screen, maybe allow aimbot if mouse speed check passed?
				enable_aimbot = true -- Or set to false if you want to disable when head is off-screen
				-- print("MinimalCrash: Aimbot Enabled (Head Off Screen)")
			end
		else
			-- Failed to get head position, keep aimbot disabled for safety
			-- print("MinimalCrash: Aimbot Disabled (No Head Pos)")
		end
	elseif not trigger_activated then
		-- No target OR mouse not fast enough (and trigger didn't fire)
		-- print("MinimalCrash: Aimbot Disabled (No Target or Slow Mouse)")
		enable_aimbot = false -- Ensure aimbot is off
	end

	-- Set aimbot state ONLY if triggerbot didn't activate
	-- If triggerbot did activate, it already set aimbot to 0.
	if not trigger_activated then
		gui.SetValue("aim bot", enable_aimbot and 1 or 0)
	end

	-- Original weapon charge logic (can stay if needed, runs regardless of aimbot/trigger)
	local active_weapon = me:GetPropEntity("m_hActiveWeapon")
	if not active_weapon then
		return
	end

	local ChargedDamage = active_weapon:GetPropFloat("m_flChargedDamage")
	if ChargedDamage then -- Check if ChargedDamage is valid
		local ChargePercentage = (ChargedDamage / 150) * 100
		-- print("MinimalCrash Charge Percentage: " .. ChargePercentage .. "%") -- Optional
	end
end

callbacks.Register("CreateMove", "minimal_crash_test", MinimalCrash_CreateMove)
