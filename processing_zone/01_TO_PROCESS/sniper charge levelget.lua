local function MinimalCrash_CreateMove(cmd)
	-- 1. Get Local Player (Raw)
	local me = entities.GetLocalPlayer()
	if not me then
		return
	end -- Need player entity
	if me:IsPlayer() then
		print("MinimalCrash: IsPlayer")
	end

	-- 2. Check Player Alive (using pcall for Lua safety)
	-- This check passed in the full script before the crash point.
	if me:IsAlive() then
		print("MinimalCrash: IsAlive")
	end

	-- 3. Get Active Weapon (Raw) (using pcall for Lua safety)
	-- This check also passed in the full script before the crash point.
	local active_weapon = me:GetPropEntity("m_hActiveWeapon")
	if active_weapon then
		print("MinimalCrash: GetPropEntity")
	end

	-- 4. The Crashing Call
	-- No pcall needed here, as we want to trigger the internal C++ crash.
	-- This is the call identified as causing the crash-to-desktop.
	local charge = active_weapon:GetPropFloat("m_flChargedDamage")
	print("MinimalCrash: " .. charge)

	-- -- This line will likely never be reached due to the CTD.
	print("MinimalCrash: Survived CanCharge call.")
end

callbacks.Register("CreateMove", "minimal_crash_test", MinimalCrash_CreateMove)
