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
--[[ Annotations ]]
---@alias NavConnection { count: integer, connections: integer[] }
---@alias NavNode { id: integer, x: number, y: number, z: number, c: { [1]: NavConnection, [2]: NavConnection, [3]: NavConnection, [4]: NavConnection } }

--[[ Imports ]]
local Common = require("Lmaobot.Common")
local Navigation = require("Lmaobot.Navigation")
local Lib = Common.Lib
---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")

-- Unload package for debugging
Lib.Utils.UnloadPackages("Lmaobot")

local Notify, FS, Fonts, Commands, Timer = Lib.UI.Notify, Lib.Utils.FileSystem, Lib.UI.Fonts, Lib.Utils.Commands, Lib.Utils.Timer
local Log = Lib.Utils.Logger.new("Lmaobot")
Log.Level = 0

--[[ Variables ]]

local options = {
    memoryUsage = true, -- Shows memory usage in the top left corner
    drawNodes = false, -- Draws all nodes on the map
    drawPath = true, -- Draws the path to the current goal
    drawCurrentNode = false, -- Draws the current node
    lookatpath = true, -- Look at where we are walking
    smoothLookAtPath = true, -- Set this to true to enable smooth look at path
    autoPath = true, -- Automatically walks to the goal
    shouldfindhealth = true, -- Path to health
    SelfHealTreshold = 45, -- Health percentage to start looking for healthPacks
}

local smoothFactor = 0.05
local currentNodeIndex = 1
local currentNodeTicks = 0

---@type Vector3[]
local healthPacks = {}

local Tasks = table.readOnly {
    None = 0,
    Objective = 1,
    Health = 2,
}

local jumptimer = 0;
local currentTask = Tasks.Objective
local taskTimer = Timer.new()
local Math = lnxLib.Utils.Math
local WPlayer = lnxLib.TF2.WPlayer

--[[ Functions ]]

-- Loads the nav file of the current map
local function LoadNavFile()
    local mapFile = engine.GetMapName()
    local navFile = string.gsub(mapFile, ".bsp", ".nav")

    Navigation.LoadFile(navFile)
end


local function Draw3DBox(size, pos)
    local halfSize = size / 2
    if not corners then
        corners1 = {
            Vector3(-halfSize, -halfSize, -halfSize),
            Vector3(halfSize, -halfSize, -halfSize),
            Vector3(halfSize, halfSize, -halfSize),
            Vector3(-halfSize, halfSize, -halfSize),
            Vector3(-halfSize, -halfSize, halfSize),
            Vector3(halfSize, -halfSize, halfSize),
            Vector3(halfSize, halfSize, halfSize),
            Vector3(-halfSize, halfSize, halfSize)
        }
    end

    local linesToDraw = {
        {1, 2}, {2, 3}, {3, 4}, {4, 1},
        {5, 6}, {6, 7}, {7, 8}, {8, 5},
        {1, 5}, {2, 6}, {3, 7}, {4, 8}
    }

    local screenPositions = {}
    for _, cornerPos in ipairs(corners1) do
        local worldPos = pos + cornerPos
        local screenPos = client.WorldToScreen(worldPos)
        if screenPos then
            table.insert(screenPositions, { x = screenPos[1], y = screenPos[2] })
        end
    end

    for _, line in ipairs(linesToDraw) do
        local p1, p2 = screenPositions[line[1]], screenPositions[line[2]]
        if p1 and p2 then
            draw.Line(p1.x, p1.y, p2.x, p2.y)
        end
    end
end

-- Normalize a vector
local function NormalizeVector(v)
    local length = math.sqrt(v.x * v.x + v.y * v.y + v.z * v.z)
    return Vector3(v.x / length, v.y / length, v.z / length)
end

local function arrowPathArrow2(startPos, endPos, width)
    if not (startPos and endPos) then return nil, nil end

    local direction = endPos - startPos
    local length = direction:Length()
    if length == 0 then return nil, nil end
    direction = NormalizeVector(direction)

    local perpDir = Vector3(-direction.y, direction.x, 0)
    local leftBase = startPos + perpDir * width
    local rightBase = startPos - perpDir * width

    local screenStartPos = client.WorldToScreen(startPos)
    local screenEndPos = client.WorldToScreen(endPos)
    local screenLeftBase = client.WorldToScreen(leftBase)
    local screenRightBase = client.WorldToScreen(rightBase)

    if screenStartPos and screenEndPos and screenLeftBase and screenRightBase then
        draw.Line(screenStartPos[1], screenStartPos[2], screenEndPos[1], screenEndPos[2])
        draw.Line(screenLeftBase[1], screenLeftBase[2], screenEndPos[1], screenEndPos[2])
        draw.Line(screenRightBase[1], screenRightBase[2], screenEndPos[1], screenEndPos[2])
    end

    return leftBase, rightBase
