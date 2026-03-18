local sourcenav = require "sourcenav"

---@type boolean, lnxLib
local libLoaded, lnxLib = pcall(require, "lnxLib")
assert(libLoaded, "lnxLib not found, please install it!")
UnloadLib() --unloads all packages

local Math, Conversion = lnxLib.Utils.Math, lnxLib.Utils.Conversion
local WPlayer, WWeapon = lnxLib.TF2.WPlayer, lnxLib.TF2.WWeapon
local Helpers = lnxLib.TF2.Helpers
local Prediction = lnxLib.TF2.Prediction
local Fonts = lnxLib.UI.Fonts

SIGNONSTATE_NONE = 0 -- no state yet, about to connect
SIGNONSTATE_CHALLENGE = 1 -- client challenging server, all OOB packets
SIGNONSTATE_CONNECTED = 2 -- client is connected to server, netchans ready
SIGNONSTATE_NEW = 3 -- just got serverinfo and string tables
SIGNONSTATE_PRESPAWN = 4 -- received signon buffers
SIGNONSTATE_SPAWN = 5 -- ready to receive entity packets
SIGNONSTATE_FULL = 6 -- we are fully connected, first non-delta packet received
SIGNONSTATE_CHANGELEVEL = 7 -- server is changing level, please wait

local nav_area_attributes = {
    CROUCH = 0x1, --must crouch to use this node/area
    JUMP = 0x2, --must jump to traverse this area (only used during generation)
    PRECISE = 0x4,	--do not adjust for obstacles, just move along area
    NO_JUMP = 0x8,	--inhibit discontinuity jumping
    STOP = 0x10, --must stop when entering this area
    RUN = 0x20,	--must run to traverse this area
    WALK = 0x40, --must walk to traverse this area
    AVOID = 0x80, --avoid this area unless alternatives are too dangerous
    TRANSIENT = 0x100, --area may become blocked, and should be periodically checked
    DONT_HIDE = 0x200, --area should not be considered for hiding spot generation
    STAND = 0x400, --bots hiding in this area should stand
    NO_HOSTAGES = 0x800, --hostages shouldn't use this area
    STAIRS = 0x1000, --this area represents stairs, do not attempt to climb or jump them - just walk up
    NO_MERGE = 0x2000, --don't merge this area with adjacent areas
    OBSTACLE_TOP = 0x4000, --this nav area is the climb point on the tip of an obstacle
    CLIFF = 0x8000, --this nav area is adjacent to a drop of at least CliffHeight

    FIRST_CUSTOM = 0x10000, --apps may define custom app-specific bits starting with this value
    LAST_CUSTOM = 0x4000000, --apps must not define custom app-specific bits higher than with this value
    FUNC_COST = 0x20000000, --area has designer specified cost controlled by func_nav_cost entities

    HAS_ELEVATOR = 0x40000000, --area is in an elevator's path
    NAV_BLOCKER = 0x80000000, --area is blocked by nav blocker ( Alas, needed to hijack a bit in the attributes to get within a cache line [7/24/2008 tom])
}

local config = {
	square = {
		enabled = true;
		r = 55;
		g = 255;
		b = 155;
		a = 50;
	};
	
	line = {
		enabled = true;
		r = 255;
		g = 255;
		b = 255;
		a = 100;
	};
};

-- Manhattan distance between two points
local function manhattanDistance(a, b)
    return math.abs(a.x - b.x) + math.abs(a.y - b.y) + math.abs(a.z - b.z)
end

-- Function to get the center of an area
local function get_area_center(area)
    local center = Vector3()
    if area.north_west then
        center.x = (area.north_west.x + area.south_east.x) / 2
        center.y = (area.north_west.y + area.south_east.y) / 2
        center.z = (area.north_west.z + area.south_east.z) / 2
        return center
    elseif area then
        center = Vector3(area.x, area.y, area.z)
        return center
    end
    return nil
end

