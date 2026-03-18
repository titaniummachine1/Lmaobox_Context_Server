
--[[  Movement assist for  Lmaobox  ]]--
--[[           --Author--           ]]--
--[[           Terminator           ]]--
--[[  (github.com/titaniummachine1  ]]--

---@alias AimTarget { entity : Entity, angles : EulerAngles, factor : number }

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
assert(lnxLib.GetVersion() >= 0.995, "lnxLib version is too old, please update it!")

local menuLoaded, ImMenu = pcall(require, "ImMenu")
assert(menuLoaded, "ImMenu not found, please install it!")
assert(ImMenu.GetVersion() >= 0.66, "ImMenu version is too old, please update it!")


local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer, WWeapon = lnxLib.TF2.WPlayer, lnxLib.TF2.WWeapon
local Helpers = lnxLib.TF2.Helpers
local Prediction = lnxLib.TF2.Prediction
local Fonts = lnxLib.UI.Fonts

local Menu = { -- this is the config that will be loaded every time u load the script

    tabs = { -- dont touch this, this is just for managing the tabs in the menu
        Main = true,
        Visuals = false,
        Config = false,
    },

    Main = {
        Active = true,  --disable lua
        FastStop = true,    --instant stop
        FastAccel = true, --instant acceleration
        AutoDodge = true, --actiavae auto dodge
        DodgeKey = KEY_SPACE, --key to activate dodge
        AirBreak = false, --disable airstafe when not holding movement keys,
        BeterAirDuck = true, --disable duck jump when holding crounch in air
    },

    Visuals = {
        Active = true,
        VisualizePoints = false,
        VisualizeDodgeDirection = false,
        VisualizeThreat = false,
        VisualizePredExplosion = true,
        VisualizePointsFactors = true,
    },
}

local config = {
	polygon = {
		enabled = true;
		r = 255;
		g = 200;
		b = 155;
		a = 50;

		size = 10;
		segments = 20;
	};
	
	line = {
		enabled = true;
		r = 255;
		g = 255;
		b = 255;
		a = 255;
	};

	flags = {
		enabled = true;
		r = 255;
		g = 0;
		b = 0;
		a = 255;

		size = 5;
	};

	outline = {
		line_and_flags = true;
		polygon = true;
		r = 0;
		g = 0;
		b = 0;
		a = 155;
	};

	-- 0.5 to 8, determines the size of the segments traced, lower values = worse performance (default 2.5)
	measure_segment_size = 2.5;
};



-- Boring shit ahead!
local CROSS = (function(a, b, c) return (b[1] - a[1]) * (c[2] - a[2]) - (b[2] - a[2]) * (c[1] - a[1]); end);
local CLAMP = (function(a, b, c) return (a<b) and b or (a>c) and c or a; end);
local TRACE_HULL = engine.TraceHull;
local WORLD2SCREEN = client.WorldToScreen;
local POLYGON = draw.TexturedPolygon;
local LINE = draw.Line;
local COLOR = draw.Color;

local pLocal = entities.GetLocalPlayer()
local pLocalOrigin = pLocal:GetAbsOrigin()
local rockets = entities.FindByClass("CTFProjectile_Rocket")
local destination

local function NormalizeVector(vector)
    local length = math.sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z)
    if length == 0 then
        return Vector3(0, 0, 0)
    else
        return Vector3(vector.x / length, vector.y / length, vector.z / length)
    end
end

local function manhattanDistance3D(vec1, vec2)
    return math.abs(vec1.x - vec2.x) + math.abs(vec1.y - vec2.y) + math.abs(vec1.z - vec2.z)
end

local lastToggleTime = 0
local Lbox_Menu_Open = true
local function toggleMenu()
    local currentTime = globals.RealTime()
    if currentTime - lastToggleTime >= 0.1 then
        if Lbox_Menu_Open == false then
            Lbox_Menu_Open = true
        elseif Lbox_Menu_Open == true then
            Lbox_Menu_Open = false
        end
        lastToggleTime = currentTime
    end
end

local threatTable = {}
local function FilterRockets()
    local filteredRockets = {}
    for i, rocket in pairs(rockets) do
        local owner = rocket:GetPropEntity("m_hOwnerEntity")
        if owner ~= pLocal then
            table.insert(filteredRockets, rocket)
        end
    end
    return filteredRockets
end

