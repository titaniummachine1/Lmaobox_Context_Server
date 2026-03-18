
local speed = 400 -- Scout speed in units per second
local best_route = {}  -- Global variable to store the best path
local max_value = 0    -- Global variable to store the maximum collected value
local distance_cache = {} -- Global cache for distances

-- Function to calculate time needed to reach a target position with caching
local function time_to_reach(pos1, pos2)
    -- Unique cache key for distance between two points
    local cache_key = tostring(pos1) < tostring(pos2) and tostring(pos1) .. tostring(pos2) or tostring(pos2) .. tostring(pos1)
    
    -- Retrieve from cache or calculate if not found
    local distance = distance_cache[cache_key] or (pos2 - pos1):Length()
    distance_cache[cache_key] = distance
    return distance
end

-- Recursive function to find the best route maximizing collected value, with pruning
local function find_best_branch(current_pos, remaining_money, collected_value, path, total_distance)
    local local_best_value = collected_value
    local local_best_path = path

    for i, money in ipairs(remaining_money) do
        local time_left = money:GetPropFloat("m_flLifetime")  -- Remaining time before disappearing
        local money_pos = money:GetAbsOrigin() -- Position of the money pack
        local distance_to_money = time_to_reach(current_pos, money_pos)

        -- Calculate the total time required to reach this money
        local time_to_money = (total_distance + distance_to_money) / speed

        -- Prune branch if it can't reach the money in time
        if time_to_money < time_left then
            local value = money:GetPropInt("m_nAmount") -- Monetary value of the money pack

            -- Create a new list excluding the current money to explore further
            local new_remaining_money = {}
            for j, m in ipairs(remaining_money) do
                if j ~= i then
                    table.insert(new_remaining_money, m)
                end
            end

            -- Recursively check this path with the updated position, value, and distance
            local branch_value, branch_path = find_best_branch(
                money_pos,
                new_remaining_money,
                collected_value + value,
                {table.unpack(path), money},
                total_distance + distance_to_money
            )

            -- Update the local best path if this branch yields a higher value
            if branch_value > local_best_value then
                local_best_value = branch_value
                local_best_path = branch_path
            end
        end
    end

    -- Update the global best route and max value if a new best path is found
    if local_best_value > max_value then
        max_value = local_best_value
        best_route = local_best_path
    end

    return local_best_value, local_best_path
end

-- Main function to initiate the search for the best route
local function find_optimal_route(start_pos, money_list)
    -- Reset the global cache and best values
    distance_cache = {}
    max_value = 0
    best_route = {}
    
    -- Start finding the best route
    max_value, best_route = find_best_branch(start_pos, money_list, 0, {}, 0)
end

-- Fetch money entities and calculate optimal route
local function CalculateOptimalMoneyRoute()
    -- Retrieve all currency packs
    local packs = entities.FindByClass("CCurrencyPack")
    local money_list = {}

    -- Filter and collect valid, non-dormant money packs
    for _, pack in pairs(packs) do
        if pack:IsValid() and not pack:IsDormant() then
            table.insert(money_list, pack)
        end
    end

    -- Get the player's current position as the starting point
    local player = entities.GetLocalPlayer()
    local start_position = player and player:GetAbsOrigin() or vector3(0, 0, 0) -- Default to (0,0,0) if player is nil

    -- Find the optimal route
    find_optimal_route(start_position, money_list)
end

-- Function to draw the optimal path
local function DrawOptimalPath()
    if #best_route == 0 then return end

    -- Set drawing color (e.g., red)
    draw.Color(255, 0, 0, 255)

    local previous_screen_pos = nil

    for _, money in ipairs(best_route) do
        local world_pos = money:GetAbsOrigin()
        local screen_pos = client.WorldToScreen(world_pos)

        if screen_pos then
            -- Draw a small rectangle at the money's position
            draw.FilledRect(screen_pos[1] - 1, screen_pos[2] - 1, screen_pos[1] + 1, screen_pos[2] + 1)

            -- Draw a line from the previous money to the current one
            if previous_screen_pos then
                draw.Line(previous_screen_pos[1], previous_screen_pos[2], screen_pos[1], screen_pos[2])
            end

            previous_screen_pos = screen_pos
        end
    end
end

-- Wrapper function for the Draw callback
local function CalculateAndDrawOptimalMoneyRoute()
    CalculateOptimalMoneyRoute()
    DrawOptimalPath()
end

-- Register the Draw callback to trigger the route calculation and drawing
callbacks.Register("Draw", "CalculateAndDrawOptimalMoneyRoute", CalculateAndDrawOptimalMoneyRoute)