-- Function to adjust the area's orientation based on a surface normal obtained from a trace
local function adjustAreaOrientation(area)
    local traceStart = Vector3(area.pos.x, area.pos.y, area.pos.z + 10)
    local traceEnd = Vector3(area.pos.x, area.pos.y, area.pos.z - 10)
    local hitResult = engine.TraceLine(traceStart, traceEnd, MASK_PLAYERSOLID)
    
    if hitResult and hitResult.fraction < 1 then
        local normal = hitResult.plane
        area.orientation = normal  -- Update the area's orientation based on the surface normal
    end
end


-- Global variables to hold the parsed navmesh and areas
local navData
local parsed_areas

-- Helper function to open, read, and parse the nav file
local function open_nav_file(map_name, basedir)
    -- Validate map name
    if map_name:len() < 1 then
        print("Invalid map name.")
        return nil
    end

    -- Construct the filename
    basedir = basedir or engine.GetGameDir()
    local filename = string.format('%s/%s', basedir, map_name:gsub('.bsp$', '.nav'))

    -- Open the file
    local file = io.open(filename, 'rb')

    -- If file not found, generate a new navmesh
    if not file then
        client.RemoveConVarProtection("sv_cheats")
        client.RemoveConVarProtection("nav_generate")
        client.SetConVar("sv_cheats", "1")
        client.Command("nav_generate", true)
        print("Generated navmesh. Please reload Lua to read the new navmesh.")
        return nil
    end

    -- Read and parse the nav file
    local content = file:read('a')
    file:close()
    local nav = sourcenav.parse(content)

    -- Validate nav file version
    assert(nav.minor == 2, "Invalid minor version, must be 2.")
    return nav
end