local function ComputeThreatTable(rocket)
    threatTable = {}
    local traceLength = 1000
    local numSegments = 10
    local rocketPos = rocket:GetAbsOrigin()
    local rocketVel = rocket:EstimateAbsVelocity()
    local traceEndPos = rocketPos + rocketVel * traceLength
    local rocketTrace = engine.TraceLine(rocketPos, traceEndPos, MASK_SHOT_HULL)
    local endpos = rocketTrace.endpos
    
    for j = 1, numSegments do
        local t = (j - 1) / (numSegments - 1)
        local segmentPoint = rocketPos + (endpos - rocketPos) * t
        local distance = (pLocalOrigin - segmentPoint):Length()
        local threatLevel = 1 / distance
        if j == numSegments then
            threatLevel = threatLevel * 2
        end
        table.insert(threatTable, {point = segmentPoint, level = threatLevel})
    end
    return threatTable
end

-- Compute the threat at a specific point based on all rockets
local function ComputeGridPointThreat(point)
    local totalThreat = 0
    for _, rocket in pairs(rockets) do
        threatTable = ComputeThreatTable(rocket, point)
        for _, threat in pairs(threatTable) do
            local distance = (point - threat.point):Length()
            local threatLevel = threat.level / (distance + 1)  -- Adding 1 to avoid division by zero
            totalThreat = totalThreat + threatLevel
        end
    end
    return totalThreat
end

local function GetHighestThreatPoint(threatTable)
    table.sort(threatTable, function(a, b) return a.level > b.level end)
    return threatTable[1].point
end

local function WalkAwayFromThreat(userCmd, pLocal, threatPoint)
    destination = pLocal:GetAbsOrigin() + (pLocal:GetAbsOrigin() - threatPoint)
    if (pLocal:GetAbsOrigin() - threatPoint):Length() < 400 then
        Helpers.WalkTo(userCmd, pLocal, destination)
    end
end


-- Function to compute threat level at a specific point based on all threats
local function ComputeThreatAtPoint(point, allThreats)
    local totalThreat = 0
    for _, threat in pairs(allThreats) do
        local distance = manhattanDistance3D(point, threat.point)
        totalThreat = totalThreat + (threat.level / (distance - 1))  -- Compute threat level at the point based on all threats
    end
    return totalThreat
end

local MAX_FALL_DISTANCE = 200  -- Define the maximum allowed falling distance for a point
local NORMAL_TRACE_HULL_SIZE = 24  -- or whatever value you want
local stepSize = pLocal:GetPropFloat("localdata", "m_flStepSize")
local vStep = Vector3(0, 0, stepSize)

local function CreateDeformedGrid(center, squareSize, numSegments)
    local halfSize = squareSize / 2
    local corners = {
        topLeft = center + Vector3(-halfSize, -halfSize, 0),
        topRight = center + Vector3(halfSize, -halfSize, 0),
        bottomRight = center + Vector3(halfSize, halfSize, 0),
        bottomLeft = center + Vector3(-halfSize, halfSize, 0)
    }
    local normalHitbox = {
        Vector3(-NORMAL_TRACE_HULL_SIZE, -NORMAL_TRACE_HULL_SIZE, 0),
        Vector3(NORMAL_TRACE_HULL_SIZE, NORMAL_TRACE_HULL_SIZE, 75)
    }

    local gridSpacing = squareSize / (numSegments - 1)
    local gridPoints = {}
    local middlePoints = {}
    
    -- Initialize a 2D array to store trace fractions for grid points
    local traceFractions = {}
    for x = 0, numSegments - 1 do
        traceFractions[x] = {}
    end

        -- Loop inside square to create inner grid points
        for x = 0, numSegments - 1 do
            for y = 0, numSegments - 1 do
                local point = corners.topLeft + Vector3(x * gridSpacing, y * gridSpacing, 0)
                local trace = engine.TraceHull(center, point, normalHitbox[1], normalHitbox[2], MASK_PLAYERSOLID)
                local canStepOver = false
    
                -- Record trace fraction only if either no obstacle was found or the obstacle can be stepped over
                if trace.fraction > 0.9 then
                    traceFractions[x][y] = trace.fraction
                    table.insert(gridPoints, point)
                else
                    traceFractions[x][y] = 0
                end
            end
        end

    -- Loop to find middle points for each cell
    for x = 0, numSegments - 2 do
        for y = 0, numSegments - 2 do
            -- Check if all corners of the cell have a trace fraction of 1
            if traceFractions[x][y] >= 1 and traceFractions[x+1][y] >= 1 and traceFractions[x][y+1] >= 1 and traceFractions[x+1][y+1] >= 1 then
                local point1 = corners.topLeft + Vector3(x * gridSpacing, y * gridSpacing, 0)
                local point2 = corners.topLeft + Vector3((x + 1) * gridSpacing, y * gridSpacing, 0)
                local point3 = corners.topLeft + Vector3(x * gridSpacing, (y + 1) * gridSpacing, 0)
                local point4 = corners.topLeft + Vector3((x + 1) * gridSpacing, (y + 1) * gridSpacing, 0)
                
                local middlePoint = (point1 + point2 + point3 + point4) / 4
                table.insert(middlePoints, middlePoint)
            end
        end
    end

    local adjustedMiddlePoints = {}

    for _, point in pairs(middlePoints) do
        local traceDown = engine.TraceLine(point, point + Vector3(0, 0, -MAX_FALL_DISTANCE), MASK_SHOT_HULL)

        -- If the point falls down too much, try using TraceHull
        if traceDown.fraction > 0.99 then
            traceDown = engine.TraceHull(point, point + Vector3(0, 0, -MAX_FALL_DISTANCE), normalHitbox[1], normalHitbox[2], MASK_SHOT_HULL)
        end

        -- If the point still falls down too much, don't include it; otherwise, adjust it to the new position
        if traceDown.fraction < 0.99 then
            -- Perform a final TraceHull from the center to this point
            local finalTrace = engine.TraceHull(center, traceDown.endpos, normalHitbox[1], normalHitbox[2], MASK_SHOT_HULL)
            
            if finalTrace.fraction > 0.7 then  -- Ensure the point is reachable
                table.insert(adjustedMiddlePoints, traceDown.endpos)
            end
        end
    end
    
 local finalAdjustedMiddlePoints = {}  -- To store the final points after additional TraceHull checks

    -- Adjusted center position, removing 75 units from the z coordinate
    local adjustedCenter = center - Vector3(0, 0, 60)

    for _, point in pairs(adjustedMiddlePoints) do
        -- Perform a final TraceHull from the adjusted center to this point
        local finalTrace = engine.TraceLine(adjustedCenter, point, MASK_PLAYERSOLID)
        
        -- Check if the TraceHull was successful
        if finalTrace.fraction > 0.7 then  -- You can adjust the fraction value as needed
            -- If the point is reachable, calculate its threat level based on all rockets
            local threatLevel = ComputeGridPointThreat(point)
            
            -- Add the point along with its threat level to the final list
            table.insert(finalAdjustedMiddlePoints, {point = point, threatLevel = threatLevel})
        end
    end
    
    return finalAdjustedMiddlePoints
