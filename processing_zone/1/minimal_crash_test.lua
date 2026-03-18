local mouse_speed_threshold = 20 -- Adjust this value as needed

local function MinimalCrash_CreateMove(cmd)
	-- 1. Get Local Player
	local me = entities.GetLocalPlayer()
	if not me then
		return
	end

	-- Need player entity
	if not me:IsPlayer() then
		return
	end

	-- 2. Check Player Alive
	if not me:IsAlive() then
		return
	end

	-- Aimbot Legitimacy based on Mouse Speed
	local mouse_delta_x = cmd.mousedx or 0
	local mouse_delta_y = cmd.mousedy or 0
	local total_mouse_delta = math.abs(mouse_delta_x) + math.abs(mouse_delta_y)

	if total_mouse_delta < mouse_speed_threshold then
		-- Mouse moving slowly, disable aimbot for legitimacy
		gui.SetValue("aim bot", 0)
		-- print("MinimalCrash: Aimbot Disabled (Slow Mouse)") -- Optional debug print
	else
		-- Mouse moving quickly enough, allow aimbot
		gui.SetValue("aim bot", 1)
		-- print("MinimalCrash: Aimbot Enabled (Fast Mouse)") -- Optional debug print
	end

	--get active weapon
	local active_weapon = me:GetPropEntity("m_hActiveWeapon")
	if not active_weapon then
		return
	end

	--get charge daamge
	local ChargedDamage = active_weapon:GetPropFloat("m_flChargedDamage")
	-- print("MinimalCrash: " .. ChargedDamage) -- Reduced print frequency

	-- Calculate the charge percentage: (Current Damage / Max Damage) * 100
	-- Assuming 150 is the maximum possible damage value representing 100% charge.
	local ChargePercentage = (ChargedDamage / 150) * 100

	-- Optional: Clamp the value to ensure it stays within the 0-100 range,
	-- in case ChargedDamage could potentially be negative or exceed 150.
	-- ChargePercentage = math.max(0, math.min(100, ChargePercentage))

	-- print("MinimalCrash Charge Percentage: " .. ChargePercentage .. "%") -- Reduced print frequency
end

callbacks.Register("CreateMove", "minimal_crash_test", MinimalCrash_CreateMove)