-- Function to generate a grid of points within an area, considering rotation
local function generate_points(area)
    local points = {}
    local step = 60  -- Grid step in units. Adjust based on your needs.
    local edge_buffer = 12  -- Distance from edges

    local nw = area.north_west
    local se = area.south_east

    -- Calculate dimensions of the area
    local dim_x = math.abs(se.x - nw.x) - 2 * edge_buffer
    local dim_y = math.abs(se.y - nw.y) - 2 * edge_buffer

    -- Calculate the starting point for the grid, so that it's edge_buffer units away from the edges
    local start_x = nw.x + edge_buffer
    local start_y = nw.y + edge_buffer

    -- Calculate the number of points (steps) that fit within the adjusted dimensions
    local steps_x = math.floor(dim_x / step)
    local steps_y = math.floor(dim_y / step)

    -- Center the grid by adjusting the starting point
    local extra_space_x = dim_x - steps_x * step
    local extra_space_y = dim_y - steps_y * step

    start_x = start_x + extra_space_x / 2
    start_y = start_y + extra_space_y / 2

    -- Generate points
    for i = 0, steps_x do
        for j = 0, steps_y do
            local point_x = start_x + i * step
            local point_y = start_y + j * step
            local point_z = nw.z  -- Assuming the area is flat

            -- Add the point to the points table
            table.insert(points, {pos = Vector3(point_x, point_y, point_z), neighbors = {}, id = #points + 1})
        end
    end

    -- Function to assign neighbors to each point
    for i, point_a in ipairs(points) do
        for j, point_b in ipairs(points) do
            if i ~= j then  -- Skip self
                local distance = manhattanDistance(point_a.pos, point_b.pos)
                if distance <= (step * 2) + 1 then  -- Check if within maximum allowed distance
                    table.insert(point_a.neighbors, {point = point_b, cost = distance})
                end
            end
        end
    end

    -- If no points are generated, add a single point at area.pos
    if #points == 0 then
        table.insert(points, {pos = get_area_center(area), neighbors = {}, id = #points + 1})
    end

    return points
end

-- Function to fetch and parse the navmesh
local function GetNavMesh()
    print("Fetching NavMesh file...")

    -- Get the current map name
    local current_map = engine.GetMapName()

    -- Open and parse the nav file
    navData = open_nav_file(current_map)

    -- Validate and print navData properties
    if navData then
        local places_count = navData.places and #navData.places or "N/A"
        local areas_count = navData.areas and #navData.areas or "N/A"
        local total_connections = 0
        local hiding_spots_count = 0  -- Initialize hiding spots count

        -- Iterate through areas to count connections and hiding spots
        for _, area in ipairs(navData.areas) do
            for dir, connections_dir in pairs(area.connections) do
                total_connections = total_connections + connections_dir.count
            end

            -- Count hiding spots if they exist
            if area.hiding_spots then
                hiding_spots_count = hiding_spots_count + #area.hiding_spots
            end
        end

        print(string.format("Parsed %s places, %s areas, %d connections, %d hiding spots.", 
                            places_count, areas_count, total_connections, hiding_spots_count))
    else
        print("navData is not available.")
        return nil
    end


    -- Initialize parsed_areas table
    parsed_areas = {}

    -- Loop through all areas in navData.areas
    for _, area in ipairs(navData.areas) do
        local area_id = area.id
        local area_pos = get_area_center(area)  -- Assuming this function returns a Vector3
        -- Hiding Spots
        local hiding_spots_positions = {}
        for _, hiding_spot in ipairs(area.hiding_spots) do
            local location = hiding_spot.location
            if location then
                -- Convert to Vector3 (Replace with your game's Vector3 constructor if needed)
                local vector3_position = Vector3(location.x, location.y, location.z)
                table.insert(hiding_spots_positions, vector3_position)
            end
        end

        -- Connections of areas
        local connections_out = {}
        for dir, connections_dir in pairs(area.connections) do
            local dir_connections = {}
            for _, target_id in ipairs(connections_dir.connections) do
                -- You can also convert target positions to Vector3 here, similar to hiding_spots_positions
                table.insert(dir_connections, target_id)
            end
            connections_out[dir] = dir_connections
        end

        -- Store parsed data
        parsed_areas[area_id] = {
            pos = area_pos,
            hiding_spots = hiding_spots_positions,
            connections_out = connections_out,
            flags = area.flags,  -- store flags if needed
            points = {}
        }

        parsed_areas[area_id].points = generate_points(area)
        --print(area.flags) -- keep for later
    end

    return navData, parsed_areas  -- Return the parsed nav_data
end

navData, parsed_areas = GetNavMesh()

--printLuaTable(navData.areas)

callbacks.Register( 'FireGameEvent', function( event )

    if event:GetName() == 'player_connect_full' then
        --navData = GetNavMesh()
    end

    if event:GetName() == 'round_prestart' then

    end

    if event:GetName() == 'player_spawn' then

    end

end )

-- Cached visibility checks
local areaVisibilityCache = {}

-- Check if a value exists in a table
local function inSet(set, value)
    for _, v in ipairs(set) do
        if v == value then
            return true
        end
    end
    return false
end

-- Reconstruct the path
local function reconstruct_path(cameFrom, current)
    local path = {current}
    while cameFrom[current] do
        current = cameFrom[current]
        table.insert(path, 1, current)
    end
    return path
end

-- A* for Points
local function AStar_Points(startPoint, endPoint, allPoints)
    local openSet = {startPoint}
    local cameFrom = {}
    local gScore = {}
    local fScore = {}
    
    gScore[startPoint] = 0
        
    fScore[startPoint] = manhattanDistance(startPoint, endPoint)

    local iteration = 0  -- To count the number of iterations

    while #openSet > 0 do
        print("Iteration: ", iteration)
        iteration = iteration + 1

        local current = openSet[1]
        
        for _, point in ipairs(openSet) do
            if fScore[point] < fScore[current] then
                current = point
            end
        end

        if current == endPoint then
            print("Path found!")
            return reconstruct_path(cameFrom, current)
        end

        for i, point in ipairs(openSet) do
            if point == current then
                table.remove(openSet, i)
                break
            end
        end

        for _, neighbor in ipairs(allPoints) do
            local tentative_gScore = gScore[current] + manhattanDistance(current, neighbor)

            if tentative_gScore < (gScore[neighbor] or math.huge) then
                cameFrom[neighbor] = current
                gScore[neighbor] = tentative_gScore
                fScore[neighbor] = gScore[neighbor] + manhattanDistance(neighbor, endPoint)

                if not inSet(openSet, neighbor) then
                    table.insert(openSet, neighbor)
                end
            end
        end
    end

    if iteration >= maxIterations then
        print("Reached maximum iterations, exiting loop.")
    end

    print("No path found.")
    return nil
end

-- Example usage
--local startPoint = Vector3(0,0,0)  -- Replace with your actual start point
--local endPoint = Vector3(10,10,10)  -- Replace with your actual end point

--local path = AStar_Points(startPoint, endPoint, allPoints)
-- You can replace 'print' with your own function to print tables, like 'printLuaTable'
--print(path)





----------------------------DRAWING CODE---------------------------------------------------
local white_texture = draw.CreateTextureRGBA(string.char(
	0xff, 0xff, 0xff, config.square.a,
	0xff, 0xff, 0xff, config.square.a,
	0xff, 0xff, 0xff, config.square.a,
	0xff, 0xff, 0xff, config.square.a
), 2, 2);

local drawPolygon = (function()
	local v1x, v1y = 0, 0;
	local function cross(a, b)
		return (b[1] - a[1]) * (v1y - a[2]) - (b[2] - a[2]) * (v1x - a[1])
	end

	local TexturedPolygon = draw.TexturedPolygon;

	return function(vertices)
		local cords, reverse_cords = {}, {};
		local sizeof = #vertices;
		local sum = 0;

		v1x, v1y = vertices[1][1], vertices[1][2];
		for i, pos in pairs(vertices) do
			local convertedTbl = {pos[1], pos[2], 0, 0};

			cords[i], reverse_cords[sizeof - i + 1] = convertedTbl, convertedTbl;

			sum = sum + cross(pos, vertices[(i % sizeof) + 1]);
		end


		TexturedPolygon(white_texture, (sum < 0) and reverse_cords or cords, true)
	end
end)();

local corners1


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

-- Assuming you have a Vector3 function and WorldToScreen function from your API
local drawLine, WorldToScreen = draw.Line, client.WorldToScreen
local DrawDist = 700 --render distance
-- Flag to indicate whether lines have been cached
local lines_cached = false


local function doDraw()
    draw.SetFont(Fonts.Verdana)
    draw.Color(255, 255, 255, 255)
    
    local pLocal = entities.GetLocalPlayer()
    if not pLocal or not pLocal:IsAlive() then return end

    -- Check if navData exists
    if not navData or not parsed_areas then return end  -- Replacing goto with return for better readability

    for _, area in pairs(parsed_areas) do  -- Assuming parsed_areas contains all your areas
        if (area.pos - pLocal:GetAbsOrigin()):Length() < DrawDist then --distance check

            -- Iterate through each hiding spot in the current area
            for _, hidingSpot in ipairs(area.hiding_spots) do  -- Assuming hiding_spots is an array of Vector3 positions
                local screenPos = client.WorldToScreen(Vector3(hidingSpot.x, hidingSpot.y, hidingSpot.z))
                if screenPos then
                    draw.Color(255, 0, 0, 255)  -- Red color for hiding spots
                    Draw3DBox(10, hidingSpot)  -- Assuming the size of the cube is 10
                end
            end

            -- Table to keep track of already drawn connections
            local drawn_connections = {}

            -- Draw points as small squares on the screen
            for _, point in ipairs(area.points) do  -- Assuming points is an array of Vector3 positions
                local screenPos = client.WorldToScreen(Vector3(point.pos.x, point.pos.y, point.pos.z))
                if screenPos then
                    draw.Color(0, 255, 0, 255)  -- Green color for points
                    local x, y = screenPos[1], screenPos[2]
                    draw.FilledRect(x - 2, y - 2, x + 2, y + 2)  -- Draw a small square centered at (x, y)
                end

                local start_pos = point.pos
                local start_screen = WorldToScreen(Vector3(start_pos.x, start_pos.y, start_pos.z))
                
                for _, neighbor in ipairs(point.neighbors) do  -- Assuming neighbors contains direct neighbors
                    local end_pos = neighbor.point.pos

                    -- Generate a unique identifier for each pair of connected points
                    local connection_id = math.min(point.id, neighbor.point.id) .. "-" .. math.max(point.id, neighbor.point.id)

                    -- Only draw the line if this connection hasn't been drawn yet
                    if not drawn_connections[connection_id] then
                        local end_screen = WorldToScreen(Vector3(end_pos.x, end_pos.y, end_pos.z))
                        
                        if start_screen and end_screen then
                            draw.Color(0, 255, 0, 255)  -- Green color for point-to-point connections
                            draw.Line(start_screen[1], start_screen[2], end_screen[1], end_screen[2])
                        end

                        -- Mark this connection as drawn
                        drawn_connections[connection_id] = true
                    end
                end

            end

            -- New code to draw lines between connected areas
            for dir, connected_areas in pairs(area.connections_out) do
                for _, target_id in ipairs(connected_areas) do
                    local target_area = parsed_areas[target_id]
                    if target_area then
                        local start_pos = area.pos
                        local end_pos = target_area.pos

                        -- Convert start and end positions to screen coordinates
                        local start_screen = WorldToScreen(Vector3(start_pos.x, start_pos.y, start_pos.z))
                        local end_screen = WorldToScreen(Vector3(end_pos.x, end_pos.y, end_pos.z))

                        if start_screen and end_screen then
                            draw.Color(255, 255, 0, 255)  -- Yellow color for connections
                            draw.Line(start_screen[1], start_screen[2], end_screen[1], end_screen[2])
                        end
                    end
                end
            end
        end
    end

    -- Iterate over all parsed areas
    for _, area in pairs(navData.areas) do
        local nw = area.north_west  -- Assuming a table with x, y, z keys
        local se = area.south_east  -- Assuming a table with x, y, z keys

        if (area.pos - pLocal:GetAbsOrigin()):Length() < DrawDist then --distance check
            -- Calculate the other two corners
            local ne = { x = se.x, y = nw.y, z = nw.z }
            local sw = { x = nw.x, y = se.y, z = se.z }

            local corners = {nw, ne, se, sw}

            -- Convert each point to screen coordinates
            local screenPoints = {}
            local polygonVertices = {}  -- for drawPolygon
            for i, point in ipairs(corners) do
                local vec3_point = Vector3(point.x, point.y, point.z)  -- Convert to Vector3
                local screenPos = WorldToScreen(vec3_point)
                if screenPos then
                    table.insert(screenPoints, { x = screenPos[1], y = screenPos[2] })
                    table.insert(polygonVertices, { screenPos[1], screenPos[2] })  -- Prepare for drawPolygon
                else
                    goto continue  -- Skip drawing if any point is not on the screen
                end
            end

            -- Draw polygon using drawPolygon function
            draw.Color(config.square.r, config.square.g, config.square.b, config.square.a)
            drawPolygon(polygonVertices)

            -- Draw polygon outline
            draw.Color(255, 255, 255, 255)
            local linesToDraw = { {1, 2}, {2, 3}, {3, 4}, {4, 1} }
            for _, line in ipairs(linesToDraw) do
                local p1, p2 = screenPoints[line[1]], screenPoints[line[2]]
                if p1 and p2 then
                    draw.Line(p1.x, p1.y, p2.x, p2.y)
                end
            end
        end
        ::continue::
    end
end

local function OnUnload()                                -- Called when the script is unloaded
    UnloadLib() --unloading lualib
    client.Command('play "ui/buttonclickrelease"', true) -- Play the "buttonclickrelease" sound
end

callbacks.Unregister("Draw", "NavBot_DrawX")                        -- Unregister the "Draw" callback
callbacks.Register("Draw", "NavBot_DrawX", doDraw)                               -- Register the "Draw" callback

callbacks.Unregister("Unload", "MCT_Unload")                    -- Unregister the "Unload" callback
callbacks.Register("Unload", "MCT_Unload", OnUnload)                         -- Register the "Unload" callback
--[[ Play sound when loaded ]]--
client.Command('play "ui/buttonclick"', true) -- Play the "buttonclick" sound when the script is loaded