end

--[[ Callbacks ]]

local function OnDraw()
    draw.SetFont(Fonts.Verdana)
    draw.Color(255, 0, 0, 255)

    local me = entities.GetLocalPlayer()
    if not me then return end

    local myPos = me:GetAbsOrigin()
    local currentPath = Navigation.GetCurrentPath()
    local currentY = 120

    -- Memory usage
    if options.memoryUsage then
        local memUsage = collectgarbage("count")
        draw.Text(20, currentY, string.format("Memory usage: %.2f MB", memUsage / 1024))
        currentY = currentY + 20
    end

    -- Auto path informaton
    if options.autoPath then
        draw.Text(20, currentY, string.format("Current Node: %d", currentNodeIndex))
        currentY = currentY + 20
    end

    -- Draw all nodes
    if options.drawNodes then
        draw.Color(0, 255, 0, 255)

        local navNodes = Navigation.GetNodes()
        for id, node in pairs(navNodes) do
            local nodePos = Vector3(node.x, node.y, node.z)
            local dist = (myPos - nodePos):Length()
            if dist > 700 then goto continue end

            local screenPos = client.WorldToScreen(nodePos)
            if not screenPos then goto continue end

            local x, y = screenPos[1], screenPos[2]
            draw.FilledRect(x - 4, y - 4, x + 4, y + 4)  -- Draw a small square centered at (x, y)

            -- Node IDs
            draw.Text(screenPos[1], screenPos[2] + 10, tostring(id))

            ::continue::
        end
    end

    -- Draw current path
    if options.drawPath and currentPath then
        draw.Color(255, 255, 255, 255)

        for i = 1, #currentPath - 1 do
            local node1 = currentPath[i]
            local node2 = currentPath[i + 1]

            local node1Pos = Vector3(node1.x, node1.y, node1.z)
            local node2Pos = Vector3(node2.x, node2.y, node2.z)

            local screenPos1 = client.WorldToScreen(node1Pos)
            local screenPos2 = client.WorldToScreen(node2Pos)
            if not screenPos1 or not screenPos2 then goto continue end

            draw.Line(screenPos1[1], screenPos1[2], screenPos2[1], screenPos2[2])

            ::continue::
        end
    end

    -- Draw current node
    if options.drawCurrentNode and currentPath then
        draw.Color(255, 255, 255, 255)

        local currentNode = currentPath[currentNodeIndex]
        local currentNodePos = Vector3(currentNode.x, currentNode.y, currentNode.z)

        local screenPos = client.WorldToScreen(currentNodePos)
        if screenPos then
            Draw3DBox(20, currentNodePos)
            draw.Text(screenPos[1], screenPos[2], tostring(currentNodeIndex))
        end
    end
end


---@param userCmd UserCmd
local function OnCreateMove(userCmd)
    if not options.autoPath then return end

    local me = entities.GetLocalPlayer()
    if not me or not me:IsAlive() then
        Navigation.ClearPath()
        return
    end

    -- Update the current task
    if taskTimer:Run(0.7) then
        -- make sure we're not being healed by a medic before running health logic
        if (me:GetHealth() / me:GetMaxHealth()) * 100 < options.SelfHealTreshold and not me:InCond(TFCond_Healing) then
            if currentTask ~= Tasks.Health and options.shouldfindhealth then
                Log:Info("Switching to health task")
                Navigation.ClearPath()
            end

            currentTask = Tasks.Health
        else
            if currentTask ~= Tasks.Objective then
                Log:Info("Switching to objective task")
                Navigation.ClearPath()
            end

            currentTask = Tasks.Objective
        end
        local memUsage2 = collectgarbage("count")
        if memUsage2 / 1024 > 250 then
            collectgarbage()
            collectgarbage()
            collectgarbage()

            Log:Info("Trigger GC")
        end
    end

    local myPos = me:GetAbsOrigin()
    local currentPath = Navigation.GetCurrentPath()

    if currentTask == Tasks.None then return end

    if currentPath then
        -- Move along path

        -- auto melee fix
        if userCmd:GetForwardMove() ~= 0 or userCmd:GetSideMove() ~= 0 then
            currentNodeTicks = 0
            return
        end

        local currentNode = currentPath[currentNodeIndex]
        local currentNodePos = Vector3(currentNode.x, currentNode.y, currentNode.z)

        if options.lookatpath then
            if currentNodePos == nil then
                return
            else
            local melnx = WPlayer.GetLocal()    
            local angles = Lib.Utils.Math.PositionAngles(melnx:GetEyePos(), currentNodePos)--Math.PositionAngles(me:GetAbsOrigin() + me:GetPropVector("localdata", "m_vecViewOffset[0]"), currentNodePos)
            angles.x = 0

            if options.smoothLookAtPath then
                local currentAngles = userCmd.viewangles
                local deltaAngles = {x = angles.x - currentAngles.x, y = angles.y - currentAngles.y}

                while deltaAngles.y > 180 do deltaAngles.y = deltaAngles.y - 360 end
                while deltaAngles.y < -180 do deltaAngles.y = deltaAngles.y + 360 end

                angles = EulerAngles(currentAngles.x + deltaAngles.x * 0.5, currentAngles.y + deltaAngles.y * smoothFactor, 0)
            end
            --Credits to catt (pp021)
            engine.SetViewAngles(angles)
            end
        end

        local dist = (myPos - currentNodePos):Length()
        if dist < 22 then
            currentNodeTicks = 0
            currentNodeIndex = currentNodeIndex - 1
            table.remove(currentPath)
            if currentNodeIndex < 1 then
                Navigation.ClearPath()
                Log:Info("Reached end of path")
                currentTask = Tasks.None
            end
        else
            currentNodeTicks = currentNodeTicks + 1

            -- Check if the next node is closer
            if currentNodeIndex > 1 then
                local nextNode = currentPath[currentNodeIndex - 1]
                local nextNodePos = Vector3(nextNode.x, nextNode.y, nextNode.z)
                local nextDist = (myPos - nextNodePos):Length()

                if nextDist < dist then
                    Log:Info("Skipping to closer node %d", currentNodeIndex - 1)
                    currentNodeIndex = currentNodeIndex - 1
                    currentNode = nextNode
                    currentNodePos = nextNodePos
                    dist = nextDist
                end
            end

            Lib.TF2.Helpers.WalkTo(userCmd, me, currentNodePos)
        end

        -- Jump if stuck
        if currentNodeTicks > 175 and not me:InCond(TFCond_Zoomed) and me:EstimateAbsVelocity():Length() < 50 then
            --hold down jump for half a second or something i dont know how long it is
            jumptimer = jumptimer + 1;
            userCmd.buttons = userCmd.buttons | IN_JUMP
        end

        -- Repath if stuck
        if currentNodeTicks > 300 then
            local viewPos = me:GetAbsOrigin() + Vector3(0, 0, 72)
            local trace = engine.TraceLine(viewPos, currentNodePos, MASK_SHOT_HULL)
            if trace.fraction < 1.0 then
                Log:Warn("Path to node %d is blocked, removing connection and repathing...", currentNodeIndex)
                Navigation.RemoveConnection(currentNode, currentPath[currentNodeIndex - 1])
                Navigation.ClearPath()
                currentNodeTicks = 0
            end
        end
    else
        -- Generate new path
        local startNode = Navigation.GetClosestNode(myPos)
        local goalNode = nil
        local entity = nil

        if currentTask == Tasks.Objective then
            local objectives = nil

            -- map check
            local mapName = engine.GetMapName():lower()
            if mapName:find("plr_") then
                payloads = entities.FindByClass("CObjectCartDispenser")
                for idx, entity in pairs(payloads) do
                    if entity:GetTeamNumber() == me:GetTeamNumber() then
                        goalNode = Navigation.GetClosestNode(entity:GetAbsOrigin())
                        Log:Info("Found payload at node %d", goalNode.id)
                    end
                end
            elseif mapName:find("pl_") then
                payloads = entities.FindByClass("CObjectCartDispenser")
                for idx, entity in pairs(payloads) do
                    goalNode = Navigation.GetClosestNode(entity:GetAbsOrigin())
                    Log:Info("Found payload at node %d", goalNode.id)
                end            
            elseif mapName:find("ctf_") then
                -- ctf
                local myItem = me:GetPropInt("m_hItem")
                local flags = entities.FindByClass("CCaptureFlag")
                for idx, entity in pairs(flags) do
                    local myTeam = entity:GetTeamNumber() == me:GetTeamNumber()
                    if (myItem > 0 and myTeam) or (myItem < 0 and not myTeam) then
                        goalNode = Navigation.GetClosestNode(entity:GetAbsOrigin())
                        Log:Info("Found flag at node %d", goalNode.id)
                        break
                    end
                end
            else
                Log:Warn("Unsupported Gamemode, try CTF, PL, or PLR")
            end

            -- Check if the distance between player and payload is greater than a threshold
            if engine.GetMapName():lower():find("pl_") then
                if entity then
                    local distanceToPayload = (myPos - entity:GetAbsOrigin()):Length()
                    local thresholdDistance = 80

                    if distanceToPayload > thresholdDistance then
                        Log:Info("Payload too far from player, pathing closer.")
                        -- If too far, update the path to get closer
                        Navigation.FindPath(startNode, goalNode)
                        currentNodeIndex = #Navigation.GetCurrentPath()
                    end
                end
            end

            if not goalNode then
                Log:Warn("No objectives found. Continuing with default objective task.")
                currentTask = Tasks.Objective
                Navigation.ClearPath()
            end
        elseif currentTask == Tasks.Health then
            local closestDist = math.huge
            for idx, pos in pairs(healthPacks) do
                local healthNode = Navigation.GetClosestNode(pos)
                if healthNode then
                    local dist = (myPos - pos):Length()
                    if dist < closestDist then
                        closestDist = dist
                        goalNode = healthNode
                        Log:Info("Found health pack at node %d", goalNode.id)
                    end
                end
            end
        else
            Log:Debug("Unknown task: %d", currentTask)
            return
        end

        -- Check if we found a start and goal node
        if not startNode or not goalNode then
            Log:Warn("Could not find new start or goal node")
            return
        end

        -- Update the pathfinder
        Log:Info("Generating new path from node %d to node %d", startNode.id, goalNode.id)
        Navigation.FindPath(startNode, goalNode)

        local currentPath = Navigation.GetCurrentPath()
        if currentPath then
            currentNodeIndex = #currentPath
        else
            Log:Warn("Failed to find a path from node %d to node %d", startNode.id, goalNode.id)
        end
    end
end

---@param ctx DrawModelContext
local function OnDrawModel(ctx)
    -- TODO: This find a better way to do this
    if ctx:GetModelName():find("medkit") then
        local entity = ctx:GetEntity()
        healthPacks[entity:GetIndex()] = entity:GetAbsOrigin()
    end
end

---@param event GameEvent
local function OnGameEvent(event)
    local eventName = event:GetName()

    -- Reload nav file on new map
    if eventName == "game_newmap" then
        Log:Info("New map detected, reloading nav file...")

        healthPacks = {}
        LoadNavFile()
    end
end

callbacks.Unregister("Draw", "LNX.Lmaobot.Draw")
callbacks.Unregister("CreateMove", "LNX.Lmaobot.CreateMove")
callbacks.Unregister("DrawModel", "LNX.Lmaobot.DrawModel")
callbacks.Unregister("FireGameEvent", "LNX.Lmaobot.FireGameEvent")

callbacks.Register("Draw", "LNX.Lmaobot.Draw", OnDraw)
callbacks.Register("CreateMove", "LNX.Lmaobot.CreateMove", OnCreateMove)
callbacks.Register("DrawModel", "LNX.Lmaobot.DrawModel", OnDrawModel)
callbacks.Register("FireGameEvent", "LNX.Lmaobot.FireGameEvent", OnGameEvent)

--[[ Commands ]]

-- Reloads the nav file
Commands.Register("pf_reload", function()
    LoadNavFile()
end)

-- Calculates the path from start to goal
Commands.Register("pf", function(args)
    if args:size() ~= 2 then
        print("Usage: pf <Start> <Goal>")
        return
    end

    local start = tonumber(args:popFront())
    local goal = tonumber(args:popFront())

    if not start or not goal then
        print("Start/Goal must be numbers!")
        return
    end

    local startNode = Navigation.GetNodeByID(start)
    local goalNode = Navigation.GetNodeByID(goal)

    if not startNode or not goalNode then
        print("Start/Goal node not found!")
        return
    end

    Navigation.FindPath(startNode, goalNode)
end)

Commands.Register("pf_auto", function (args)
    options.autoPath = not options.autoPath
    print("Auto path: " .. tostring(options.autoPath))
end)

Notify.Alert("Lmaobot loaded!")
LoadNavFile()
end)
__bundle_register("Lmaobot.Navigation", function(require, _LOADED, __bundle_register, __bundle_modules)
---@alias Connection { count: integer, connections: integer[] }
---@alias Node { x: number, y: number, z: number, id: integer, c: { [1]: Connection, [2]: Connection, [3]: Connection, [4]: Connection } }

local Common = require("Lmaobot.Common")
local SourceNav = require("Lmaobot.SourceNav")
local AStar = require("Lmaobot.A-Star")
local Lib, Log = Common.Lib, Common.Log

local FS = Lib.Utils.FileSystem

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

function Navigation.RemoveConnection(nodeA, nodeB)
    -- If nodeA or nodeB is nil, exit the function
    if not nodeA or not nodeB then
        print("One or both nodes are nil, exiting function")
        return
    end

    -- Remove the connection from nodeA to nodeB
    for dir = 1, 4 do
        local conDir = nodeA.c[dir]
        for i, con in ipairs(conDir.connections) do
            if con == nodeB.id then
                print("Removing connection between " .. nodeA.id .. " and " .. nodeB.id)
                table.remove(conDir.connections, i)
                conDir.count = conDir.count - 1
                break  -- Exit the loop once the connection is found and removed
            end
        end
    end

    -- Remove the reverse connection from nodeB to nodeA
    for dir = 1, 4 do
        local conDir = nodeB.c[dir]
        for i, con in ipairs(conDir.connections) do
            if con == nodeA.id then
                print("Removing reverse connection between " .. nodeB.id .. " and " .. nodeA.id)
                table.remove(conDir.connections, i)
                conDir.count = conDir.count - 1
                break  -- Exit the loop once the connection is found and removed
            end
        end
    end
end

function Navigation.AddCostToConnection(nodeA, nodeB, cost)
    -- If nodeA or nodeB is nil, exit the function
    if not nodeA or not nodeB then
        print("One or both nodes are nil, exiting function")
        return
    end

    -- Add the cost from nodeA to nodeB
    for dir = 1, 4 do
        local conDir = nodeA.c[dir]
        for i, con in ipairs(conDir.connections) do
            if con == nodeB.id then
                print("Adding cost between " .. nodeA.id .. " and " .. nodeB.id)
                conDir.connections[i] = {node = con, cost = cost}
                break  -- Exit the loop once the connection is found
            end
        end
    end

    -- Add the cost from nodeB to nodeA
    for dir = 1, 4 do
        local conDir = nodeB.c[dir]
        for i, con in ipairs(conDir.connections) do
            if con == nodeA.id then
                print("Adding cost between " .. nodeB.id .. " and " .. nodeA.id)
                conDir.connections[i] = {node = con, cost = cost}
                break  -- Exit the loop once the connection is found
            end
        end
    end
end

function Navigation.AddConnection(nodeA, nodeB)
    -- If nodeA or nodeB is nil, exit the function
    if not nodeA or not nodeB then
        print("One or both nodes are nil, exiting function")
        return
    end

    -- Add the connection from nodeA to nodeB
    for dir = 1, 4 do
        local conDir = nodeA.c[dir]
        if not conDir.connections[nodeB.id] then
            print("Adding connection between " .. nodeA.id .. " and " .. nodeB.id)
            table.insert(conDir.connections, nodeB.id)
            conDir.count = conDir.count + 1
        end
    end

    -- Add the reverse connection from nodeB to nodeA
    for dir = 1, 4 do
        local conDir = nodeB.c[dir]
        if not conDir.connections[nodeA.id] then
            print("Adding reverse connection between " .. nodeB.id .. " and " .. nodeA.id)
            table.insert(conDir.connections, nodeA.id)
            conDir.count = conDir.count + 1
        end
    end
end

-- Constants for hull dimensions and trace masks
local HULL_MIN = Vector3(-24, -24, 0)
local HULL_MAX = Vector3(24, 24, 82)
local TRACE_MASK = MASK_PLAYERSOLID

-- Fixes a node by adjusting its height based on TraceHull and TraceLine results
-- Moves the node 18 units up and traces down to find a new valid position
---@param nodeId integer The index of the node in the Nodes table
---@return Node The fixed node
function Navigation.FixNode(nodeId)
    local node = Navigation.GetNodeByID(nodeId)
    if not node or not node.pos then
        print("Node with ID " .. tostring(nodeId) .. " is invalid or missing position, exiting function")
        return nil
    end

    -- Check if the node has already been fixed
    if node.fixed then
        return Nodes[nodeId]
    end

    local upVector = Vector3(0, 0, 72) -- Move node 18 units up
    local downVector = Vector3(0, 0, -72) -- Trace down a large distance

    -- Perform a TraceHull directly downwards from the node's center position
    local nodePos = node.pos
    local centerTraceResult = engine.TraceHull(nodePos + upVector, nodePos + downVector, HULL_MIN, HULL_MAX, TRACE_MASK)

    -- Check if the trace result is more than 0
    if centerTraceResult.fraction > 0 then
        -- Update node's center position in the Nodes table directly
        Nodes[nodeId].z = centerTraceResult.endpos.z
        Nodes[nodeId].pos = centerTraceResult.endpos
    else
        -- Lift the node 18 units up and keep it there
        Nodes[nodeId].z = nodePos.z + 18
        Nodes[nodeId].pos = Vector3(nodePos.x, nodePos.y, nodePos.z + 18)
    end

    -- Mark the node as fixed
    Nodes[nodeId].fixed = true

    return Nodes[nodeId]  -- Return the fixed node
end

-- Checks for an obstruction between two points using a line trace, then a hull trace if necessary.
local function isPathClear(startPos, endPos)
    -- First, use a line trace for a quick check
    local lineTraceResult = engine.TraceLine(startPos, endPos, TRACE_MASK)
    
    -- If line trace fails, return false immediately
    if lineTraceResult.fraction < 1 then
        return false
    end
    
    -- If line trace succeeds, use a hull trace for the actual check
    local traceResult = engine.TraceHull(startPos, endPos, HULL_MIN, HULL_MAX, TRACE_MASK)
    if traceResult.fraction == 1 then
        return true  -- If fraction is 1, path is clear.
    else
        -- If the height difference is less than 18, move startPos 18 units up and check again
        local upVector = Vector3(0, 0, 72)
        traceResult = engine.TraceHull(startPos + upVector, endPos, HULL_MIN, HULL_MAX, TRACE_MASK)
        return traceResult.fraction == 1
    end
end

-- Checks if the ground is stable at a given position.
local function isGroundStable(position)
    local groundTraceStart = position + Vector3(0, 0, 5)  -- Start a bit above the ground
    local groundTraceEnd = position + Vector3(0, 0, -67)  -- Check 72 units down
    local groundTraceResult = engine.TraceLine(groundTraceStart, groundTraceEnd, TRACE_MASK)
    return groundTraceResult.fraction < 1  -- If fraction is less than 1, ground is stable.
end

-- Recursive binary search function to check path walkability.
local function binarySearch(startPos, endPos, depth)
    if depth == 0 then
        return true
    end

    if not isPathClear(startPos, endPos) then
        return false
    end

    local midPos = (startPos + endPos) / 2
    if not isGroundStable(midPos) then
        return false
    end

    -- Recurse for each half of the path
    return binarySearch(startPos, midPos, depth - 1) and binarySearch(midPos, endPos, depth - 1)
end

-- Main function to check if the path between the current position and the node is walkable.
function Navigation.isWalkable(startPos, endPos)
    local maxDepth = 5
    return binarySearch(startPos, endPos, maxDepth)
end

--- Finds the closest walkable node from the player's current position in reverse order (from last to first).
-- @param currentPath table The current path consisting of nodes.
-- @param myPos Vector3 The player's current position.
-- @param currentNodeIndex number The index of the current node in the path.
-- @return number, Node, Vector3 The index, node, and position of the closest walkable node in reverse order.
function Navigation.FindBestNode(currentPath, myPos, currentNodeIndex)
    -- Initialize variables for storing the last walkable node information
    local lastWalkableNodeIndex = nil
    local lastWalkableNode = nil
    local lastWalkableNodePos = nil

    -- Start the search from the current node, moving towards the first node
    for i = currentNodeIndex, 1, -1 do
        local node = currentPath[i]
        node = Navigation.FixNode(node.id) -- Ensure the node is fixed before checking
        local nodePos = node.pos

        -- Calculate the distance between the current position and the node
        local distance = (myPos - nodePos):Length()

        -- Check if the node is walkable and within 700 units
        if distance <= 700 and Navigation.isWalkable(myPos, nodePos) then
            -- Update the last walkable node information
            lastWalkableNodeIndex = i
            lastWalkableNode = node
            lastWalkableNodePos = nodePos
        elseif distance > 700 then
            -- Break the loop if the node is beyond 700 units or higher than 72 units
            break
        end
    end

    -- Return the last walkable node information found in the search
    return lastWalkableNodeIndex, lastWalkableNode, lastWalkableNodePos
end

-- Constants
local MIN_SPEED = 0   -- Minimum speed to avoid jittery movements
local MAX_SPEED = 450 -- Maximum speed the player can move
local TICK_RATE = 66  -- Number of ticks per second

local ClassForwardSpeeds = {
    [E_Character.TF2_Scout] = 400,
    [E_Character.TF2_Soldier] = 240,
    [E_Character.TF2_Pyro] = 300,
    [E_Character.TF2_Demoman] = 280,
    [E_Character.TF2_Heavy] = 230,
    [E_Character.TF2_Engineer] = 300,
    [E_Character.TF2_Medic] = 320,
    [E_Character.TF2_Sniper] = 300,
    [E_Character.TF2_Spy] = 320
}

-- Function to get forward speed by class
function Navigation.GetForwardSpeedByClass(pLocal)
    local pLocalClass = pLocal:GetPropInt("m_iClass")
    return ClassForwardSpeeds[pLocalClass]
end

-- Function to compute the move direction
local function ComputeMove(pCmd, a, b)
    local diff = (b - a)
    if diff:Length() == 0 then return Vector3(0, 0, 0) end

    local x = diff.x
    local y = diff.y
    local vSilent = Vector3(x, y, 0)

    local ang = vSilent:Angles()
    local cPitch, cYaw, cRoll = pCmd:GetViewAngles()
    local yaw = math.rad(ang.y - cYaw)
    local move = Vector3(math.cos(yaw), -math.sin(yaw), 0)

    return move
end

local function Normalize(vec)
    local length = math.sqrt(vec.x * vec.x + vec.y * vec.y + vec.z * vec.z)
    return Vector3(vec.x / length, vec.y / length, vec.z / length)
end

-- Function to make the player walk to a destination smoothly
function Navigation.WalkTo(pCmd, pLocal, pDestination)
    local localPos = pLocal:GetAbsOrigin()
    local distVector = pDestination - localPos
    local dist = math.abs(distVector.x) + math.abs(distVector.y)
    local currentSpeed = Navigation.GetForwardSpeedByClass(pLocal)  -- Max speed for the class
    local currentVelocity = pLocal:EstimateAbsVelocity()
    local velocityDirection = Normalize(currentVelocity)
    local velocitySpeed = currentVelocity:Length()

    -- Calculate distance that would be covered in one tick at the current speed
    local distancePerTick = currentSpeed / TICK_RATE

    -- Check if we are close enough to potentially overshoot the target in the next tick
    if dist > distancePerTick then
        -- If we are not close enough to overshoot, proceed at max speed
        local result = ComputeMove(pCmd, localPos, pDestination)
        pCmd:SetForwardMove(result.x * currentSpeed)
        pCmd:SetSideMove(result.y * currentSpeed)
    else
        -- Calculate the required deceleration per tick to stop at the target
        local decelPerTick = (velocitySpeed * velocitySpeed) / (2 * dist * TICK_RATE)
        local requiredSpeed = velocitySpeed - decelPerTick
        requiredSpeed = math.max(requiredSpeed, 0)  -- Ensure speed doesn't go below 0

        -- Apply the calculated speed in the direction of the target
        local result = ComputeMove(pCmd, localPos, pDestination)
        pCmd:SetForwardMove(result.x * requiredSpeed)
        pCmd:SetSideMove(result.y * requiredSpeed)
    end
end





---@param node NavNode
---@param pos Vector3
---@return Vector3
function Navigation.GetMeshPos(node, pos)
    -- Calculate the closest point on the node's 3D plane to the given position
    return Vector3(
        math.max(node.nw.x, math.min(node.se.x, pos.x)),
        math.max(node.nw.y, math.min(node.se.y, pos.y)),
        math.max(node.nw.z, math.min(node.se.z, pos.z))
    )
end

-- Attempts to read and parse the nav file
---@param navFilePath string
---@return table|nil, string|nil
local function tryLoadNavFile(navFilePath)
    local file = io.open(navFilePath, "rb")
    if not file then
        return nil, "File not found"
    end

    local content = file:read("*a")
    file:close()

    local navData = SourceNav.parse(content)
    if not navData or #navData.areas == 0 then
        return nil, "Failed to parse nav file or no areas found."
    end

    return navData
end

-- Generates the nav file
local function generateNavFile()
    client.RemoveConVarProtection("sv_cheats")
    client.RemoveConVarProtection("nav_generate")
    client.SetConVar("sv_cheats", "1")
    client.Command("nav_generate", true)
    Log:Info("Generating nav file. Please wait...")

    local navGenerationDelay = 10  -- in seconds
    local startTime = os.time()
    repeat
        if os.time() - startTime > navGenerationDelay then
            break
        end
    until false
end

-- Processes nav data to create nodes
---@param navData table
---@return table
local function processNavData(navData)
    local navNodes = {}
    for _, area in ipairs(navData.areas) do
        local cX = (area.north_west.x + area.south_east.x) / 2
        local cY = (area.north_west.y + area.south_east.y) / 2
        local cZ = (area.north_west.z + area.south_east.z) / 2

        navNodes[area.id] = {
            x = cX,
            y = cY,
            z = cZ,
            pos = Vector3(cX, cY, cZ),
            id = area.id,
            c = area.connections,
            nw = area.north_west,
            se = area.south_east,
        }
    end
    return navNodes
end

-- Main function to load the nav file
---@param navFile string
function Navigation.LoadFile(navFile)
    local fullPath = "tf/" .. navFile
    local navData, error = tryLoadNavFile(fullPath)

    if not navData and error == "File not found" then
        generateNavFile()
        navData, error = tryLoadNavFile(fullPath)
        if not navData then
            Log:Error("Failed to load or parse generated nav file: " .. error)
            return
        end
    elseif not navData then
        Log:Error(error)
        return
    end

    local navNodes = processNavData(navData)
    Log:Info("Parsed %d areas from nav file.", #navNodes)
    Navigation.SetNodes(navNodes)
end

---@param pos Vector3|{ x:number, y:number, z:number }
---@return Node
function Navigation.GetClosestNode(pos)
    local closestNode = nil
    local closestDist = math.huge

    for _, node in pairs(Nodes) do
        local dist = (node.pos - pos):Length()
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

local InSearch = false
function Navigation.isSearching()
    return InSearch
end

---@param startNode Node
---@param goalNode Node
function Navigation.FindPath(startNode, goalNode, maxNodes)
    if not startNode then
        Log:Warn("Invalid start node %d!", startNode.id)
        return
    end

    if not goalNode then
        Log:Warn("Invalid goal node %d!", goalNode.id)
        return
    end

    InSearch = false
    CurrentPath, InSearch = AStar.Path(startNode, goalNode, Nodes, GetAdjacentNodes, maxNodes)
    if not CurrentPath and not InSearch then
        Log:Error("Failed to find path from %d to %d!", startNode.id, goalNode.id)
    end
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
    Enhanced Heap implementation in Lua.
    Modifications made for robustness and preventing memory leaks.
    Credits: github.com/GlorifiedPig/Luafinding
]]

local Heap = {}
Heap.__index = Heap

-- Constructor for the heap.
-- @param compare? Function for comparison, defining the heap property. Defaults to a min-heap.
function Heap.new(compare)
    return setmetatable({
        _data = {},
        _size = 0,
        Compare = compare or function(a, b) return a < b end
    }, Heap)
end

-- Helper function to maintain the heap property while inserting an element.
local function sortUp(heap, index)
    while index > 1 do
        local parentIndex = math.floor(index / 2)
        if heap.Compare(heap._data[index], heap._data[parentIndex]) then
            heap._data[index], heap._data[parentIndex] = heap._data[parentIndex], heap._data[index]
            index = parentIndex
        else
            break
        end
    end
end

-- Helper function to maintain the heap property after removing the root element.
local function sortDown(heap, index)
    while true do
        local leftIndex, rightIndex = 2 * index, 2 * index + 1
        local smallest = index

        if leftIndex <= heap._size and heap.Compare(heap._data[leftIndex], heap._data[smallest]) then
            smallest = leftIndex
        end
        if rightIndex <= heap._size and heap.Compare(heap._data[rightIndex], heap._data[smallest]) then
            smallest = rightIndex
        end

        if smallest ~= index then
            heap._data[index], heap._data[smallest] = heap._data[smallest], heap._data[index]
            index = smallest
        else
            break
        end
    end
end

-- Checks if the heap is empty.
function Heap:empty()
    return self._size == 0
end

-- Clears the heap, allowing Lua's garbage collector to reclaim memory.
function Heap:clear()
    for i = 1, self._size do
        self._data[i] = nil
    end
    self._size = 0
end

-- Adds an item to the heap.
-- @param item The item to be added.
function Heap:push(item)
    self._size = self._size + 1
    self._data[self._size] = item
    sortUp(self, self._size)
end

-- Removes and returns the root element of the heap.
function Heap:pop()
    if self._size == 0 then
        return nil
    end
    local root = self._data[1]
    self._data[1] = self._data[self._size]
    self._data[self._size] = nil  -- Clear the reference to the removed item
    self._size = self._size - 1
    if self._size > 0 then
        sortDown(self, 1)
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