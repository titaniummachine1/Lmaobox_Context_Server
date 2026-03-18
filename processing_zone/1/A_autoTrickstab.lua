local function determine_direction(my_pos, enemy_pos, hitbox_size, vertical_range)
    local dx = enemy_pos.x - my_pos.x
    local dy = enemy_pos.y - my_pos.y
    local dz = enemy_pos.z - my_pos.z

    local out_of_vertical_range = (math.abs(dz) > vertical_range) and 1 or 0

    local direction_x = ((dx > hitbox_size) and 1 or 0) - ((dx < -hitbox_size) and 1 or 0)
    local direction_y = ((dy > hitbox_size) and 1 or 0) - ((dy < -hitbox_size) and 1 or 0)

    return {(direction_x * (1 - out_of_vertical_range)), (direction_y * (1 - out_of_vertical_range))}
end

local function get_best_corners_or_origin(my_pos, enemy_pos, hitbox_size, vertical_range)
    local corners = {
        Vector3(-49.0, 49.0, 0.0),  -- top left corner
        Vector3(49.0, 49.0, 0.0),   -- top right corner
        Vector3(-49.0, -49.0, 0.0), -- bottom left corner
        Vector3(49.0, -49.0, 0.0)   -- bottom right corner
    }

    local direction_to_corners = {
        [-1] = {
            [-1] = {corners[1], corners[4]},  -- Top-left
            [0] = {corners[1], corners[3]},   -- Left
            [1] = {corners[3], corners[2]}    -- Bottom-left
        },
        [0] = {
            [-1] = {corners[3], corners[4]},  -- Down
            [0] = {enemy_pos},                -- Middle (out of hitbox bounds)
            [1] = {corners[1], corners[2]}    -- Up
        },
        [1] = {
            [-1] = {corners[2], corners[3]},  -- Bottom-right
            [0] = {corners[2], corners[4]},   -- Right
            [1] = {corners[4], corners[1]}    -- Top-right
        }
    }

    local direction = determine_direction(my_pos, enemy_pos, hitbox_size, vertical_range)
    return direction_to_corners[direction[1]][direction[2]]
end

-- Example usage
local my_position = Vector3(-100.0, 100.0, 0.0)
local enemy_position = Vector3(0.0, 0.0, 0.0)
local hitbox_size = 49.0
local vertical_range = 83.0

-- Get the best corners or origin
local best_corners_or_origin = get_best_corners_or_origin(my_position, enemy_position, hitbox_size, vertical_range)
print("Best corners or origin relative to enemy direction:")
for i, point in ipairs(best_corners_or_origin) do
    print(string.format("  Point %d: (%.1f, %.1f, %.1f)", i, point.x, point.y, point.z))
end