end



local navmesh = {}

-- Main function
local function OnCreateMove(userCmd)
    if Lbox_Menu_Open == true then userCmd:SetButtons(userCmd.buttons & (~IN_ATTACK)) end
    pLocal = entities.GetLocalPlayer()
    if pLocal == nil then return end
    pLocalOrigin = pLocal:GetAbsOrigin()

    rockets = entities.FindByClass("CTFProjectile_Rocket")
    local filteredRockets = FilterRockets(rockets, pLocal)
    local allThreats = {}

    for i, rocket in pairs(filteredRockets) do
        threatTable = ComputeThreatTable(rocket)
        for _, threat in pairs(threatTable) do
            table.insert(allThreats, threat)
        end
    end

    navmesh = CreateDeformedGrid(pLocal:GetAbsOrigin() + Vector3(0, 0, 75), 250, 8)
    
    -- Calculate threat at the current position
    local currentThreat = ComputeThreatAtPoint(pLocal:GetAbsOrigin(), allThreats)
    
    if currentThreat > 0 then
        -- Initialize variables to find the best point
        local bestPoint = nil
        local bestValue = math.huge  -- Initialize to a very large number
        
        for _, navPoint in pairs(navmesh) do
            local pointThreat = ComputeThreatAtPoint(navPoint.point, allThreats)  -- Calculate threat at each navPoint
            
            -- Compute manhattan distance from current position to this navPoint
            local distance = manhattanDistance3D(pLocal:GetAbsOrigin(), navPoint.point)
            
            -- Calculate a combined value of threat and distance
            -- Note: Since you want to minimize both, they are just summed up.
            -- You could also consider other combinations or weights.
            local value = pointThreat - distance  -- Less threat and closer distance will result in a lower value
            
            if value < bestValue then
                bestValue = value
                bestPoint = navPoint
            end
        end
        
        -- If a best point is found, move towards it
        if bestPoint then
            WalkAwayFromThreat(userCmd, pLocal, bestPoint)
        end
    end
end













