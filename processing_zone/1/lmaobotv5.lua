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
    local Common = require("Lmaobot.Common")
    local Navigation = require("Lmaobot.Navigation")
    local Lib = Common.Lib
    
    local Log = Lib.Utils.Logger.new("Lmaobot")
    Log.Level = 0  -- Set to a higher value for more detailed logging, e.g., 1 for debug logs
    
    local options = {
        drawPath = true,
        drawCurrentNode = true,
        autoPath = true,
    }
    
    local MAX_CACHE_SIZE = 100 -- Adjust as needed

    local currentNodeIndex, currentNodeTicks = 1, 0
    local healthPacks, dispensers, teleporters, resupplyClosets = {}, {}, {}, {}
    local lastHealthSourceCheck, healthSourceCheckInterval = 0, 5 * 66 -- Check every 5 seconds
    local currentTask, taskTimer = "None", Lib.Utils.Timer.new()
    local noNearbyPlayerTime, proximityCheckRadius, noPlayerThreshold = 0, 500, 10 * 66
    local lastCartCheckTime, cartCheckInterval = 0, 1
    local lastKnownCartPos, lastKnownCartTeam = nil, nil
    local justRespawned, respawnTime = false, 0
    local healthThreshold = 125
    local lastCartStatus, lastCartLogTime, cartLogCooldown = nil, 0, 3
    local lastTeleporterCheck, teleporterCheckInterval = 0, 2 * 66
    local lastInvalidGameStateLog = 0
    local lastTaskSwitchTime, taskSwitchCooldown = 0, 3
    local lastEntityLogTime, entityLogCooldown = {}, 5
    local teleporterWaitStart, maxTeleporterWaitTime = 0, 5
    local hasTeleportedSinceRespawn = false
    local lastTeleporterLogTime, teleporterLogInterval = 0, 5
    local lastPosition = Vector3(0, 0, 0)
    local teleportThreshold = 500
    local CART_CHECK_INTERVAL, MIN_OBJECTIVE_DISTANCE = 1, 250
    
    local HEALTH_SOURCE_PRIORITIES = {
        ResupplyCloset = 1,
        Dispenser = 2,
        HealthPack = 3
    }

    local function LoadNavFile()
        local mapFile = engine.GetMapName()
        local navFile = string.gsub(mapFile, ".bsp", ".nav")
        Navigation.LoadFile(navFile)
        Log:Info("Loaded nav file: %s", navFile)
    end

    local function HasTeleported(currentPosition)
        if not hasTeleportedSinceRespawn then return false end
        if (currentPosition - lastPosition):Length() > teleportThreshold then
            lastPosition = currentPosition
            return true
        end
        lastPosition = currentPosition
        return false
    end

    local function ShouldSeekCart()
        local mapName = engine.GetMapName():lower()
        if not (mapName:find("plr_") or mapName:find("pl_")) then
            Log:Debug("Not a payload or payload race map")
            return false
        end
        if gamerules.IsMvM() or gamerules.GetRoundState() ~= 4 then
            Log:Debug("Game not in valid state for cart seeking. MvM: %s, Round State: %d", 
                      tostring(gamerules.IsMvM()), gamerules.GetRoundState())
            return false
        end
        return true
    end
    
    local function OnDraw()
        draw.SetFont(Lib.UI.Fonts.Verdana)
        draw.Color(255, 0, 0, 255)
    
        local me = entities.GetLocalPlayer()
        if not me then return end
    
        local myPos = me:GetAbsOrigin()
        local currentPath = Navigation.GetCurrentPath()
    
        if options.drawPath and currentPath then
            draw.Color(255, 255, 0, 255)
    
            for i = 1, #currentPath - 1 do
                local node1 = currentPath[i]
                local node2 = currentPath[i + 1]
    
                local node1Pos = Vector3(node1.x, node1.y, node1.z)
                local node2Pos = Vector3(node2.x, node2.y, node2.z)
    
                local screenPos1 = client.WorldToScreen(node1Pos)
                local screenPos2 = client.WorldToScreen(node2Pos)
                if screenPos1 and screenPos2 then
                    draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])
                end
            end
        end
    
        if options.drawCurrentNode and currentPath then
            draw.Color(255, 0, 0, 255)
    
            local currentNode = currentPath[currentNodeIndex]

            if currentNode then
                local currentNodePos = Vector3(currentNode.x, currentNode.y, currentNode.z)
                local screenPos = client.WorldToScreen(currentNodePos)
            else
                Log:Warn("Current node is nil")
            end

            if screenPos then
                draw.Text(screenPos[1], screenPos[2], tostring(currentNodeIndex))
            end
        end
    
        -- Draw objective line
        if currentTask == "Objective" and lastKnownCartPos then
            draw.Color(0, 255, 0, 255)
            local cartScreenPos = client.WorldToScreen(lastKnownCartPos)
            local myScreenPos = client.WorldToScreen(myPos)
            if cartScreenPos and myScreenPos then
                draw.Line(myScreenPos[1], myScreenPos[2], cartScreenPos[1], cartScreenPos[2])
            end
        end
    end
    
    local function FindPayloadCart()
        local currentTime = globals.RealTime()
        if currentTime - lastCartCheckTime < cartCheckInterval then
            return lastKnownCartPos, lastKnownCartTeam, lastKnownCartPos and (entities.GetLocalPlayer():GetAbsOrigin() - lastKnownCartPos):Length() or nil
        end
    
        lastCartCheckTime = currentTime
        local payloads = entities.FindByClass("CObjectCartDispenser")
        local me = entities.GetLocalPlayer()
        if not me then 
            Log:Debug("FindPayloadCart: Local player not found")
            return nil, nil, nil 
        end
        
        local myTeam = me:GetTeamNumber()
        local myPos = me:GetAbsOrigin()
        local friendlyCart, enemyCart = nil, nil
        local friendlyDist, enemyDist = math.huge, math.huge
    
        for _, entity in pairs(payloads) do
            if entity and entity:IsValid() then
                local cartPos = entity:GetAbsOrigin()
                local distance = (myPos - cartPos):Length()
                if entity:GetTeamNumber() == myTeam then
                    if distance < friendlyDist then
                        friendlyCart = entity
                        friendlyDist = distance
                    end
                else
                    if distance < enemyDist then
                        enemyCart = entity
                        enemyDist = distance
                    end
                end
            end
        end
    
        local closestCart = friendlyCart or enemyCart
        local closestDistance = friendlyDist < enemyDist and friendlyDist or enemyDist
    
        if closestCart then
            lastKnownCartPos = closestCart:GetAbsOrigin()
            lastKnownCartTeam = closestCart:GetTeamNumber()
            local cartType = lastKnownCartTeam == myTeam and "Friendly" or "Enemy"
            Log:Debug("%s cart found at %s, distance: %.2f", cartType, tostring(lastKnownCartPos), closestDistance)
            return lastKnownCartPos, lastKnownCartTeam, closestDistance
        else
            Log:Debug("No cart found")
            return nil, nil, nil
        end
    end
    
    local function SwitchTask(newTask)
        local currentTime = globals.RealTime()
        if newTask ~= currentTask and currentTime - lastTaskSwitchTime > taskSwitchCooldown then
            Log:Info("Switching task from %s to %s", currentTask, newTask)
            gui.SetValue("follow bot", newTask == "None" and "all players" or "none")
            Navigation.ClearPath()
            currentTask = newTask
            lastTaskSwitchTime = currentTime
        end
    end
    
    local function ArePlayersNearby(myPos)
        local players = entities.FindByClass("CTFPlayer")
        local currentTime = globals.TickCount()
        for _, player in ipairs(players) do
            if player:IsAlive() and player:GetIndex() ~= entities.GetLocalPlayer():GetIndex() then
                local playerPos = player:GetAbsOrigin()
                if (myPos - playerPos):Length() <= proximityCheckRadius then
                    -- Check if the player has moved recently
                    local lastPos = player:GetPropVector("m_vecOrigin")
                    local lastMoveTime = player:GetPropFloat("m_flLastMovementTime")
                    if lastPos ~= playerPos or (currentTime - lastMoveTime) < (5 * 66) then  -- 5 seconds of idle time
                        return true
                    end
                end
            end
        end
        return false
    end
    
    local function OnRespawn()
        Log:Info("Player respawned, enabling follow mode")
        gui.SetValue("follow bot", "all players")
        currentTask, justRespawned, respawnTime = "None", false, globals.RealTime()
        noNearbyPlayerTime, lastPosition, lastTeleporterPosition = 0, nil, nil
        hasTeleportedSinceRespawn = false
    end
    
    local function FindNearestFriendlyDispenser()
        local me = entities.GetLocalPlayer()
        if not me then return nil end
    
        local myTeam = me:GetTeamNumber()
        local myPos = me:GetAbsOrigin()
        local closestDispenser = nil
        local closestDist = math.huge
    
        for _, entity in pairs(entities.FindByClass("CObjectDispenser")) do
            if entity and entity:IsValid() and entity:GetTeamNumber() == myTeam then
                local dispenserPos = entity:GetAbsOrigin()
                local dist = (myPos - dispenserPos):Length()
                if dist < closestDist then
                    closestDispenser = dispenserPos
                    closestDist = dist
                end
            end
        end
    
        return closestDispenser, closestDist
    end
    

    local function FindNearestHealthSource()
        local me = entities.GetLocalPlayer()
        if not me then return nil, nil, nil end
    
        local myPos = me:GetAbsOrigin()
        local myTeam = me:GetTeamNumber()
    
        local closestCabinet = nil
        local closestCabinetDist = math.huge
        local closestOther = nil
        local closestOtherType = nil
        local closestOtherDist = math.huge
    
        -- Check resupply closets (health cabinets)
        for _, entity in pairs(entities.FindByClass("func_regenerate")) do
            if entity:GetTeamNumber() == myTeam or entity:GetTeamNumber() == 0 then
                local pos = entity:GetAbsOrigin()
                local dist = (myPos - pos):Length()
                if dist < closestCabinetDist then
                    closestCabinet = pos
                    closestCabinetDist = dist
                end
            end
        end
    
        -- If a cabinet is found within 1000 units, prefer it
        if closestCabinet and closestCabinetDist <= 1000 then
            return closestCabinet, "ResupplyCloset", closestCabinetDist
        end
    
        -- Check health packs and dispensers
        for _, pos in pairs(healthPacks) do
            local dist = (myPos - pos):Length()
            if dist < closestOtherDist then
                closestOther = pos
                closestOtherType = "HealthPack"
                closestOtherDist = dist
            end
        end
    
        local dispenserPos, dispenserDist = FindNearestFriendlyDispenser()
        if dispenserPos and dispenserDist < closestOtherDist then
            closestOther = dispenserPos
            closestOtherType = "Dispenser"
            closestOtherDist = dispenserDist
        end
    
        -- If no cabinet is found nearby, return the closest other health source
        if closestOther then
            return closestOther, closestOtherType, closestOtherDist
        end
    
        -- If a cabinet was found but it's far away, return it as a last resort
        if closestCabinet then
            return closestCabinet, "ResupplyCloset", closestCabinetDist
        end
    
        return nil, nil, nil
    end
    
    local function UpdateHealthSources()
        local currentTime = globals.TickCount()
        if currentTime - lastHealthSourceCheck < healthSourceCheckInterval then
            return
        end
    
        lastHealthSourceCheck = currentTime
        local me = entities.GetLocalPlayer()
        if not me then return end
        local myTeam = me:GetTeamNumber()
    
        -- Update health packs
        for _, entity in pairs(entities.FindByClass("item_healthkit_*")) do
            local pos = entity:GetAbsOrigin()
            healthPacks[entity:GetIndex()] = pos
            Log:Debug("Health pack found at %s", tostring(pos))
        end
    
        -- Update friendly dispensers
        dispensers = {}
        for _, entity in pairs(entities.FindByClass("CObjectDispenser")) do
            if entity:GetTeamNumber() == myTeam then
                local pos = entity:GetAbsOrigin()
                dispensers[entity:GetIndex()] = pos
                Log:Debug("Friendly dispenser found at %s", tostring(pos))
            end
        end
    
        -- Update friendly or neutral resupply closets
        resupplyClosets = {}
        for _, entity in pairs(entities.FindByClass("func_regenerate")) do
            if entity:GetTeamNumber() == myTeam or entity:GetTeamNumber() == 0 then
                local pos = entity:GetAbsOrigin()
                resupplyClosets[entity:GetIndex()] = pos
                Log:Debug("Friendly resupply closet found at %s", tostring(pos))
            end
        end
    end
    
    local function ClearInvalidHealthSources()
        for index, pos in pairs(healthPacks) do
            local entity = entities.GetByIndex(index)
            if not entity or not entity:IsValid() then
                healthPacks[index] = nil
                Log:Debug("Removed invalid healthpack at %s", tostring(pos))
            end
        end
        for index, pos in pairs(dispensers) do
            local entity = entities.GetByIndex(index)
            if not entity or not entity:IsValid() then
                dispensers[index] = nil
                Log:Debug("Removed invalid dispenser at %s", tostring(pos))
            end
        end
    end

    -- Modified function to check if a teleporter is valid, friendly, and an entrance
    local function IsValidFriendlyTeleporterEntrance(teleporter)
        local me = entities.GetLocalPlayer()
        if not me then return false end
        return teleporter and 
            teleporter:IsValid() and 
            teleporter:GetTeamNumber() == me:GetTeamNumber() and
            teleporter:GetPropInt("m_iObjectMode") == 0 and
            teleporter:GetPropInt("m_iState") == 2
    end

    -- Modified FindNearestTeleporter function
    local function FindNearestTeleporterEntrance()
        local me = entities.GetLocalPlayer()
        if not me then return nil end
    
        local myPos = me:GetAbsOrigin()
        local closestTeleporter = nil
        local closestDist = math.huge
    
        for _, entity in pairs(entities.FindByClass("CObjectTeleporter")) do
            if IsValidFriendlyTeleporterEntrance(entity) then
                local teleporterPos = entity:GetAbsOrigin()
                local dist = (myPos - teleporterPos):Length()
                if dist < closestDist then
                    closestTeleporter = entity
                    closestDist = dist
                end
            end
        end
    
        if closestTeleporter then
            --Log:Debug("Found nearest teleporter entrance at distance: %.2f", closestDist)
        else
            --Log:Debug("No valid teleporter entrances found")
        end
    
        return closestTeleporter, closestDist
    end

    local function HandleTeleporter(userCmd, currentTime, currentPosition)
        if hasTeleportedSinceRespawn then
            return
        end
    
        local teleporter, teleporterDist = FindNearestTeleporterEntrance()
        
        if not teleporter then
            if currentTask == "Teleporter" then
                Log:Info("No valid teleporter found, switching to default task")
                SwitchTask("None")
            end
            return
        end
        
        if currentTask ~= "Teleporter" then
            Log:Info("Seeking friendly teleporter entrance, distance: %.2f", teleporterDist)
            SwitchTask("Teleporter")
            local startNode = Navigation.GetClosestNode(currentPosition)
            local teleporterNode = Navigation.GetClosestNode(teleporter:GetAbsOrigin())
            if startNode and teleporterNode then
                if Navigation.FindPath(startNode, teleporterNode) then
                    currentNodeIndex = #Navigation.GetCurrentPath()
                else
                    Log:Warn("Failed to find path to teleporter entrance")
                    SwitchTask("None")
                end
            else
                Log:Warn("Failed to find valid nodes for teleporter pathing")
                SwitchTask("None")
            end
        elseif teleporterDist < 0 then
            userCmd.forwardmove = 0
            userCmd.sidemove = 0
            gui.SetValue("no push", 1)
            
            if teleporterWaitStart == 0 then
                teleporterWaitStart = currentTime
                Log:Info("Reached teleporter, waiting to be teleported")
            elseif currentTime - teleporterWaitStart > maxTeleporterWaitTime then
                Log:Info("Teleporter wait time exceeded, switching to default task")
                SwitchTask("None")
                gui.SetValue("no push", 0)
                hasTeleportedSinceRespawn = true
            else
                -- Check for sudden position change (teleportation)
                if lastPosition and currentPosition and teleportationDetectionThreshold then
                    local distance = (currentPosition - lastPosition):Length()
                    if distance > teleportationDetectionThreshold then
                        Log:Info("Teleportation detected. Old pos: %s, New pos: %s", tostring(lastPosition), tostring(currentPosition))
                        SwitchTask("None")
                        gui.SetValue("no push", 0)
                        hasTeleportedSinceRespawn = true
                        Navigation.ClearPath()
                    end
                else
                    -- Log a warning if any of the required variables are nil
                    if not lastPosition then
                        Log:Warn("lastPosition is nil")
                    end
                    if not currentPosition then
                        Log:Warn("currentPosition is nil")
                    end
                    if not teleportationDetectionThreshold then
                        Log:Warn("teleportationDetectionThreshold is nil")
                    end
                end
            end
        else
            local currentPath = Navigation.GetCurrentPath()
            if currentPath and #currentPath > 0 and currentNodeIndex > 0 and currentNodeIndex <= #currentPath then
                local currentNode = currentPath[currentNodeIndex]
                if currentNode then
                    local currentNodePos = Vector3(currentNode.x, currentNode.y, currentNode.z)
                    Lib.TF2.Helpers.WalkTo(userCmd, entities.GetLocalPlayer(), currentNodePos)
                else
                    Log:Warn("Current node is nil, clearing path and switching to default task")
                    Navigation.ClearPath()
                    SwitchTask("None")
                end
            else
                Log:Warn("Lost path to teleporter")
                SwitchTask("None")
            end
        end
    
        lastPosition = currentPosition
    end

    -- Modified UpdateTeleporters function to reduce log spam
    local function UpdateTeleporters()
        local currentTime = globals.TickCount()
        if currentTime - lastTeleporterCheck < teleporterCheckInterval then
            return
        end

        lastTeleporterCheck = currentTime
        teleporters = {}

        for _, entity in pairs(entities.FindByClass("CObjectTeleporter")) do
            if IsValidFriendlyTeleporterEntrance(entity) then
                local teleporterPos = entity:GetAbsOrigin()
                teleporters[entity:GetIndex()] = teleporterPos
                
                -- Log only if enough time has passed since the last log
                if currentTime - lastTeleporterLogTime > teleporterLogInterval * 66 then  -- Convert seconds to ticks
                    Log:Debug("Valid friendly teleporter entrance found at %s", tostring(teleporterPos))
                    lastTeleporterLogTime = currentTime
                end
            end
        end
    end

    -- Function to clear old data
    local function clearOldData()
        -- Clear health packs, dispensers, etc. that haven't been seen in a while
        local currentTime = globals.TickCount()
        for index, lastSeenTime in pairs(lastEntityLogTime) do
            if currentTime - lastSeenTime > 60 * 66 then -- 60 seconds
                healthPacks[index] = nil
                dispensers[index] = nil
                teleporters[index] = nil
                resupplyClosets[index] = nil
                lastEntityLogTime[index] = nil
            end
        end

        -- Limit navigation mesh cache size
        local cacheSize = 0
        for _ in pairs(navigation_mesh_cache) do
            cacheSize = cacheSize + 1
        end
        if cacheSize > MAX_CACHE_SIZE then
            local oldestKey, oldestTime = nil, math.huge
            for key, cacheEntry in pairs(navigation_mesh_cache) do
                if cacheEntry.lastUsed < oldestTime then
                    oldestKey, oldestTime = key, cacheEntry.lastUsed
                end
            end
            if oldestKey then
                navigation_mesh_cache[oldestKey] = nil
            end
        end

        -- Clear current path if not in use
        if currentTask == "None" then
            Navigation.ClearPath()
        end

        -- Force garbage collection
        collectgarbage("collect")
    end

    local function OnCreateMove(userCmd)
        -- Call clearOldData periodically, e.g., in OnCreateMove
        if globals.TickCount() % (60 * 66) == 0 then -- Every 60 seconds
            clearOldData()
        end

        if not options.autoPath then return end
    
        local me = entities.GetLocalPlayer()
        if not me or not me:IsAlive() then
            Navigation.ClearPath()
            return
        end
    
        local currentTime = globals.RealTime()
        local currentPosition = me:GetAbsOrigin()
    
        UpdateHealthSources()
        UpdateTeleporters()
    
        -- Cart-seeking logic with inline path recalculation
        if (noNearbyPlayerTime >= noPlayerThreshold or gui.GetValue("follow bot") == "none") and currentTask == "None" then
            local mapName = engine.GetMapName():lower()
            if mapName:find("plr_") or mapName:find("pl_") then
                if currentTime - lastCartCheckTime > CART_CHECK_INTERVAL then
                    lastCartCheckTime = currentTime
    
                    if not gamerules.IsMvM() and gamerules.GetRoundState() == 4 then
                        local cartPos, cartTeam, distToCart = FindPayloadCart()
                        Log:Debug("Cart check - Position: %s, Team: %s, Distance: %.2f", 
                                  tostring(cartPos), tostring(cartTeam), distToCart or -1)
                        
                        if cartPos then
                            if distToCart > MIN_OBJECTIVE_DISTANCE then
                                -- Inline cart path recalculation
                                if currentTask ~= "Objective" or currentTime - lastPathRecalculationTime > pathRecalculationInterval then
                                    Log:Info("Recalculating path to cart")
                                    local startNode = Navigation.GetClosestNode(currentPosition)
                                    local cartNode = Navigation.GetClosestNode(cartPos)
                                    if startNode and cartNode then
                                        if Navigation.FindPath(startNode, cartNode) then
                                            currentNodeIndex = #Navigation.GetCurrentPath()
                                            Log:Info("New path to cart calculated")
                                            lastPathRecalculationTime = currentTime
                                        else
                                            Log:Warn("Failed to find new path to cart")
                                        end
                                    else
                                        Log:Warn("Failed to find valid nodes for cart pathing")
                                    end
                                end
                                SwitchTask("Objective")
                            else
                                Log:Debug("Cart is close (%.2f units), staying near", distToCart)
                                SwitchTask("Objective")
                            end
                        else
                            Log:Debug("No cart found to seek")
                        end
                    else
                        Log:Debug("Game not in valid state for cart seeking. MvM: %s, Round State: %d", 
                                  tostring(gamerules.IsMvM()), gamerules.GetRoundState())
                    end
                end
            else
                Log:Debug("Not a payload or payload race map")
            end
        end
    
        if justRespawned then
            justRespawned = false
            hasTeleportedSinceRespawn = false
            return
        end
    
        if lastPosition and currentTime - lastTeleporterCheck >= teleporterCheckInterval then
            lastTeleporterCheck = currentTime
            local distance = (currentPosition - lastPosition):Length()
            if distance > teleportThreshold then
                Log:Info("Teleportation detected in OnCreateMove. Old pos: %s, New pos: %s, Distance: %.2f", 
                         tostring(lastPosition), tostring(currentPosition), distance)
                hasTeleportedSinceRespawn = true
                SwitchTask("None")
                gui.SetValue("no push", 0)
                Navigation.ClearPath()
            end
        end
    
        if respawnTime and currentTime - respawnTime <= 20 and not hasTeleportedSinceRespawn then
            HandleTeleporter(userCmd, currentTime, currentPosition)
        end
    
        if globals.TickCount() % (10 * 66) == 0 then
            ClearInvalidHealthSources()
        end
    
        if ArePlayersNearby(currentPosition) then
            if noNearbyPlayerTime >= noPlayerThreshold then
                Log:Info("Players nearby again after %d seconds", math.floor(noNearbyPlayerTime / 66))
                if gui.GetValue("follow bot") == "none" then
                    gui.SetValue("follow bot", "all players")
                    Log:Info("Re-enabled follow bot")
                end
            end
            noNearbyPlayerTime = 0
        else
            noNearbyPlayerTime = noNearbyPlayerTime + 1
            if noNearbyPlayerTime == noPlayerThreshold then
                Log:Debug("No players nearby for %d seconds", math.floor(noPlayerThreshold / 66))
            end
        end
    
        local cartPos, cartTeam, distToCart = FindPayloadCart()
        local currentCartStatus = nil
    
        if cartPos then
            if distToCart <= 250 then
                currentCartStatus = "near"
            else
                currentCartStatus = "far"
            end
        else
            currentCartStatus = "not_found"
        end
    
        if currentCartStatus ~= lastCartStatus and currentTime - lastCartLogTime > cartLogCooldown then
            if currentCartStatus == "near" then
                Log:Info("Cart nearby, distance: %.2f. Switching to player follow mode", distToCart)
                SwitchTask("None")
            elseif currentCartStatus == "far" then
                Log:Debug("Cart detected, distance: %.2f", distToCart)
            else
                Log:Debug("No cart found")
            end
            lastCartStatus = currentCartStatus
            lastCartLogTime = currentTime
        end
    
        -- Modified cart-seeking logic
        if (noNearbyPlayerTime >= noPlayerThreshold or gui.GetValue("follow bot") == "none") and currentTask == "None" then
            local mapName = engine.GetMapName():lower()
            --Log:Debug("Current map: %s", mapName)
            
            if mapName:find("plr_") or mapName:find("pl_") then
                if currentTime - lastCartCheckTime > cartCheckInterval then
                    lastCartCheckTime = currentTime
                    
                    if not gamerules.IsMvM() and gamerules.GetRoundState() == 4 then
                        local cartPos, cartTeam, distToCart = FindPayloadCart()
                        Log:Debug("Cart check - Position: %s, Team: %s, Distance: %.2f", 
                                tostring(cartPos), tostring(cartTeam), distToCart or -1)
                        
                        if cartPos then
                            if distToCart > minObjectiveDistance then
                                local cartType = cartTeam == me:GetTeamNumber() and "friendly" or "enemy"
                                Log:Info("Seeking %s objective cart", cartType)
                                local startNode = Navigation.GetClosestNode(currentPosition)
                                local cartNode = Navigation.GetClosestNode(cartPos)
                                if startNode and cartNode then
                                    if Navigation.FindPath(startNode, cartNode) then
                                        currentNodeIndex = #Navigation.GetCurrentPath()
                                        SwitchTask("Objective")
                                        Log:Info("Path found to cart, switched to Objective task")
                                    else
                                        Log:Warn("Failed to find path to cart")
                                    end
                                else
                                    Log:Warn("Failed to find valid nodes for cart pathing")
                                end
                            else
                                Log:Debug("Cart is too close (%.2f units), not seeking", distToCart)
                            end
                        else
                            Log:Debug("No cart found to seek")
                        end
                    else
                        Log:Debug("Game not in valid state for cart seeking. MvM: %s, Round State: %d", 
                                tostring(gamerules.IsMvM()), gamerules.GetRoundState())
                    end
                end
            else
                Log:Debug("Not a payload or payload race map")
            end
        else
            --Log:Debug("Not seeking cart. No nearby players: %s, Current task: %s", 
                    --tostring(noNearbyPlayerTime >= noPlayerThreshold), currentTask)
        end
    
        if taskTimer:Run(3) then
            Log:Debug("Checking health. Current health: %d", me:GetHealth())
            if me:GetHealth() < healthThreshold then
                local healthSource, sourceType, sourceDist = FindNearestHealthSource()
                if healthSource then
                    Log:Info("Seeking %s for health, distance: %.2f", sourceType, sourceDist)
                    if currentTask ~= "Health" then
                        SwitchTask("Health")
                    end
                    local startNode = Navigation.GetClosestNode(currentPosition)
                    local healthNode = Navigation.GetClosestNode(healthSource)
                    if startNode and healthNode then
                        if Navigation.FindPath(startNode, healthNode) then
                            currentNodeIndex = #Navigation.GetCurrentPath()
                        else
                            Log:Warn("Failed to find path to health source, staying put")
                            SwitchTask("None")
                        end
                    else
                        Log:Warn("Failed to find valid nodes for pathing to health source")
                        SwitchTask("None")
                    end
                else
                    Log:Warn("No health source found")
                end
            elseif currentTask == "Health" and me:GetHealth() >= 100 then
                Log:Info("Health restored, switching back to default task")
                SwitchTask("None")
            end
        end
    
        if currentTask == "Health" or currentTask == "Objective" or currentTask == "Teleporter" then
            local currentPosition = me:GetAbsOrigin()
            
            if HasTeleported(currentPosition) then
                Log:Info("Teleportation detected, resetting navigation")
                Navigation.ClearPath()
                currentNodeIndex = 1
                currentNodeTicks = 0
                SwitchTask("None")
            else
                local currentPath = Navigation.GetCurrentPath()
                if currentPath and #currentPath > 0 and currentNodeIndex > 0 and currentNodeIndex <= #currentPath then
                    local currentNode = currentPath[currentNodeIndex]
                    if currentNode then
                        local currentNodePos = Vector3(currentNode.x, currentNode.y, currentNode.z)
                
                        local dist = (currentPosition - currentNodePos):Length()
                        if dist < 22 then
                            currentNodeTicks = 0
                            currentNodeIndex = currentNodeIndex - 1
                            if currentNodeIndex < 1 then
                                Log:Info("Reached %s", currentTask == "Objective" and "objective" or (currentTask == "Teleporter" and "teleporter entrance" or "health source"))
                                SwitchTask("None")
                            end
                        else
                            currentNodeTicks = currentNodeTicks + 1
                            Lib.TF2.Helpers.WalkTo(userCmd, me, currentNodePos)
                
                            if currentNodeTicks == 100 then
                                Log:Debug("Stuck for 100 ticks, attempting to jump")
                                userCmd.buttons = userCmd.buttons | IN_JUMP
                            elseif currentNodeTicks == 150 then
                                Log:Warn("Stuck on node for 150 ticks, removing connection and repathing...")
                                if currentNodeIndex > 1 then
                                    Navigation.RemoveConnection(currentNode, currentPath[currentNodeIndex - 1])
                                end
                                Navigation.ClearPath()
                                currentNodeTicks = 0
                                SwitchTask("None")
                            end
                        end
                    else
                        Log:Warn("Current node is nil, clearing path and switching to default task")
                        Navigation.ClearPath()
                        SwitchTask("None")
                    end
                else
                    local closestNode = nil
                    if currentTask == "Health" then
                        local healthSource, _ = FindNearestHealthSource()
                        if healthSource then
                            closestNode = Navigation.GetClosestNode(healthSource)
                        end
                    elseif currentTask == "Objective" then
                        local cartPos, _ = FindPayloadCart()
                        if cartPos then
                            closestNode = Navigation.GetClosestNode(cartPos)
                        end
                    elseif currentTask == "Teleporter" then
                        local teleporter, _ = FindNearestTeleporterEntrance()
                        if teleporter then
                            closestNode = Navigation.GetClosestNode(teleporter:GetAbsOrigin())
                        end
                    end
            
                    if closestNode then
                        Log:Info("Finding path to %s at node %d", currentTask, closestNode.id)
                        local startNode = Navigation.GetClosestNode(currentPosition)
                        if Navigation.FindPath(startNode, closestNode) then
                            currentNodeIndex = #Navigation.GetCurrentPath()
                        else
                            Log:Warn("Failed to find path to %s, switching to default task", currentTask)
                            SwitchTask("None")
                        end
                    else
                        Log:Warn("No valid target for %s, switching to default task", currentTask)
                        SwitchTask("None")
                    end
                end
            end
        end
    end
    
    local function OnDrawModel(ctx)
        local currentTime = globals.RealTime()
        local modelName = ctx:GetModelName()
        
        -- Early return if the model name doesn't match any of our interests
        if not (modelName:find("medkit") or modelName:find("dispenser") or modelName:find("teleporter") or modelName:find("resupply_locker")) then
            return
        end
    
        local entity = ctx:GetEntity()
        if not entity or not entity:IsValid() then
            -- Log:Debug("OnDrawModel: Invalid entity for model %s", modelName)
            return
        end
    
        local entityIndex = entity:GetIndex()
    
        local function logNewEntity(entityType, pos)
            if not lastEntityLogTime[entityIndex] or currentTime - lastEntityLogTime[entityIndex] > entityLogCooldown then
                Log:Debug("New %s found at %s", entityType, tostring(pos))
                lastEntityLogTime[entityIndex] = currentTime
            end
        end
    
        local pos = entity:GetAbsOrigin()
        if not pos then
            -- Log:Debug("OnDrawModel: Unable to get position for entity %d", entityIndex)
            return
        end
    
        if modelName:find("medkit") then
            if not healthPacks[entityIndex] then
                healthPacks[entityIndex] = pos
                logNewEntity("healthpack", pos)
            end
        elseif modelName:find("dispenser") then
            if not dispensers[entityIndex] then
                dispensers[entityIndex] = pos
                logNewEntity("dispenser", pos)
            end
        elseif modelName:find("teleporter") then
            if not teleporters[entityIndex] then
                teleporters[entityIndex] = pos
                logNewEntity("teleporter", pos)
            end
        elseif modelName:find("resupply_locker") then
            if not resupplyClosets[entityIndex] then
                resupplyClosets[entityIndex] = pos
                logNewEntity("resupply closet", pos)
            end
        end
    end
    
    local function OnGameEvent(event)
        if event:GetName() == "game_newmap" then
            Log:Info("New map detected: %s, reloading nav file...", engine.GetMapName())
            healthPacks, dispensers, lastKnownCartPos, lastKnownCartTeam = {}, {}, nil, nil
            LoadNavFile()
        elseif event:GetName() == "player_spawn" then
            local player = entities.GetByUserID(event:GetInt("userid"))
            if player == entities.GetLocalPlayer() then
                OnRespawn()
            end
        end
    end
    
    local function UnregisterCallbacks()
        local callbacks_to_unregister = {"Draw", "CreateMove", "DrawModel", "FireGameEvent"}
        for _, callback in ipairs(callbacks_to_unregister) do
            callbacks.Unregister(callback, "LNX.Lmaobot." .. callback)
        end
    end
    
    local function RegisterCallbacks()
        callbacks.Register("Draw", "LNX.Lmaobot.Draw", OnDraw)
        callbacks.Register("CreateMove", "LNX.Lmaobot.CreateMove", OnCreateMove)
        callbacks.Register("DrawModel", "LNX.Lmaobot.DrawModel", OnDrawModel)
        callbacks.Register("FireGameEvent", "LNX.Lmaobot.FireGameEvent", OnGameEvent)
    end
    
    UnregisterCallbacks()
    RegisterCallbacks()
    LoadNavFile()
    Log:Info("Navigation loaded!")
    end)
__bundle_register("Lmaobot.Navigation", function(require, _LOADED, __bundle_register, __bundle_modules)
---@alias Connection { count: integer, connections: integer[] }
---@alias Node { x: number, y: number, z: number, id: integer, c: { [1]: Connection, [2]: Connection, [3]: Connection, [4]: Connection } }

local Common = require("Lmaobot.Common")
local SourceNav = require("Lmaobot.SourceNav")
local AStar = require("Lmaobot.A-Star")
local Lib, Log = Common.Lib, Common.Log

local FS = Lib.Utils.FileSystem

local function DistTo(a, b)
    return math.sqrt((a.x - b.x) ^ 2 + (a.y - b.y) ^ 2 + (a.z - b.z) ^ 2)
end

---@class Pathfinding
local Navigation = {}

---@type Node[]
local Nodes = {}

---@type Node[]|nil
local CurrentPath = nil

---@param nodes Node[]
function Navigation.SetNodes(nodes)
    Nodes = nodes
end

---@return Node[]
function Navigation.GetNodes()
    return Nodes
end

---@return Node[]|nil
---@return Node[]|nil
function Navigation.GetCurrentPath()
    return CurrentPath
end

function Navigation.ClearPath()
    CurrentPath = nil
end

---@param id integer
---@return Node
function Navigation.GetNodeByID(id)
    return Nodes[id]
end

-- Removes the connection between two nodes (if it exists)
function Navigation.RemoveConnection(nodeA, nodeB)
    for dir = 1, 4 do
		local conDir = nodeA.c[dir]
        for i, con in pairs(conDir.connections) do
            if con == nodeB.id then
                print("Removing connection between " .. nodeA.id .. " and " .. nodeB.id)
                table.remove(conDir.connections, i)
                conDir.count = conDir.count - 1
                break
            end
        end
	end
end

---@param navFile string
function Navigation.LoadFile(navFile)
    -- Read nav file
    local rawNavData = FS.Read("tf/" .. navFile)
    assert(rawNavData, "Failed to read nav file: " .. navFile)

    -- Parse nav file
    local navData = SourceNav.parse(rawNavData)
    Log:Info("Parsed %d areas", #navData.areas)

    -- Convert nav data to usable format
    local navNodes = {}
    for _, area in ipairs(navData.areas) do
        local cX = (area.north_west.x + area.south_east.x) // 2
        local cY = (area.north_west.y + area.south_east.y) // 2
        local cZ = (area.north_west.z + area.south_east.z) // 2

        navNodes[area.id] = { x = cX, y = cY, z = cZ, id = area.id, c = area.connections }
    end

    Navigation.SetNodes(navNodes)
end

---@param pos Vector3|{ x:number, y:number, z:number }
---@return Node
function Navigation.GetClosestNode(pos)
    local closestNode = nil
    local closestDist = math.huge

    for _, node in pairs(Nodes) do
        local dist = DistTo(node, pos)
        if dist < closestDist then
            closestNode = node
            closestDist = dist
        end
    end

    return closestNode
end

-- Returns all adjacent nodes of the given node
---@param node Node
---@param nodes Node[]
local function GetAdjacentNodes(node, nodes)
	local adjacentNodes = {}

	for dir = 1, 4 do
		local conDir = node.c[dir]
        for _, con in pairs(conDir.connections) do
            local conNode = nodes[con]
            if conNode and node.z + 70 > conNode.z then
                table.insert(adjacentNodes, conNode)
            end
        end
	end

	return adjacentNodes
end

---@param startNode Node
---@param goalNode Node
function Navigation.FindPath(startNode, goalNode)
    if not startNode then
        Log:Warn("Invalid start node!")
        return false
    end

    if not goalNode then
        Log:Warn("Invalid goal node!")
        return false
    end

    CurrentPath = AStar.Path(startNode, goalNode, Nodes, GetAdjacentNodes)
    if not CurrentPath then
        Log:Error("Failed to find path from %d to %d!", startNode.id, goalNode.id)
        return false
    end
    return true
end

return Navigation

end)
__bundle_register("Lmaobot.A-Star", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
	A-Star Algorithm for Lmaobox
	Credits: github.com/GlorifiedPig/Luafinding
]]

