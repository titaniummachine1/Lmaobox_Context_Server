--[[
    Spawn Location & Respawn Timer
    
    1. Entity ESP: Shows ALL entities with names
    2. On-Screen HUD: Your respawn countdown
    3. World Timers: Countdown at spawn locations for all dead players
]]

local font = draw.CreateFont("Tahoma", 24, 800)
local smallFont = draw.CreateFont("Tahoma", 12, 600)

-- Draw square helper
local function DrawSquare(x, y, size, r, g, b, a)
	draw.Color(r, g, b, a)
	draw.OutlinedRect(x - size, y - size, x + size, y + size)
end

local function OnDraw()
	local me = entities.GetLocalPlayer()
	if not me then
		return
	end

	local curTime = globals.CurTime()
	local myPos = me:GetAbsOrigin()
	local myIndex = me:GetIndex()

	-- 1. ENTITY ESP - Draw ALL entities with names
	local highestIndex = entities.GetHighestEntityIndex()
	for i = 0, highestIndex do
		local ent = entities.GetByIndex(i)
		if ent and ent:IsValid() and not ent:IsDormant() then
			local pos = ent:GetAbsOrigin()
			if pos and (pos - myPos):Length() < 1000 then
				local screenPos = client.WorldToScreen(pos)
				if screenPos then
					local className = ent:GetClass()
					DrawSquare(screenPos[1], screenPos[2], 5, 255, 255, 255, 255)
					draw.SetFont(smallFont)
					draw.Color(255, 255, 255, 255)
					draw.Text(screenPos[1] + 10, screenPos[2], className .. " (" .. i .. ")")
				end
			end
		end
	end

	-- 2. Get respawn data
	local resource = entities.GetPlayerResources()
	if not resource then
		return
	end

	local respawnTimes = resource:GetPropDataTableFloat("m_flNextRespawnTime")
	if not respawnTimes then
		return
	end

	-- 3. ON-SCREEN HUD - Show YOUR respawn time
	local myRespawnTime = respawnTimes[myIndex + 1] or 0
	if myRespawnTime > curTime then
		local timeLeft = myRespawnTime - curTime
		draw.SetFont(font)
		draw.Color(255, 255, 0, 255)
		local text = string.format("RESPAWN IN: %.1f seconds", timeLeft)
		draw.Text(10, 100, text)
	end

	-- 4. World timers for all dead players at spawn locations
	local players = entities.FindByClass("CTFPlayer")
	local spawnTimers = {}

	for _, player in ipairs(players) do
		if player:IsValid() then
			local idx = player:GetIndex()
			local rTime = respawnTimes[idx + 1]

			if rTime and rTime > curTime then
				local timeLeft = rTime - curTime
				local team = player:GetTeamNumber()

				-- Find spawn points
				local spawns = {}
				local spawnClasses = { "CTFTeamSpawn", "info_player_teamspawn", "info_player_start" }
				for _, cls in ipairs(spawnClasses) do
					local found = entities.FindByClass(cls)
					for _, spawn in ipairs(found) do
						if spawn:GetTeamNumber() == team or spawn:GetTeamNumber() == 0 then
							table.insert(spawns, spawn)
						end
					end
				end

				-- Predict nearest spawn
				if #spawns > 0 then
					local pPos = player:GetAbsOrigin()
					local bestSpawn = spawns[1]
					local bestDist = math.huge
					for _, spawn in ipairs(spawns) do
						local dist = (pPos - spawn:GetAbsOrigin()):Length()
						if dist < bestDist then
							bestDist = dist
							bestSpawn = spawn
						end
					end

					local spawnPos = bestSpawn:GetAbsOrigin()
					local key = string.format("%.0f_%.0f", spawnPos.x, spawnPos.y)

					if not spawnTimers[key] then
						spawnTimers[key] = { pos = spawnPos, players = {} }
					end

					table.insert(spawnTimers[key].players, {
						name = player:GetName(),
						time = timeLeft,
						team = team,
					})
				end
			end
		end
	end

	-- Draw spawn timers in world
	for _, data in pairs(spawnTimers) do
		local screenPos = client.WorldToScreen(data.pos)
		if screenPos then
			local yOffset = 0
			for _, p in ipairs(data.players) do
				draw.SetFont(smallFont)
				if p.team == 2 then
					draw.Color(255, 100, 100, 255)
				elseif p.team == 3 then
					draw.Color(100, 150, 255, 255)
				else
					draw.Color(200, 200, 200, 255)
				end

				draw.Text(screenPos[1], screenPos[2] + yOffset, string.format("%s: %.1fs", p.name, p.time))
				yOffset = yOffset + 14
			end
		end
	end
end

callbacks.Register("Draw", "SpawnTimer", OnDraw)

print("Spawn Timer Loaded: Entity ESP + On-Screen HUD + World Timers")