local function CreateCFG(folder_name, table)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.txt")
    local file = io.open(filepath, "w")
    
    if file then
        local function serializeTable(tbl, level)
            level = level or 0
            local result = string.rep("    ", level) .. "{\n"
            for key, value in pairs(tbl) do
                result = result .. string.rep("    ", level + 1)
                if type(key) == "string" then
                    result = result .. '["' .. key .. '"] = '
                else
                    result = result .. "[" .. key .. "] = "
                end
                if type(value) == "table" then
                    result = result .. serializeTable(value, level + 1) .. ",\n"
                elseif type(value) == "string" then
                    result = result .. '"' .. value .. '",\n'
                else
                    result = result .. tostring(value) .. ",\n"
                end
            end
            result = result .. string.rep("    ", level) .. "}"
            return result
        end
        
        local serializedConfig = serializeTable(table)
        file:write(serializedConfig)
        file:close()
        printc( 255, 183, 0, 255, "["..os.date("%H:%M:%S").."] Saved to ".. tostring(fullPath))
    end
end

local function LoadCFG(folder_name)
    local success, fullPath = filesystem.CreateDirectory(folder_name)
    local filepath = tostring(fullPath .. "/config.txt")
    local file = io.open(filepath, "r")

    if file then
        local content = file:read("*a")
        file:close()
        local chunk, err = load("return " .. content)
        if chunk then
            printc( 0, 255, 140, 255, "["..os.date("%H:%M:%S").."] Loaded from ".. tostring(fullPath))
            return chunk()
        else
            print("Error loading configuration:", err)
        end
    end
end


local saveMessageCounter = 0  -- Counter for the "Config Saved" message
local loadFailMessageCounter = 0  -- Counter for the "Failed to Load Config" message
local loadSuccessMessageCounter = 0  -- Counter for the "Config Loaded" message