local Heap = require("Lmaobot.Heap")

---@alias PathNode { id : integer, x : number, y : number, z : number }

---@class AStar
local AStar = {}

local function HeuristicCostEstimate(nodeA, nodeB)
	return math.sqrt((nodeB.x - nodeA.x) ^ 2 + (nodeB.y - nodeA.y) ^ 2 + (nodeB.z - nodeA.z) ^ 2)
end

local function ReconstructPath(current, previous)
	local path = { current }
	while previous[current] do
		current = previous[current]
		table.insert(path, current)
	end

	return path
end

---@param start PathNode
---@param goal PathNode
---@param nodes PathNode[]
---@param adjacentFun fun(node : PathNode, nodes : PathNode[]) : PathNode[]
---@return PathNode[]|nil
function AStar.Path(start, goal, nodes, adjacentFun)
	local openSet, closedSet = Heap.new(), {}
	local gScore, fScore = {}, {}
	gScore[start] = 0
	fScore[start] = HeuristicCostEstimate(start, goal)

	openSet.Compare = function(a, b) return fScore[a] < fScore[b] end
	openSet:push(start)

	local previous = {}
	while not openSet:empty() do
		---@type PathNode
		local current = openSet:pop()

		if not closedSet[current] then

			-- Found the goal
			if current.id == goal.id then
				openSet:clear()
				return ReconstructPath(current, previous)
			end

			closedSet[current] = true

			-- Traverse adjacent nodes
			local adjacentNodes = adjacentFun(current, nodes)
			for i = 1, #adjacentNodes do
				local neighbor = adjacentNodes[i]
				if not closedSet[neighbor] then
					local tentativeGScore = gScore[current] + HeuristicCostEstimate(current, neighbor)

					local neighborGScore = gScore[neighbor]
					if not neighborGScore or tentativeGScore < neighborGScore then
						gScore[neighbor] = tentativeGScore
						fScore[neighbor] = tentativeGScore + HeuristicCostEstimate(neighbor, goal)
						previous[neighbor] = current
						openSet:push(neighbor)
					end
				end
			end
		end
	end

	return nil
end

return AStar

end)
__bundle_register("Lmaobot.Heap", function(require, _LOADED, __bundle_register, __bundle_modules)
--[[
    Heap implementation in Lua
    Credits: github.com/GlorifiedPig/Luafinding
]]

local function findLowest(a, b)return a < b end

---@class Heap
local Heap = {
    _data = {},
    _size = 0,
    Compare = findLowest,
}
Heap.__index = Heap
setmetatable(Heap, Heap)

---@param compare? fun(a: any, b: any): boolean
---@return Heap
function Heap.new(compare)
    local self = setmetatable({}, Heap)
    self._data = {}
    self.Compare = compare or findLowest
    self._size = 0

    return self
end

---@param heap Heap
---@param index integer
local function sortUp(heap, index)
    if index <= 1 then return end
    local pIndex = index % 2 == 0 and index / 2 or (index - 1) / 2

    if not heap.Compare(heap._data[pIndex], heap._data[index]) then
        heap._data[pIndex], heap._data[index] = heap._data[index], heap._data[pIndex]
        sortUp(heap, pIndex)
    end
end

---@param heap Heap
---@param index integer
local function sortDown(heap, index)
    local leftIndex, rightIndex, minIndex
    leftIndex = index * 2
    rightIndex = leftIndex + 1
    
    if rightIndex > heap._size then
        if leftIndex > heap._size then
            return
        else
            minIndex = leftIndex
        end
    else
        if heap.Compare(heap._data[leftIndex], heap._data[rightIndex]) then
            minIndex = leftIndex
        else
            minIndex = rightIndex
        end
    end

    if not heap.Compare(heap._data[index], heap._data[minIndex]) then
        heap._data[index], heap._data[minIndex] = heap._data[minIndex], heap._data[index]
        sortDown(heap, minIndex)
    end
end

function Heap:empty()
    return self._size == 0
end

function Heap:clear()
    self._data, self._size, self.Compare = {}, 0, self.Compare or findLowest
    return self
end

function Heap:push(item)
    if item then
        self._size = self._size + 1
        self._data[self._size] = item
        sortUp(self, self._size)
    end

    return self
end

function Heap:pop()
    local root
    if self._size > 0 then
        root = self._data[1]
        self._data[1] = self._data[self._size]
        self._data[self._size] = nil
        self._size = self._size - 1
        if self._size > 1 then
            sortDown(self, 1)
        end
    end

    return root
end

return Heap

end)
__bundle_register("Lmaobot.SourceNav", function(require, _LOADED, __bundle_register, __bundle_modules)
-- author : https://github.com/sapphyrus
-- ported to tf2 by moonverse

local unpack = table.unpack
local struct = {
    unpack = string.unpack,
    pack = string.pack
}

local struct_buffer_mt = {
    __index = {
        seek = function(self, seek_val, seek_mode)
            if seek_mode == nil or seek_mode == "CUR" then
                self.offset = self.offset + seek_val
            elseif seek_mode == "END" then
                self.offset = self.len + seek_val
            elseif seek_mode == "SET" then
                self.offset = seek_val
            end
        end,
        unpack = function(self, format_str)
            local unpacked = { struct.unpack(format_str, self.raw, self.offset) }

            if self.size_cache[format_str] == nil then
                self.size_cache[format_str] = struct.pack(format_str, unpack(unpacked)):len()
            end
            self.offset = self.offset + self.size_cache[format_str]

            return unpack(unpacked)
        end,
        unpack_vec = function(self)
            local x, y, z = self:unpack("fff")
            return {
                x = x,
                y = y,
                z = z
            }
        end
    }
}

local function struct_buffer(raw)
    return setmetatable({
        raw = raw,
        len = raw:len(),
        size_cache = {},
        offset = 1
    }, struct_buffer_mt)
end

-- cache
local navigation_mesh_cache = {}

-- use checksum so we dont have to keep the whole thing in memory
local function crc32(s, lt)
    -- return crc32 checksum of string as an integer
    -- use lookup table lt if provided or create one on the fly
    -- if lt is empty, it is initialized.
    lt = lt or {}
    local b, crc, mask
    if not lt[1] then -- setup table
        for i = 1, 256 do
            crc = i - 1
            for _ = 1, 8 do -- eight times
                mask = -(crc & 1)
                crc = (crc >> 1) ~ (0xedb88320 & mask)
            end
            lt[i] = crc
        end
    end

    -- compute the crc
    crc = 0xffffffff
    for i = 1, #s do
        b = string.byte(s, i)
        crc = (crc >> 8) ~ lt[((crc ~ b) & 0xFF) + 1]
    end
    return ~crc & 0xffffffff
end

local function parse(raw, use_cache)
    local checksum
    if use_cache == nil or use_cache then
        checksum = crc32(raw)
        if navigation_mesh_cache[checksum] ~= nil then
            return navigation_mesh_cache[checksum]
        end
    end

    local buf = struct_buffer(raw)

    local self = {}
    self.magic, self.major, self.minor, self.bspsize, self.analyzed, self.places_count = buf:unpack("IIIIbH")

    assert(self.magic == 0xFEEDFACE, "invalid magic, expected 0xFEEDFACE")
    assert(self.major == 16, "invalid major version, expected 16")

    -- place names
    self.places = {}
    for i = 1, self.places_count do
        local place = {}
        place.name_length = buf:unpack("H")

        -- read but ignore null byte
        place.name = buf:unpack(string.format("c%db", place.name_length - 1))

        self.places[i] = place
    end

    -- areas
    self.has_unnamed_areas, self.areas_count = buf:unpack("bI")
    self.areas = {}
    for i = 1, self.areas_count do
        local area = {}
        area.id, area.flags = buf:unpack("II")

        area.north_west = buf:unpack_vec()
        area.south_east = buf:unpack_vec()

        area.north_east_z, area.south_west_z = buf:unpack("ff")

        -- connections
        area.connections = {}
        for dir = 1, 4 do
            local connections_dir = {}
            connections_dir.count = buf:unpack("I")

            connections_dir.connections = {}
            for i = 1, connections_dir.count do
                local target
                target = buf:unpack("I")
                connections_dir.connections[i] = target
            end
            area.connections[dir] = connections_dir
        end

        -- hiding spots
        area.hiding_spots_count = buf:unpack("B")
        area.hiding_spots = {}
        for i = 1, area.hiding_spots_count do
            local hiding_spot = {}
            hiding_spot.id = buf:unpack("I")
            hiding_spot.location = buf:unpack_vec()
            hiding_spot.flags = buf:unpack("b")
            area.hiding_spots[i] = hiding_spot
        end

        -- encounter paths
        area.encounter_paths_count = buf:unpack("I")
        area.encounter_paths = {}
        for i = 1, area.encounter_paths_count do
            local encounter_path = {}
            encounter_path.from_id, encounter_path.from_direction, encounter_path.to_id, encounter_path.to_direction,
                encounter_path.spots_count =
            buf:unpack("IBIBB")

            encounter_path.spots = {}
            for i = 1, encounter_path.spots_count do
                encounter_path.spots[i] = {}
                encounter_path.spots[i].order_id, encounter_path.spots[i].distance = buf:unpack("IB")
            end
            area.encounter_paths[i] = encounter_path
        end

        area.place_id = buf:unpack("H")

        -- ladders
        area.ladders = {}
        for i = 1, 2 do
            area.ladders[i] = {}
            area.ladders[i].connection_count = buf:unpack("I")

            area.ladders[i].connections = {}
            for i = 1, area.ladders[i].connection_count do
                area.ladders[i].connections[i] = buf:unpack("I")
            end
        end

        area.earliest_occupy_time_first_team, area.earliest_occupy_time_second_team = buf:unpack("ff")
        area.light_intensity_north_west, area.light_intensity_north_east, area.light_intensity_south_east,
            area.light_intensity_south_west =
        buf:unpack("ffff")

        -- visible areas
        area.visible_areas = {}
        area.visible_area_count = buf:unpack("I")
        for i = 1, area.visible_area_count do
            area.visible_areas[i] = {}
            area.visible_areas[i].id, area.visible_areas[i].attributes = buf:unpack("Ib")
        end
        area.inherit_visibility_from_area_id = buf:unpack("I")

        -- NOTE: Differnet value in CSGO/TF2
        -- garbage?
        self.garbage = buf:unpack('I')

        self.areas[i] = area
    end

    -- ladders
    self.ladders_count = buf:unpack("I")
    self.ladders = {}
    for i = 1, self.ladders_count do
        local ladder = {}
        ladder.id, ladder.width = buf:unpack("If")

        ladder.top = buf:unpack_vec()
        ladder.bottom = buf:unpack_vec()

        ladder.length, ladder.direction = buf:unpack("fI")

        ladder.top_forward_area_id, ladder.top_left_area_id, ladder.top_right_area_id, ladder.top_behind_area_id =
        buf:unpack("IIII")
        ladder.bottom_area_id = buf:unpack("I")

        self.ladders[i] = ladder
    end

    if checksum ~= nil and navigation_mesh_cache[checksum] == nil then
        navigation_mesh_cache[checksum] = self
    end

    return self
end

return {
    parse = parse
}

end)
__bundle_register("Lmaobot.Common", function(require, _LOADED, __bundle_register, __bundle_modules)
---@class Common
local Common = {}

---@type boolean, LNXlib
local libLoaded, Lib = pcall(require, "LNXlib")
assert(libLoaded, "LNXlib not found, please install it!")
assert(Lib.GetVersion() >= 0.94, "LNXlib version is too old, please update it!")
Common.Lib = Lib

Common.Log = Lib.Utils.Logger.new("Lmaobot")

return Common

end)
return __bundle_require("__root")