local function doDraw()
    rockets = entities.FindByClass("CTFProjectile_Rocket")
    draw.SetFont(Fonts.Verdana)
    draw.Color(255, 255, 255, 255) --white color

    if input.IsButtonPressed( KEY_INSERT )then
        toggleMenu()
    end

    for i, rocket in pairs(rockets) do
        local rocketPos = rocket:GetAbsOrigin()

        
        local distance = (pLocal:GetAbsOrigin() - rocketPos):Length()
        local RocketVel = NormalizeVector(rocket:EstimateAbsVelocity())

        local Target =  rocketPos + (RocketVel * distance)

        local startpos = client.WorldToScreen(rocketPos)
        local rocketTrace = engine.TraceLine(rocketPos, Target, MASK_SHOT_HULL)
        local endpos = client.WorldToScreen(rocketTrace.endpos)

        --local destination = source1 + viewAngles * distance

        if startpos ~= nil and endpos ~= nil then
            draw.Color(255, 255, 255, 255)
            draw.Line(startpos[1], startpos[2], endpos[1], endpos[2])
        end
        if destination then
            local Walkto = client.WorldToScreen(destination)
            local ppos = client.WorldToScreen(pLocal:GetAbsOrigin())
            if Walkto ~= nil and ppos ~= nil then
                draw.Color(0, 255, 0, 255)
                draw.Line(ppos[1], ppos[2], Walkto[1], Walkto[2])
            end
        end
    end

        -- Drawing the threat points on screen
        for i, point in pairs(threatTable) do
            local screenPos = client.WorldToScreen(Vector3(point.point.x, point.point.y, point.point.z))
            if screenPos then
                draw.Color(0, 255, 0, 255)  -- Green color for points
                local x, y = screenPos[1], screenPos[2]
                draw.FilledRect(x - 2, y - 2, x + 2, y + 2)  -- Draw a small square centered at (x, y)
            end
        end

        -- Drawing the threat points on screen
        for i, point in pairs(navmesh) do
            local screenPos = client.WorldToScreen(Vector3(point.x, point.y, point.z))
            if screenPos then
                draw.Color(0, 255, 0, 255)  -- Green color for points
                local x, y = screenPos[1], screenPos[2]
                draw.FilledRect(x - 2, y - 2, x + 2, y + 2)  -- Draw a small square centered at (x, y)
            end
        end


    if Lbox_Menu_Open == true and ImMenu.Begin("Movement Lua", true) then -- managing the menu
        ImMenu.BeginFrame(1) -- tabs
            if ImMenu.Button("Main") then
                Menu.tabs.Main = true
                Menu.tabs.Visuals = false
                Menu.tabs.Config = false
            end

            if ImMenu.Button("Visuals") then
                Menu.tabs.Main = false
                Menu.tabs.Visuals = true
                Menu.tabs.Config = false
            end

            if ImMenu.Button("Config") then
                Menu.tabs.Main = false
                Menu.tabs.Visuals = false
                Menu.tabs.Config = true
            end
        ImMenu.EndFrame()

        if Menu.tabs.Main then
            ImMenu.BeginFrame(1)
            Menu.Main.Active = ImMenu.Checkbox("Active", Menu.Main.Active)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
                Menu.Main.AutoDodge = ImMenu.Checkbox("Auto Dodge", Menu.Main.AutoDodge)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
                Menu.Main.FastStop = ImMenu.Checkbox("Fast Stop", Menu.Main.FastStop)
                Menu.Main.FastAccel = ImMenu.Checkbox("Fast Acceleration", Menu.Main.FastAccel)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
                Menu.Main.AirBreak = ImMenu.Checkbox("Air Break", Menu.Main.AirBreak)
                Menu.Main.BeterAirDuck = ImMenu.Checkbox("Better Air Duck", Menu.Main.BeterAirDuck)
            ImMenu.EndFrame()

            --[[ImMenu.BeginFrame(1)
            Menu.Main.DodgeKey = ImMenu.Option("Dodge Key", Menu.Main.DodgeKey, {["Space"] = KEY_SPACE})
            ImMenu.EndFrame()]]

        end
        
        if Menu.tabs.Visuals then
            ImMenu.BeginFrame(1)
            ImMenu.Text("Visuals Settings")
            ImMenu.EndFrame()
            
            ImMenu.BeginFrame(1)
            Menu.Visuals.Active = ImMenu.Checkbox("Active", Menu.Visuals.Active)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Visuals.VisualizePoints = ImMenu.Checkbox("Visualize Points", Menu.Visuals.VisualizePoints)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Visuals.VisualizeDodgeDirection = ImMenu.Checkbox("Visualize Dodge Direction", Menu.Visuals.VisualizeDodgeDirection)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Visuals.VisualizeThreat = ImMenu.Checkbox("Visualize Threat", Menu.Visuals.VisualizeThreat)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Visuals.VisualizePredExplosion = ImMenu.Checkbox("Visualize Predicted Explosion", Menu.Visuals.VisualizePredExplosion)
            ImMenu.EndFrame()

            ImMenu.BeginFrame(1)
            Menu.Visuals.VisualizePointsFactors = ImMenu.Checkbox("Visualize Points Factors", Menu.Visuals.VisualizePointsFactors)
            ImMenu.EndFrame()
        end

        if Menu.tabs.Config then 
            ImMenu.BeginFrame(1)
        
            -- Show Config Saved message
            if saveMessageCounter > 0 then
                ImMenu.Text("Config Saved!")
                saveMessageCounter = saveMessageCounter - 1  -- Decrement the counter
            end
        
            -- Show Config Loaded message
            if loadSuccessMessageCounter > 0 then
                ImMenu.Text("Config Loaded!")
                loadSuccessMessageCounter = loadSuccessMessageCounter - 1  -- Decrement the counter
            end
        
            -- Show Failed to Load Config message
            if loadFailMessageCounter > 0 then
                ImMenu.Text("Failed to Load Config: File does not exist or is corrupt")
                loadFailMessageCounter = loadFailMessageCounter - 1  -- Decrement the counter
            end
            ImMenu.EndFrame()
            
            ImMenu.BeginFrame(1)
            -- Create/Save Config
            if ImMenu.Button("Create/Save CFG") then
                CreateCFG([[LBOX Movement Lua]], Menu)
                saveMessageCounter = 100  -- Set the counter to 100
            end
        
            -- Load Config
            if ImMenu.Button("Load CFG") then
                local status, loadedMenu = pcall(function() return assert(LoadCFG([[LBOX Movement Lua]])) end)
        
                if status then
                    Menu = loadedMenu
                    loadSuccessMessageCounter = 100  -- Set the counter to 100
                else
                    loadFailMessageCounter = 100  -- Set the counter to 100
                end
            end
        
            ImMenu.EndFrame()
        end
        ImMenu.End()
    end
end

--[[ Remove the menu when unloaded ]]--
local function OnUnload()                                -- Called when the script is unloaded
    UnloadLib() --unloading lualib
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

--[[ Unregister previous callbacks ]]--
callbacks.Unregister("CreateMove", "AMAT_CreateMove")            -- Unregister the "CreateMove" callback
callbacks.Unregister("Unload", "AMAT_Unload")                    -- Unregister the "Unload" callback
callbacks.Unregister("Draw", "AMAT_Draw")                        -- Unregister the "Draw" callback
--[[ Register callbacks ]]--
callbacks.Register("CreateMove", "AMAT_CreateMove", OnCreateMove)             -- Register the "CreateMove" callback
callbacks.Register("Unload", "AMAT_Unload", OnUnload)                         -- Register the "Unload" callback
callbacks.Register("Draw", "AMAT_Draw", doDraw)                               -- Register the "Draw" callback

--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded