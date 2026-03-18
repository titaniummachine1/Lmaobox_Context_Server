-- Requires lnxlib for WEntity:IsVisible() and Math functions
local lnxLoaded, LNX = pcall(require, "lnxlib")
assert(lnxLoaded, "lnxlib not found!")

local WEntity = LNX.WEntity
local Math = LNX.Utils.Math

--------------------------------------------------
-- CONFIGURATION
--------------------------------------------------
-- Prediction settings
local HISTORY_SIZE = 16          -- Reduced for simplicity
local PREDICTION_TICKS = 16      -- Prediction length
local DRAW_DISTANCE = 250        -- Increased distance to draw prediction points
local MOVEMENT_THRESHOLD = 0.6   -- Lower threshold to detect mouse movement (more sensitive)
local INACTIVE_DELAY = 0.3       -- Longer time without movement before considered inactive
local PREDICTION_SCALE = 2.5     -- Increased scale for more visible predictions
local TIME_FACTOR = 0.07         -- Time scaling for prediction points
local STABILIZATION_FACTOR = 0.7 -- How much to consider future adjustments (0-1)
local ADJUSTMENT_DECAY = 0.85    -- How quickly adjustment influence decays with distance
local MAX_DIRECTION_CHANGE = 65  -- Increased to be less strict with angle constraints

-- Motion settings
local VELOCITY_THRESHOLD = 2.0 -- Ignore movements below this threshold

-- Visual settings
local LINE_THICKNESS = 2        -- Line thickness
local POINT_SIZE = 2            -- Point size
local LINE_ALPHA = 128          -- Line transparency
local POINT_ALPHA = 150         -- Point transparency
local POINT_OUTLINE_ALPHA = 100 -- Point outline transparency

-- Pitch limits (to prevent crazy angles)
local MAX_PITCH = 84.9  -- Maximum upward pitch angle
local MIN_PITCH = -84.9 -- Minimum downward pitch angle

-- Aim assist settings
local INITIAL_FOV_SCAN = 60           -- Wide initial FOV scan to catch potential targets
local FOV_THRESHOLD = 7               -- Deadzone size and targeting threshold
local MAX_ANGLE_CHANGE = 1.5          -- Maximum angle change per tick (reduced for subtler adjustments)
local TARGET_HITGROUP = 1             -- 1=head
local TRAJECTORY_ADJUST_FACTOR = 0.4  -- Reduced for even more subtle effect (was 0.75)
local MAX_PREDICTION_DISTANCE = 24    -- Increased upper limit for better prediction distance
local ENABLE_TRAJECTORY_ADJUST = true -- Toggle for trajectory adjustment
local RESPECT_MOVEMENT_INTENT = true  -- Whether to respect user's movement intent
local DEBUG_MODE = true               -- Show debug information on screen
local DEBUG_TARGETS = true            -- Show extended target debugging
local DUMP_ALL_ENTITIES = true        -- Dump all entity info for first few frames
local IGNORE_VISIBILITY = true        -- Ignore visibility checks (all entities are considered visible)
local TRAJECTORY_MODE = true          -- Use trajectory modification instead of direct aiming

-- Aimbot modes
local aimbot_mode = { plain = "plain", smooth = "smooth", silent = "silent", assistance = "assistance" }
local CURRENT_AIMBOT_MODE = aimbot_mode.plain

-- Visual settings
local Verdana = draw.CreateFont("Verdana", 16, 800)
local prediction_path = {}       -- Points to display prediction path
local best_target = nil          -- Current best target angle
local global_fov_stop_tick = nil -- Track when FOV increases stop prediction

-- Hitbox constants
local Hitbox = {
    Head = 1,
    Neck = 2,
    Pelvis = 4,
    Body = 5,
    Chest = 7
}

--------------------------------------------------
-- UTILITY FUNCTIONS
--------------------------------------------------
--- Normalizes an angle to (-180, 180] range
function NormalizeAngle(angle)
    -- Check if angle is nil
    if angle == nil then
        return 0 -- Return 0 as a safe default when angle is nil
    end

    angle = angle % 360
    if angle > 180 then
        angle = angle - 360
    elseif angle <= -180 then
        angle = angle + 360
    end
    return angle
end

--- Clamps a pitch angle to prevent flipping
function ClampPitch(pitch)
    return math.max(MIN_PITCH, math.min(MAX_PITCH, pitch))
end

--- Gets the shortest distance between two angles
function AngleDifference(a1, a2)
    -- Check if either input is nil and return immediately
    if a1 == nil then
        return 0 -- Return 0 as a safe default when a1 is nil
    end

    if a2 == nil then
        return 0 -- Return 0 as a safe default when a2 is nil
    end

    -- Now that we know both values are not nil, we can safely perform the arithmetic
    return NormalizeAngle(a1 - a2)
end

--- Convert world position to screen position
function WorldToScreen(pos)
    local screen = client.WorldToScreen(pos)
    if screen then
        return { x = math.floor(screen[1]), y = math.floor(screen[2]) }
    end
    return nil
end

--- Calculate angle between two 3D points
function CalcAngle(from, to)
    local dir = Vector3(to.x - from.x, to.y - from.y, to.z - from.z)
    local len = dir:Length()

    -- Avoid division by zero
    if len < 0.001 then
        return EulerAngles(0, 0, 0)
    end

    -- Normalize using vector / length (as per user's instructions)
    local normalized = Vector3(dir.x / len, dir.y / len, dir.z / len)

    local pitch = math.deg(math.asin(-normalized.z))
    local yaw = math.deg(math.atan(normalized.y, normalized.x))

    -- Clamp pitch to valid range
    pitch = ClampPitch(pitch)

    return EulerAngles(pitch, yaw, 0)
end

--------------------------------------------------
-- PREDICTION SYSTEM
--------------------------------------------------
-- Storage for view angle history and mouse movement status
local angle_history = {}
local last_mouse_move_time = 0
local is_mouse_active = false

-- For trajectory tracking
local last_direction = { x = 0, y = 0 }
local last_velocity = { pitch = 0, yaw = 0 }

--- Records view angle and its timestamp
function RecordViewAngle(angle, timestamp, mousedx, mousedy)
    -- Make sure mousedx and mousedy are valid numbers
    mousedx = mousedx or 0
    mousedy = mousedy or 0

    -- Update mouse activity status
    local mouse_moving = (math.abs(mousedx) > MOVEMENT_THRESHOLD or math.abs(mousedy) > MOVEMENT_THRESHOLD)

    if mouse_moving then
        is_mouse_active = true
        last_mouse_move_time = timestamp

        -- Update last direction when mouse is moving
        local dir_length = math.sqrt(mousedx * mousedx + mousedy * mousedy)
        if dir_length > 0.001 then
            last_direction = {
                x = mousedx / dir_length,
                y = mousedy / dir_length
            }
        end
    elseif timestamp - last_mouse_move_time > INACTIVE_DELAY then
        is_mouse_active = false
    end

    -- Only add to history if mouse is active to prevent lingering predictions
    if is_mouse_active then
        -- Add to history, but ensure angles are normalized and clamped
        table.insert(angle_history, {
            pitch = ClampPitch(angle.pitch),
            yaw = NormalizeAngle(angle.yaw),
            time = timestamp,
            mousedx = mousedx,
            mousedy = mousedy,
            -- Store normalized mouse direction
            direction = {
                x = (dir_length and dir_length > 0.001) and (mousedx / dir_length) or last_direction.x,
                y = (dir_length and dir_length > 0.001) and (mousedy / dir_length) or last_direction.y
            }
        })

        -- Keep history size limited
        if #angle_history > HISTORY_SIZE then
            table.remove(angle_history, 1)
        end
    else
        -- Clear history when mouse is inactive
        angle_history = {}
        last_velocity = { pitch = 0, yaw = 0 }
    end
end

--- Calculate the average mouse direction from history
function GetAverageDirection()
    if #angle_history < 2 then
        return last_direction
    end

    -- Use up to 7 most recent entries (or whatever is available)
    local history_limit = math.min(7, #angle_history)

    -- Initialize direction accumulators
    local avg_dir_x = 0
    local avg_dir_y = 0
    local total_weight = 0
    local valid_samples = 0

    -- Accumulate weighted direction vectors from history
    for i = #angle_history - history_limit + 1, #angle_history do
        if i < 1 then goto continue end

        local entry = angle_history[i]

        -- Skip entries with zero direction
        local dir_valid = (entry.direction.x ~= 0 or entry.direction.y ~= 0)
        if not dir_valid then goto continue end

        -- Apply weight (more recent entries are more important)
        -- The weight increases linearly from oldest to newest
        local weight = (i - (#angle_history - history_limit)) / history_limit

        -- Add weighted direction
        avg_dir_x = avg_dir_x + (entry.direction.x * weight)
        avg_dir_y = avg_dir_y + (entry.direction.y * weight)
        total_weight = total_weight + weight
        valid_samples = valid_samples + 1

        ::continue::
    end

    -- If we don't have enough valid samples, use the latest entry or last_direction
    if valid_samples < 2 or total_weight < 0.1 then
        if #angle_history > 0 then
            local latest = angle_history[#angle_history]
            if latest.direction.x ~= 0 or latest.direction.y ~= 0 then
                return latest.direction
            end
        end
        return last_direction
    end

    -- Normalize by total weight
    avg_dir_x = avg_dir_x / total_weight
    avg_dir_y = avg_dir_y / total_weight

    -- Normalize the resulting vector
    local length = math.sqrt(avg_dir_x * avg_dir_x + avg_dir_y * avg_dir_y)
    if length < 0.001 then
        return last_direction
    end

    -- Return normalized average direction
    return {
        x = avg_dir_x / length,
        y = avg_dir_y / length
    }
end

--- Calculate average velocity from historical data for stable prediction
function CalculateMotion()
    -- Need at least 2 samples for velocity
    if #angle_history < 2 then
        return {
            velocity_pitch = 0,
            velocity_yaw = 0,
            direction = last_direction,
            magnitude = 0
        }
    end

    -- Calculate average velocity from multiple history entries for stability
    local avg_velocity_pitch = 0
    local avg_velocity_yaw = 0
    local total_weight = 0
    local samples_used = 0

    -- Use up to 7 most recent entries (or whatever is available)
    local history_limit = math.min(7, #angle_history)

    -- Process from oldest to newest (most recent has highest weight)
    for i = #angle_history - history_limit + 1, #angle_history do
        if i < 2 then goto continue end -- Skip if we can't calculate velocity

        local current = angle_history[i]
        local previous = angle_history[i - 1]

        -- Time delta between samples
        local time_delta = current.time - previous.time

        -- Skip invalid time deltas
        if time_delta < 0.001 then goto continue end

        -- Calculate velocity for this sample
        local pitch_diff = AngleDifference(current.pitch, previous.pitch)
        local yaw_diff = AngleDifference(current.yaw, previous.yaw)

        local velocity_pitch = pitch_diff / time_delta
        local velocity_yaw = yaw_diff / time_delta

        -- Skip tiny movements
        if math.abs(velocity_pitch) < VELOCITY_THRESHOLD and
            math.abs(velocity_yaw) < VELOCITY_THRESHOLD then
            goto continue
        end

        -- Apply weight (more recent entries are more important)
        -- The weight increases linearly from oldest to newest
        local weight = (i - (#angle_history - history_limit)) / history_limit

        -- Add weighted velocity to average
        avg_velocity_pitch = avg_velocity_pitch + (velocity_pitch * weight)
        avg_velocity_yaw = avg_velocity_yaw + (velocity_yaw * weight)
        total_weight = total_weight + weight
        samples_used = samples_used + 1

        ::continue::
    end

    -- If we don't have enough valid samples, use the most recent one
    if samples_used < 2 or total_weight < 0.1 then
        local latest = angle_history[#angle_history]
        local previous = angle_history[#angle_history - 1]

        -- Time delta
        local time_delta = latest.time - previous.time

        -- Avoid division by zero
        if time_delta < 0.001 then
            return {
                velocity_pitch = 0,
                velocity_yaw = 0,
                direction = GetAverageDirection(),
                magnitude = math.sqrt(latest.mousedx * latest.mousedx + latest.mousedy * latest.mousedy)
            }
        end

        -- Calculate basic pitch/yaw velocities
        local pitch_diff = AngleDifference(latest.pitch, previous.pitch)
        local yaw_diff = AngleDifference(latest.yaw, previous.yaw)

        avg_velocity_pitch = pitch_diff / time_delta
        avg_velocity_yaw = yaw_diff / time_delta

        -- Apply velocity threshold
        if math.abs(avg_velocity_pitch) < VELOCITY_THRESHOLD then
            avg_velocity_pitch = 0
        end

        if math.abs(avg_velocity_yaw) < VELOCITY_THRESHOLD then
            avg_velocity_yaw = 0
        end
    else
        -- Normalize by total weight
        avg_velocity_pitch = avg_velocity_pitch / total_weight
        avg_velocity_yaw = avg_velocity_yaw / total_weight
    end

    -- Store for next frame
    last_velocity.pitch = avg_velocity_pitch
    last_velocity.yaw = avg_velocity_yaw

    -- Apply limits to prevent extreme values
    local max_velocity = 400
    avg_velocity_pitch = math.max(-max_velocity, math.min(max_velocity, avg_velocity_pitch))
    avg_velocity_yaw = math.max(-max_velocity, math.min(max_velocity, avg_velocity_yaw))

    -- Get average mouse direction
    local avg_direction = GetAverageDirection()

    -- Calculate mouse movement magnitude
    local latest = angle_history[#angle_history]
    local magnitude = math.sqrt(latest.mousedx * latest.mousedx + latest.mousedy * latest.mousedy)

    -- Return averaged motion parameters
    return {
        velocity_pitch = avg_velocity_pitch,
        velocity_yaw = avg_velocity_yaw,
        direction = avg_direction,
        magnitude = magnitude
    }
end

--- Creates a super simple linear prediction path
function PredictViewPath(current_angle, view_pos)
    -- If mouse is inactive, don't predict
    if not is_mouse_active then
        return { angles = {}, positions = {} }
    end

    -- Calculate motion parameters from history (just need velocity)
    local motion = CalculateMotion()
    local result = {
        angles = {},
        positions = {},
        adjusted = {} -- Track if each prediction point has been adjusted
    }

    -- If no significant movement, don't predict
    if (math.abs(motion.velocity_pitch) < VELOCITY_THRESHOLD and
            math.abs(motion.velocity_yaw) < VELOCITY_THRESHOLD) then
        return result
    end

    local frame_time = globals.TickInterval()

    -- Initial angle as our starting point
    local predicted_angle = EulerAngles(current_angle.pitch, current_angle.yaw, 0)

    -- Use measured angular velocity with scale
    local velocity_pitch = motion.velocity_pitch * PREDICTION_SCALE
    local velocity_yaw = motion.velocity_yaw * PREDICTION_SCALE

    -- Store last predicted aim adjustment (starts with zeroes)
    local last_aim_adjust = {
        pitch = 0,
        yaw = 0
    }

    -- First pass - create basic prediction path without adjustments
    for i = 1, PREDICTION_TICKS do
        -- Linear time scaling
        local time_offset = frame_time * (1 + (i * TIME_FACTOR))

        -- Super simple linear prediction
        local pitch_change = velocity_pitch * time_offset
        local yaw_change = velocity_yaw * time_offset

        -- Apply changes to get new angles
        local new_pitch = ClampPitch(predicted_angle.pitch + pitch_change)
        local new_yaw = NormalizeAngle(predicted_angle.yaw + yaw_change)

        -- Update the prediction for this step
        predicted_angle = EulerAngles(new_pitch, new_yaw, 0)

        -- Store predicted angle
        result.angles[i] = predicted_angle
        result.adjusted[i] = false -- Not adjusted yet

        -- Calculate world position using the predicted angle's forward vector
        local forward = predicted_angle:Forward()

        -- Use increasing distance factor to spread points further for visibility
        local distance_factor = 1 + (i * 0.1)
        local predicted_pos = Vector3(
            view_pos.x + forward.x * DRAW_DISTANCE * distance_factor,
            view_pos.y + forward.y * DRAW_DISTANCE * distance_factor,
            view_pos.z + forward.z * DRAW_DISTANCE * distance_factor
        )

        -- Convert to screen coordinates for drawing
        local screen_pos = WorldToScreen(predicted_pos)
        if screen_pos then
            result.positions[i] = screen_pos
        end
    end

    -- If we have a previous target and adjustment, apply it to future predictions
    if best_target and Last_angle_change then
        -- Get base adjustment values
        local base_pitch_adjust = Last_angle_change.pitch_diff
        local base_yaw_adjust = Last_angle_change.yaw_diff

        -- Cache target tick offset for efficiency
        local target_tick = best_target.tick_offset

        -- Second pass - adjust predictions based on predicted aim adjustments
        for i = 1, PREDICTION_TICKS do
            -- Skip if already on target position
            if i == target_tick then
                goto continue_adjustment
            end

            -- Calculate distance from current prediction to target tick
            local tick_distance = math.abs(i - target_tick)

            -- Apply more adjustment to ticks near the target tick
            -- Further ticks get less adjustment to avoid overcorrection
            local adjustment_strength = STABILIZATION_FACTOR * (ADJUSTMENT_DECAY ^ tick_distance)

            -- Calculate this tick's adjustment
            local tick_pitch_adjust = base_pitch_adjust * adjustment_strength
            local tick_yaw_adjust = base_yaw_adjust * adjustment_strength

            -- Apply the adjustment
            local adjusted_pitch = ClampPitch(result.angles[i].pitch + tick_pitch_adjust)
            local adjusted_yaw = NormalizeAngle(result.angles[i].yaw + tick_yaw_adjust)

            -- Update the prediction angle
            result.angles[i] = EulerAngles(adjusted_pitch, adjusted_yaw, 0)
            result.adjusted[i] = true -- Mark as adjusted

            -- Recalculate world position
            local forward = result.angles[i]:Forward()
            local distance_factor = 1 + (i * 0.1)
            local adjusted_pos = Vector3(
                view_pos.x + forward.x * DRAW_DISTANCE * distance_factor,
                view_pos.y + forward.y * DRAW_DISTANCE * distance_factor,
                view_pos.z + forward.z * DRAW_DISTANCE * distance_factor
            )

            -- Convert to screen coordinates
            local screen_pos = WorldToScreen(adjusted_pos)
            if screen_pos then
                result.positions[i] = screen_pos
            end

            ::continue_adjustment::
        end
    end

    return result
end

--------------------------------------------------
-- TARGET SELECTION
--------------------------------------------------
-- Returns if the player is visible between two points
---@param target Entity
---@param from Vector3
---@param to Vector3
---@return boolean
local function VisPos(target, from, to)
    local trace = engine.TraceLine(from, to, MASK_SHOT | CONTENTS_GRATE)
    return (trace.entity == target) or (trace.fraction > 0.99)
end

--- Find best trajectory adjustment point
function FindBestTrajectoryAdjustment(player, predicted_angles, view_pos)
    -- Reset the global FOV stop tick for visualization
    global_fov_stop_tick = nil

    local players = entities.FindByClass("CTFPlayer")
    if not players or #players == 0 then
        if DEBUG_MODE then
            DebugInfo = DebugInfo or {}
            DebugInfo.noPlayers = "No players found with entities.FindByClass"
        end
        return nil
    end

    -- Current view angle for initial wide FOV scan
    local current_angle = engine.GetViewAngles()

    -- Get view angle velocity for trajectory projection
    local motion = CalculateMotion()
    local is_actively_aiming = (math.abs(motion.velocity_pitch) > VELOCITY_THRESHOLD or
        math.abs(motion.velocity_yaw) > VELOCITY_THRESHOLD)

    -- Debug info for target scanning
    local debug_targets = {}
    local target_count = 0

    -- Stage 1: Find all potential targets within wide FOV scan
    local potential_targets = {}

    -- For debugging, let's count how many players we see total
    local total_players = #players
    local teammates = 0
    local enemies = 0
    local invalid = 0
    local not_alive = 0

    for i = 1, #players do
        local target = players[i]

        -- Skip invalid targets
        if not target then
            invalid = invalid + 1
            goto continue_initial_scan
        end

        -- Skip teammates - use direct team number comparison
        if target == player then
            teammates = teammates + 1
            goto continue_initial_scan
        end

        if not target:IsValid() then
            invalid = invalid + 1
            goto continue_initial_scan
        end

        if not target:IsAlive() then
            not_alive = not_alive + 1
            goto continue_initial_scan
        end

        if target:GetTeamNumber() == player:GetTeamNumber() then
            teammates = teammates + 1
            goto continue_initial_scan
        else
            enemies = enemies + 1
        end

        -- Calculate target position (head)
        local target_pos = nil

        -- Safe way to get target position using hitbox
        pcall(function()
            -- Use proper hitbox targeting for head position
            local player = LNX.TF2.WPlayer.FromEntity(target)
            if player then
                target_pos = player:GetHitboxPos(Hitbox.Head)
            else
                -- Fallback method if WPlayer wrapping fails
                target_pos = target:GetAbsOrigin() + target:GetPropVector("localdata", "m_vecViewOffset[0]")
            end
        end)

        if not target_pos then
            goto continue_initial_scan
        end

        local target_angle = CalcAngle(view_pos, target_pos)

        -- Check if within wide initial FOV scan
        local fov = Math.AngleFov(current_angle, target_angle)

        -- This if statement is primarily to collect debug info
        if fov <= INITIAL_FOV_SCAN then
            -- Use direct visibility check
            local is_visible = VisPos(target, view_pos, target_pos)

            -- Add to debug info regardless of visibility
            target_count = target_count + 1
            debug_targets[target_count] = {
                fov = fov,
                visible = is_visible,
                team = target:GetTeamNumber(),
                name = target:GetName() or "Unknown"
            }

            -- Only add visible targets
            if is_visible then
                -- MODIFIED DEADZONE CHECK: Skip if in deadzone AND not actively aiming
                -- This allows corrections in the deadzone when actively moving mouse
                if fov <= FOV_THRESHOLD and not is_actively_aiming then
                    debug_targets[target_count].in_deadzone = true
                    debug_targets[target_count].msg = "Target in deadzone (not moving mouse)"
                    goto continue_initial_scan
                end

                table.insert(potential_targets, {
                    entity = target,
                    position = target_pos,
                    angle = target_angle,
                    fov = fov,
                    name = target:GetName() or "Unknown"
                })
            end
        end

        ::continue_initial_scan::
    end

    -- Store all debug counts
    DebugCounts = {
        total = total_players,
        teammates = teammates,
        enemies = enemies,
        invalid = invalid,
        not_alive = not_alive,
        potential = #potential_targets
    }

    -- If no potential targets found in wide scan, exit early
    if #potential_targets == 0 then
        DebugTargets = debug_targets
        DebugTargetCount = target_count
        DebugInfo = {
            target_count = target_count,
            potential_count = #potential_targets,
            message = "No potential targets in FOV scan or all in deadzone"
        }
        return nil
    end

    -- Project aim trajectory based on current motion to predict intersection with targets
    local best_match = {
        fov = FOV_THRESHOLD, -- Starting threshold
        target = nil,
        target_angle = nil,
        target_pos = nil,
        pred_tick = 0,
        pred_angle = nil,
        angle_offset = nil,
        trajectory_time = 999, -- Time to intersection (lower is better)
        min_distance = 999     -- Distance from trajectory to target
    }

    -- Stage 2: Project current aim trajectory and check for intersections with targets
    local future_view_pos = view_pos -- Assume static view position for simplicity

    if is_actively_aiming and predicted_angles and #predicted_angles > 0 then
        -- Get current aiming direction (ray)
        local current_view_dir = current_angle:Forward()

        -- For each potential target, check if our projected aim path will cross their hitbox
        for _, target_data in ipairs(potential_targets) do
            -- Estimate time to intersection by projecting current aim path
            local time_to_intersection = nil
            local intersection_point = nil
            local intersection_angle = nil
            local min_distance = 999
            local best_tick = 0

            -- Variables to track if FOV is increasing (moving away from target)
            local last_fov = Math.AngleFov(predicted_angles[1], target_data.angle)
            local increasing_fov_count = 0

            -- Check each prediction tick for closest approach to target
            for tick = 1, math.min(MAX_PREDICTION_DISTANCE, #predicted_angles) do
                local pred_angle = predicted_angles[tick]

                -- Calculate FOV to target from this prediction angle
                local pred_fov = Math.AngleFov(pred_angle, target_data.angle)

                -- Check if FOV is increasing (we're moving away from target)
                if pred_fov > last_fov then
                    increasing_fov_count = increasing_fov_count + 1

                    -- If FOV has been increasing for 2 consecutive ticks, we're definitely moving away
                    -- No need to check further predictions
                    if increasing_fov_count >= 2 and tick > 2 then
                        -- Only log a message if we previously found a potential match
                        if best_tick > 0 then
                            debug_targets[target_count + 1] = {
                                msg = string.format("Stopped at tick %d - FOV increasing (%.1f > %.1f)",
                                    tick, pred_fov, last_fov),
                                entity = target_data.name
                            }
                            target_count = target_count + 1

                            -- Also visualize where prediction stops
                            if i == #potential_targets then
                                global_fov_stop_tick = tick
                            end
                        end

                        -- Important: Exit the prediction loop for this target immediately
                        break
                    end
                else
                    -- Reset counter if FOV decreases again
                    increasing_fov_count = 0
                end

                -- Update last FOV for next comparison
                last_fov = pred_fov

                local pred_dir = pred_angle:Forward()

                -- Calculate closest point of approach from this prediction angle to target
                local target_to_eye = Vector3(
                    target_data.position.x - future_view_pos.x,
                    target_data.position.y - future_view_pos.y,
                    target_data.position.z - future_view_pos.z
                )

                -- Project target vector onto prediction direction to get closest approach
                local pred_dir_length = pred_dir:Length()
                if pred_dir_length < 0.001 then goto continue_intersection end

                -- Calculate dot product to find projection length
                local dot_product = target_to_eye.x * pred_dir.x +
                    target_to_eye.y * pred_dir.y +
                    target_to_eye.z * pred_dir.z

                -- Distance along prediction ray
                local proj_length = dot_product / pred_dir_length

                -- Ignore negative projections (behind us)
                if proj_length < 0 then goto continue_intersection end

                -- Calculate closest point on prediction ray to target
                local closest_point = Vector3(
                    future_view_pos.x + pred_dir.x * proj_length / pred_dir_length,
                    future_view_pos.y + pred_dir.y * proj_length / pred_dir_length,
                    future_view_pos.z + pred_dir.z * proj_length / pred_dir_length
                )

                -- Calculate distance from closest point to target
                local distance = Vector3(
                    closest_point.x - target_data.position.x,
                    closest_point.y - target_data.position.y,
                    closest_point.z - target_data.position.z
                ):Length()

                -- Check if this is our best approach so far (would we hit the head?)
                -- Use a reasonable head hitbox size (8 units)
                local head_radius = 8
                if distance < head_radius and distance < min_distance then
                    min_distance = distance
                    best_tick = tick
                    intersection_point = closest_point
                    intersection_angle = pred_angle
                    time_to_intersection = tick * globals.TickInterval() * (1 + (tick * TIME_FACTOR))
                end

                ::continue_intersection::
            end

            -- If we found an intersection, consider it as a potential target
            if intersection_point and time_to_intersection and time_to_intersection < best_match.trajectory_time then
                -- Calculate angle offset between current and intersection angle
                local pitch_offset = AngleDifference(target_data.angle.pitch, current_angle.pitch)
                local yaw_offset = AngleDifference(target_data.angle.yaw, current_angle.yaw)

                best_match.fov = target_data.fov
                best_match.target = target_data.entity
                best_match.target_angle = target_data.angle
                best_match.target_pos = target_data.position
                best_match.pred_tick = best_tick
                best_match.pred_angle = intersection_angle
                best_match.angle_offset = {
                    pitch = pitch_offset,
                    yaw = yaw_offset
                }
                best_match.trajectory_time = time_to_intersection
                best_match.min_distance = min_distance

                -- Add to debug info
                if DEBUG_TARGETS then
                    debug_targets[target_count + 1] = {
                        msg = string.format("TRAJECTORY HIT: Tick %d, Time %.2fs, Distance %.1f, FOV %.1f",
                            best_tick, time_to_intersection, min_distance, target_data.fov),
                        entity = target_data.name
                    }
                    target_count = target_count + 1
                end
            end
        end

        -- If no trajectory intersection found, fall back to standard FOV checking
        if not best_match.target and predicted_angles and #predicted_angles > 0 then
            -- Fall back to standard method - checking FOV from prediction points
            for tick = 1, math.min(MAX_PREDICTION_DISTANCE, #predicted_angles) do
                local pred_angle = predicted_angles[tick]

                -- For each potential target, check FOV from this prediction angle
                for _, target_data in ipairs(potential_targets) do
                    local pred_fov = Math.AngleFov(pred_angle, target_data.angle)

                    -- If within tight FOV threshold and better than current best
                    if pred_fov <= FOV_THRESHOLD and pred_fov < best_match.fov then
                        -- Calculate angle offset between prediction and target
                        local pitch_offset = AngleDifference(target_data.angle.pitch, pred_angle.pitch)
                        local yaw_offset = AngleDifference(target_data.angle.yaw, pred_angle.yaw)

                        best_match.fov = pred_fov
                        best_match.target = target_data.entity
                        best_match.target_angle = target_data.angle
                        best_match.target_pos = target_data.position
                        best_match.pred_tick = tick
                        best_match.pred_angle = pred_angle
                        best_match.angle_offset = {
                            pitch = pitch_offset,
                            yaw = yaw_offset
                        }

                        -- Add to debug
                        if DEBUG_TARGETS then
                            debug_targets[target_count + 1] = {
                                msg = string.format("MATCH: Tick %d, FOV %.1f, Offset [P:%.1f, Y:%.1f]",
                                    tick, pred_fov, pitch_offset, yaw_offset),
                                entity = target_data.name
                            }
                            target_count = target_count + 1
                        end
                    end
                end
            end
        end
    else
        -- Standard FOV checking if not actively aiming
        if predicted_angles and #predicted_angles > 0 then
            for tick = 1, math.min(MAX_PREDICTION_DISTANCE, #predicted_angles) do
                local pred_angle = predicted_angles[tick]

                -- For each potential target, check FOV from this prediction angle
                for _, target_data in ipairs(potential_targets) do
                    local pred_fov = Math.AngleFov(pred_angle, target_data.angle)

                    -- If within tight FOV threshold and better than current best
                    if pred_fov <= FOV_THRESHOLD and pred_fov < best_match.fov then
                        -- Calculate angle offset between prediction and target
                        local pitch_offset = AngleDifference(target_data.angle.pitch, pred_angle.pitch)
                        local yaw_offset = AngleDifference(target_data.angle.yaw, pred_angle.yaw)

                        best_match.fov = pred_fov
                        best_match.target = target_data.entity
                        best_match.target_angle = target_data.angle
                        best_match.target_pos = target_data.position
                        best_match.pred_tick = tick
                        best_match.pred_angle = pred_angle
                        best_match.angle_offset = {
                            pitch = pitch_offset,
                            yaw = yaw_offset
                        }

                        -- Add to debug
                        if DEBUG_TARGETS then
                            debug_targets[target_count + 1] = {
                                msg = string.format("MATCH: Tick %d, FOV %.1f, Offset [P:%.1f, Y:%.1f]",
                                    tick, pred_fov, pitch_offset, yaw_offset),
                                entity = target_data.name
                            }
                            target_count = target_count + 1
                        end
                    end
                end
            end
        end
    end

    -- Store debug info in global for rendering
    DebugTargets = debug_targets
    DebugTargetCount = target_count

    if best_match.target and best_match.angle_offset then
        -- Store trajectory information in the return value if it was calculated
        -- This will be used for visualization and further logic
        if best_match.trajectory_time then
            return best_match.target_angle, best_match.target, best_match.pred_tick,
                best_match.target_pos, best_match.angle_offset, best_match.pred_angle,
                best_match.trajectory_time, best_match.min_distance
        else
            return best_match.target_angle, best_match.target, best_match.pred_tick,
                best_match.target_pos, best_match.angle_offset, best_match.pred_angle
        end
    end

    DebugInfo = {
        target_count = target_count,
        potential_count = #potential_targets,
        message = "No target within FOV threshold or trajectory projection"
    }
    return nil
end

--------------------------------------------------
-- CALLBACKS
--------------------------------------------------
function CreateMove(cmd)
    local player = entities.GetLocalPlayer()
    if not player or not player:IsAlive() then
        angle_history = {}
        prediction_path = {}
        best_target = nil
        is_mouse_active = false
        return
    end

    -- Get current view data
    local current_angle = engine.GetViewAngles()
    local current_time = globals.RealTime()
    local view_pos = player:GetAbsOrigin() + player:GetPropVector("localdata", "m_vecViewOffset[0]")

    -- Apply pitch clamping to current angle
    local clamped_pitch = ClampPitch(current_angle.pitch)
    if clamped_pitch ~= current_angle.pitch then
        current_angle = EulerAngles(clamped_pitch, current_angle.yaw, current_angle.roll)
        engine.SetViewAngles(current_angle)
    end

    -- Record current angle and mouse state for prediction
    RecordViewAngle(current_angle, current_time, cmd.mousedx, cmd.mousedy)

    -- Generate prediction path only if mouse is active
    if is_mouse_active then
        local prediction = PredictViewPath(current_angle, view_pos)
        prediction_path = prediction.positions

        -- Find best target for trajectory adjustment
        local target_angle, closest_target, pred_tick, target_pos, angle_offset, pred_angle, trajectory_time, min_distance =
            FindBestTrajectoryAdjustment(player, prediction.angles, view_pos)

        if not target_angle or not closest_target or not angle_offset then
            best_target = nil
            return
        end

        -- Save target for visualization
        best_target = {
            angle = target_angle,
            entity = closest_target,
            tick_offset = pred_tick,
            position = target_pos,
            pred_angle = pred_angle,
            angle_offset = angle_offset,
            trajectory_time = trajectory_time,
            min_distance = min_distance
        }

        -- Only proceed if trajectory adjustment is enabled
        if not ENABLE_TRAJECTORY_ADJUST then return end

        -- Check if we can shoot
        local weapon = player:GetPropEntity("m_hActiveWeapon")
        if weapon then
            local flCurTime = globals.CurTime()
            -- Fix: Use GetPropFloat to access the next attack time properties
            local nextPrimaryAttack = weapon:GetPropFloat("LocalActiveWeaponData", "m_flNextPrimaryAttack")
            local playerNextAttack = player:GetPropFloat("m_flNextAttack")
            local canShoot = nextPrimaryAttack <= flCurTime and playerNextAttack <= flCurTime
            if not canShoot then
                -- Still store best target for visualization, but don't adjust aim
                return
            end
        end

        -- Calculate t-value based on prediction tick
        local t = math.max(0.1, pred_tick / MAX_PREDICTION_DISTANCE)

        -- Initialize adjustment variables
        local adjusted_pitch, adjusted_yaw, direction_angle, allow_adjustment
        local interp_factor = TRAJECTORY_ADJUST_FACTOR / (1 + (t * 3))

        -- Get mouse movement info
        local is_active_movement = (cmd.mousedx ~= 0 or cmd.mousedy ~= 0)
        local motion = CalculateMotion()

        if TRAJECTORY_MODE and is_active_movement then
            -- TRAJECTORY MODE: Modify trajectory to cross target instead of aiming directly at it

            -- Get normalized motion direction
            local mouse_dx = cmd.mousedx
            local mouse_dy = cmd.mousedy
            local mouse_len = math.sqrt(mouse_dx * mouse_dx + mouse_dy * mouse_dy)

            if mouse_len > 0.001 then
                -- Normalize mouse vector
                mouse_dx = mouse_dx / mouse_len
                mouse_dy = mouse_dy / mouse_len

                -- Current forward vector
                local forward = current_angle:Forward()
                local right = current_angle:Right()
                local up = current_angle:Up()

                -- Calculate target direction vector
                local target_dir = Vector3(
                    target_pos.x - view_pos.x,
                    target_pos.y - view_pos.y,
                    target_pos.z - view_pos.z
                )

                -- Instead of aiming directly at target, we want to create a trajectory that passes through
                -- the target by creating a slight offset to our direction vector

                -- Calculate 3D direction of mouse movement
                local move_dir = Vector3(
                    right.x * mouse_dx + up.x * mouse_dy,
                    right.y * mouse_dx + up.y * mouse_dy,
                    right.z * mouse_dx + up.z * mouse_dy
                )

                -- Normalize this direction
                local move_dir_length = move_dir:Length()
                if move_dir_length > 0.001 then
                    move_dir = Vector3(
                        move_dir.x / move_dir_length,
                        move_dir.y / move_dir_length,
                        move_dir.z / move_dir_length
                    )

                    -- Create a trajectory plane perpendicular to move_dir
                    -- This will be used to project the target onto
                    local plane_normal = Vector3(
                        move_dir.x,
                        move_dir.y,
                        move_dir.z
                    )

                    -- Project target onto this plane to create an intercept point
                    -- We want to aim at this point to create a natural crossing trajectory
                    local dot_product = target_dir.x * plane_normal.x +
                        target_dir.y * plane_normal.y +
                        target_dir.z * plane_normal.z

                    -- Calculate a point ahead of the target in the direction of our movement
                    -- This creates a natural lead point for our aim
                    local lead_offset = 20 -- Distance ahead of target to aim
                    local intercept_point = Vector3(
                        target_pos.x + move_dir.x * lead_offset,
                        target_pos.y + move_dir.y * lead_offset,
                        target_pos.z + move_dir.z * lead_offset
                    )

                    -- Calculate angle to the intercept point
                    local intercept_angle = CalcAngle(view_pos, intercept_point)

                    -- Get difference from current angle
                    local pitch_diff = AngleDifference(intercept_angle.pitch, current_angle.pitch)
                    local yaw_diff = AngleDifference(intercept_angle.yaw, current_angle.yaw)

                    -- Scale adjustment based on distance to target
                    local distance_to_target = target_dir:Length()
                    local distance_scale = math.min(1.0, 300 / math.max(distance_to_target, 1))

                    -- Reduce the adjustment magnitude for subtlety
                    local adjustment_mag = math.sqrt(pitch_diff * pitch_diff + yaw_diff * yaw_diff)

                    if adjustment_mag > 0.001 then
                        -- Apply more subtle adjustment
                        local subtlety_factor = 0.4 -- More subtle
                        pitch_diff = pitch_diff * interp_factor * subtlety_factor * distance_scale
                        yaw_diff = yaw_diff * interp_factor * subtlety_factor * distance_scale
                    end

                    -- Calculate final angle
                    adjusted_pitch = NormalizeAngle(current_angle.pitch + pitch_diff)
                    adjusted_yaw = NormalizeAngle(current_angle.yaw + yaw_diff)

                    -- Check direction angle for allowable adjustment
                    local adjust_dx = yaw_diff    -- Yaw right = positive
                    local adjust_dy = -pitch_diff -- Pitch down = positive

                    -- Normalize adjustment vector
                    local adjust_len = math.sqrt(adjust_dx * adjust_dx + adjust_dy * adjust_dy)
                    if adjust_len > 0.001 then
                        adjust_dx = adjust_dx / adjust_len
                        adjust_dy = adjust_dy / adjust_len

                        -- Calculate dot product (cosine of angle between vectors)
                        local motion_dot = (mouse_dx * adjust_dx) + (mouse_dy * adjust_dy)

                        -- Clamp to valid range
                        motion_dot = math.max(-1, math.min(1, motion_dot))

                        -- Get angle in degrees
                        direction_angle = math.deg(math.acos(motion_dot))

                        -- Check if adjustment is roughly aligned with mouse movement
                        allow_adjustment = direction_angle <= MAX_DIRECTION_CHANGE

                        -- Store debug info if not allowed
                        if not allow_adjustment then
                            DebugDirectional = {
                                message = "Trajectory adjust skipped - against movement intent",
                                mouse_x = mouse_dx,
                                mouse_y = mouse_dy,
                                adjust_x = adjust_dx,
                                adjust_y = adjust_dy,
                                angle = direction_angle,
                                limit = MAX_DIRECTION_CHANGE
                            }
                            return
                        end
                    else
                        direction_angle = 0
                        allow_adjustment = true
                    end
                else
                    -- Fallback to more subtle direct adjustment if can't calculate movement direction
                    local pitch_diff = angle_offset.pitch * interp_factor * 0.3 -- Much more subtle
                    local yaw_diff = angle_offset.yaw * interp_factor * 0.3

                    adjusted_pitch = NormalizeAngle(current_angle.pitch + pitch_diff)
                    adjusted_yaw = NormalizeAngle(current_angle.yaw + yaw_diff)
                    direction_angle = 0
                    allow_adjustment = true
                end
            else
                -- Default to more subtle direct adjustment when no movement detected
                local pitch_diff = angle_offset.pitch * interp_factor * 0.3 -- Much more subtle
                local yaw_diff = angle_offset.yaw * interp_factor * 0.3

                adjusted_pitch = NormalizeAngle(current_angle.pitch + pitch_diff)
                adjusted_yaw = NormalizeAngle(current_angle.yaw + yaw_diff)
                direction_angle = 0
                allow_adjustment = true
            end
        end

        -- Add smoothing based on how many consecutive frames we've been adjusting
        local consecutive_frames = 0
        if best_target and Last_best_target and
            best_target.entity == Last_best_target.entity then
            -- We're tracking the same target as last frame
            consecutive_frames = (Last_consecutive_frames or 0) + 1
        else
            consecutive_frames = 1
        end

        -- Store for next frame
        Last_best_target = best_target
        Last_consecutive_frames = consecutive_frames

        -- Apply additional smoothing for consecutive tracking
        -- Cap at 10 frames to avoid becoming too sluggish
        local stability_factor = math.min(consecutive_frames, 10) / 10

        -- Calculate difference between current and adjusted angles
        local pitch_diff = AngleDifference(adjusted_pitch, current_angle.pitch)
        local yaw_diff = AngleDifference(adjusted_yaw, current_angle.yaw)

        -- Apply additional stability smoothing
        if TRAJECTORY_MODE then
            -- Extra smoothing in trajectory mode
            pitch_diff = pitch_diff * (1 - (stability_factor * 0.4))
            yaw_diff = yaw_diff * (1 - (stability_factor * 0.4))
        else
            pitch_diff = pitch_diff * (1 - (stability_factor * 0.3))
            yaw_diff = yaw_diff * (1 - (stability_factor * 0.3))
        end

        -- Calculate angle magnitude for limits
        local angle_magnitude = math.sqrt(pitch_diff ^ 2 + yaw_diff ^ 2)

        -- Skip tiny adjustments
        if angle_magnitude < 0.1 then return end

        -- Apply maximum angle change limit for subtle movements
        if angle_magnitude > MAX_ANGLE_CHANGE then
            local scale = MAX_ANGLE_CHANGE / angle_magnitude
            pitch_diff = pitch_diff * scale
            yaw_diff = yaw_diff * scale
        end

        -- Calculate new view angle with adjustment
        local new_pitch = ClampPitch(NormalizeAngle(current_angle.pitch + pitch_diff))
        local new_yaw = NormalizeAngle(current_angle.yaw + yaw_diff)
        local new_angle = EulerAngles(new_pitch, new_yaw, 0)

        -- Check if user is manually aiming
        local has_recent_motion = (math.abs(motion.velocity_pitch) > VELOCITY_THRESHOLD / 2 or
            math.abs(motion.velocity_yaw) > VELOCITY_THRESHOLD / 2)
        local is_manual_aiming = is_active_movement or has_recent_motion

        -- Apply angle adjustments based on the aimbot mode
        if CURRENT_AIMBOT_MODE == aimbot_mode.plain then
            -- Plain mode - direct angle setting
            engine.SetViewAngles(new_angle)
        elseif CURRENT_AIMBOT_MODE == aimbot_mode.smooth then
            -- Smooth mode - always apply adjustment with smoothing
            engine.SetViewAngles(new_angle)
        elseif CURRENT_AIMBOT_MODE == aimbot_mode.silent then
            -- Silent mode - only adjust command angles, not view
            cmd.viewangles = EulerAngles(new_pitch, new_yaw, 0)
        elseif CURRENT_AIMBOT_MODE == aimbot_mode.assistance then
            -- Assistance mode - apply when user is moving mouse or has moved recently
            if is_manual_aiming then
                engine.SetViewAngles(new_angle)
            end
        end

        -- Store debug info in global for next frame
        if DEBUG_MODE then
            Last_angle_change = {
                pitch_diff = pitch_diff,
                yaw_diff = yaw_diff,
                magnitude = angle_magnitude,
                tick_offset = pred_tick,
                t_value = t,
                interp_factor = interp_factor,
                offset_pitch = angle_offset.pitch,
                offset_yaw = angle_offset.yaw,
                mode = CURRENT_AIMBOT_MODE,
                manual_aiming = is_manual_aiming,
                consecutive_frames = consecutive_frames,
                direction_angle = direction_angle,
                allow_adjustment = allow_adjustment,
                trajectory_mode = TRAJECTORY_MODE,
                adjustment_applied = (CURRENT_AIMBOT_MODE == aimbot_mode.plain) or
                    (CURRENT_AIMBOT_MODE == aimbot_mode.smooth) or
                    (CURRENT_AIMBOT_MODE == aimbot_mode.assistance and is_manual_aiming)
            }
        end
    else
        -- Clear prediction path when mouse is inactive
        prediction_path = {}
        best_target = nil
    end
end

function OnDraw()
    -- Get screen dimensions
    local screen_w, screen_h = draw.GetScreenSize()
    local center_x, center_y = math.floor(screen_w / 2), math.floor(screen_h / 2)

    -- Draw center reference (subtle crosshair highlight)
    draw.Color(255, 0, 255, 100) -- Semi-transparent magenta
    draw.FilledRect(center_x - 1, center_y - 1, center_x + 1, center_y + 1)

    -- Draw debug information if enabled
    if DEBUG_MODE then
        draw.SetFont(Verdana)
        draw.Color(255, 255, 0, 255)

        -- Show history information
        draw.Text(5, 5, string.format("History: %d/%d samples",
            #angle_history,
            HISTORY_SIZE))

        if best_target then
            draw.Text(5, 25, string.format("Target Found: Tick %d, FOV: %.1f°",
                best_target.tick_offset or 0,
                Math.AngleFov(engine.GetViewAngles(), best_target.angle) or 0))

            draw.Text(5, 45, string.format("Trajectory Adjust: %s, Factor: %.2f",
                ENABLE_TRAJECTORY_ADJUST and "ON" or "OFF",
                TRAJECTORY_ADJUST_FACTOR))

            -- Show deadzone status
            draw.Text(5, 65, string.format("Deadzone: %.1f° (Active Aiming Override: %s)",
                FOV_THRESHOLD,
                CalculateMotion().magnitude > MOVEMENT_THRESHOLD and "YES" or "NO"))

            -- Show the last angle adjustment if available
            if Last_angle_change then
                draw.Text(5, 85, string.format("Adjustment: P:%.2f Y:%.2f (%.2f°)",
                    Last_angle_change.pitch_diff or 0,
                    Last_angle_change.yaw_diff or 0,
                    Last_angle_change.magnitude or 0))

                draw.Text(5, 105, string.format("Ticks: %d, T-value: %.2f, Factor: %.3f",
                    Last_angle_change.tick_offset or 0,
                    Last_angle_change.t_value or 0,
                    Last_angle_change.interp_factor or 0))

                draw.Text(5, 125, string.format("Mode: %s, Frames: %d, Applied: %s",
                    Last_angle_change.mode or "unknown",
                    Last_angle_change.consecutive_frames or 1,
                    Last_angle_change.adjustment_applied and "YES" or "NO"))

                -- Add directional constraint information
                draw.Text(5, 165, string.format("Direction Change: %.1f° (Limit: %d°)",
                    Last_angle_change.direction_angle or 0,
                    MAX_DIRECTION_CHANGE))

                -- Add trajectory intersection information
                if best_target.trajectory_time then
                    draw.Text(5, 185, string.format("Trajectory Hit: %.2fs, Distance: %.1f units",
                        best_target.trajectory_time or 0,
                        best_target.min_distance or 0))
                end

                -- Add trajectory mode information
                draw.Text(5, 145, string.format("Entity: %s%s",
                    best_target.entity:GetName() or "Unknown",
                    Last_angle_change.trajectory_mode and " - Trajectory Mode" or ""))
            else
                draw.Text(5, 25, "No Target Found")
                draw.Text(5, 45, string.format("Trajectory Adjust: %s",
                    ENABLE_TRAJECTORY_ADJUST and "ON" or "OFF"))

                -- Show deadzone status
                draw.Text(5, 65, string.format("Deadzone: %.1f° (Active Aiming Override: %s)",
                    FOV_THRESHOLD,
                    CalculateMotion().magnitude > MOVEMENT_THRESHOLD and "YES" or "NO"))

                -- Display player counts and potential targets
                if DebugCounts then
                    draw.Text(5, 85, string.format("Players: %d (Enemy: %d, Team: %d, Invalid: %d, Dead: %d)",
                        DebugCounts.total or 0,
                        DebugCounts.enemies or 0,
                        DebugCounts.teammates or 0,
                        DebugCounts.invalid or 0,
                        DebugCounts.not_alive or 0))
                    draw.Text(5, 105, string.format("Potential Targets: %d", DebugCounts.potential or 0))
                end

                -- Display additional error info
                if DebugInfo then
                    if DebugInfo.noPlayers then
                        draw.Text(5, 125, DebugInfo.noPlayers)
                    else
                        draw.Text(5, 125, DebugInfo.message or "Unknown error")
                    end
                end

                -- Display potential target debugging
                if DebugTargets and DebugTargetCount and DebugTargetCount > 0 then
                    draw.Text(5, 145, string.format("Scanned %d potential targets", DebugTargetCount))

                    -- Show individual target info if enabled
                    if DEBUG_TARGETS and DebugTargets then
                        for i, info in pairs(DebugTargets) do
                            if i <= 5 then -- Limit to 5 targets to avoid cluttering
                                if info.msg then
                                    draw.Text(5, 165 + (i - 1) * 20, info.msg)
                                elseif info.in_deadzone then
                                    draw.Text(5, 165 + (i - 1) * 20, string.format("Target %d: FOV %.1f - In Deadzone",
                                        i, info.fov or 0))
                                else
                                    draw.Text(5, 165 + (i - 1) * 20,
                                        string.format("Target %d: FOV %.1f, Team %d, Visible: %s",
                                            i, info.fov or 0, info.team or -1, info.visible and "Yes" or "No"))
                                end
                            end
                        end
                    end
                end

                -- Draw directional debug info if available
                if DebugDirectional then
                    draw.Text(5, 185, DebugDirectional.message)
                    draw.Text(5, 205, string.format("Current: P:%.1f Y:%.1f | Adjusted: P:%.1f Y:%.1f",
                        DebugDirectional.mouse_x or 0,
                        DebugDirectional.mouse_y or 0,
                        DebugDirectional.adjust_x or 0,
                        DebugDirectional.adjust_y or 0))
                    draw.Text(5, 225, string.format("Angle: %.1f° (Limit: %d°)",
                        DebugDirectional.angle or 0,
                        DebugDirectional.limit or MAX_DIRECTION_CHANGE))
                end
            end
        else
            draw.Text(5, 25, "No Target Found")
            draw.Text(5, 45, string.format("Trajectory Adjust: %s",
                ENABLE_TRAJECTORY_ADJUST and "ON" or "OFF"))

            -- Show deadzone status
            draw.Text(5, 65, string.format("Deadzone: %.1f° (Active Aiming Override: %s)",
                FOV_THRESHOLD,
                CalculateMotion().magnitude > MOVEMENT_THRESHOLD and "YES" or "NO"))

            -- Display player counts and potential targets
            if DebugCounts then
                draw.Text(5, 85, string.format("Players: %d (Enemy: %d, Team: %d, Invalid: %d, Dead: %d)",
                    DebugCounts.total or 0,
                    DebugCounts.enemies or 0,
                    DebugCounts.teammates or 0,
                    DebugCounts.invalid or 0,
                    DebugCounts.not_alive or 0))
                draw.Text(5, 105, string.format("Potential Targets: %d", DebugCounts.potential or 0))
            end

            -- Display additional error info
            if DebugInfo then
                if DebugInfo.noPlayers then
                    draw.Text(5, 125, DebugInfo.noPlayers)
                else
                    draw.Text(5, 125, DebugInfo.message or "Unknown error")
                end
            end

            -- Display potential target debugging
            if DebugTargets and DebugTargetCount and DebugTargetCount > 0 then
                draw.Text(5, 145, string.format("Scanned %d potential targets", DebugTargetCount))

                -- Show individual target info if enabled
                if DEBUG_TARGETS and DebugTargets then
                    for i, info in pairs(DebugTargets) do
                        if i <= 5 then -- Limit to 5 targets to avoid cluttering
                            if info.msg then
                                draw.Text(5, 165 + (i - 1) * 20, info.msg)
                            elseif info.in_deadzone then
                                draw.Text(5, 165 + (i - 1) * 20, string.format("Target %d: FOV %.1f - In Deadzone",
                                    i, info.fov or 0))
                            else
                                draw.Text(5, 165 + (i - 1) * 20,
                                    string.format("Target %d: FOV %.1f, Team %d, Visible: %s",
                                        i, info.fov or 0, info.team or -1, info.visible and "Yes" or "No"))
                            end
                        end
                    end
                end
            end

            -- Draw directional debug info if available
            if DebugDirectional then
                draw.Text(5, 185, DebugDirectional.message)
                draw.Text(5, 205, string.format("Current: P:%.1f Y:%.1f | Adjusted: P:%.1f Y:%.1f",
                    DebugDirectional.mouse_x or 0,
                    DebugDirectional.mouse_y or 0,
                    DebugDirectional.adjust_x or 0,
                    DebugDirectional.adjust_y or 0))
                draw.Text(5, 225, string.format("Angle: %.1f° (Limit: %d°)",
                    DebugDirectional.angle or 0,
                    DebugDirectional.limit or MAX_DIRECTION_CHANGE))
            end
        end

        -- Display motion information if available
        local motion = CalculateMotion()
        if motion then
            local y_pos = 285
            draw.Text(5, y_pos, string.format("Motion: Vel P:%.1f Y:%.1f, Mag: %.1f",
                motion.velocity_pitch,
                motion.velocity_yaw,
                motion.magnitude))

            draw.Text(5, y_pos + 20, string.format("Direction: X:%.2f Y:%.2f",
                motion.direction.x,
                motion.direction.y))
        end

        -- Display at the top that this is a trajectory adjuster, not an aimbot
        draw.Text(5, screen_h - 30, "VIEW TRAJECTORY ADUSTER (Not an Aimbot)")
    end

    -- Only draw if we have a valid prediction path
    if #prediction_path >= 1 then
        -- Draw connecting line from crosshair to first prediction point
        local first_point = prediction_path[1]
        if first_point then
            local x1 = math.floor(first_point.x + 0.5)
            local y1 = math.floor(first_point.y + 0.5)

            -- Check valid coordinates
            if x1 and y1 and x1 >= 0 and y1 >= 0 and
                x1 < screen_w and y1 < screen_h then
                -- Draw line from crosshair to first prediction point
                draw.Color(0, 255, 255, LINE_ALPHA) -- Semi-transparent cyan
                draw.Line(center_x, center_y, x1, y1)
            end
        end

        -- Draw connecting lines between prediction points
        for i = 1, #prediction_path - 1 do
            local p1 = prediction_path[i]
            local p2 = prediction_path[i + 1]
            if p1 and p2 then
                -- Ensure coordinates are integers and clamped to screen
                local x1 = math.floor(p1.x + 0.5) -- +0.5 for proper rounding
                local y1 = math.floor(p1.y + 0.5)
                local x2 = math.floor(p2.x + 0.5)
                local y2 = math.floor(p2.y + 0.5)

                -- Check for valid coordinates
                if x1 and y1 and x2 and y2 and
                    x1 >= 0 and y1 >= 0 and x2 >= 0 and y2 >= 0 and
                    x1 < screen_w and y1 < screen_h and x2 < screen_w and y2 < screen_h then
                    -- Use different colors for adjusted and non-adjusted prediction segments
                    local prediction = nil
                    local player = entities.GetLocalPlayer()

                    -- Safely get the player eye position
                    if player and player:IsAlive() then
                        local view_pos = player:GetAbsOrigin() + player:GetPropVector("localdata", "m_vecViewOffset[0]")
                        prediction = PredictViewPath(engine.GetViewAngles(), view_pos)
                    else
                        prediction = { adjusted = {} }
                    end

                    if prediction.adjusted and (prediction.adjusted[i] or prediction.adjusted[i + 1]) then
                        -- Magenta for adjusted predictions
                        draw.Color(255, 0, 255, LINE_ALPHA)
                    else
                        -- Cyan for raw predictions
                        draw.Color(0, 255, 255, LINE_ALPHA)
                    end

                    -- Draw lines with reduced thickness for subtle appearance
                    for thickness = 0, LINE_THICKNESS - 1 do
                        draw.Line(x1, y1 + thickness, x2, y2 + thickness)
                    end
                end
            end
        end

        -- Draw prediction points as small circles
        for i = 1, #prediction_path do
            local pos = prediction_path[i]
            if pos then
                -- Ensure coordinates are integers and properly rounded
                local x = math.floor(pos.x + 0.5)
                local y = math.floor(pos.y + 0.5)

                -- Skip invalid coordinates
                if not x or not y or
                    x < 0 or y < 0 or
                    x >= screen_w or y >= screen_h or
                    tostring(x) == "nan" or tostring(y) == "nan" or
                    tostring(x) == "inf" or tostring(y) == "inf" then
                    goto continue
                end

                -- Constant small size for points
                local size = POINT_SIZE

                -- Highlight where FOV check stopped prediction with a different color
                if global_fov_stop_tick and i == global_fov_stop_tick then
                    -- Draw yellow stop marker with X shape
                    draw.Color(255, 255, 0, 200) -- Bright yellow
                    draw.Line(x - size - 2, y - size - 2, x + size + 2, y + size + 2)
                    draw.Line(x - size - 2, y + size + 2, x + size + 2, y - size - 2)
                    draw.FilledRect(x - 1, y - 1, x + 1, y + 1) -- Dot in center

                    -- Highlight best target step with brighter color
                elseif best_target and i == best_target.tick_offset then
                    -- Draw filled circle for target point (brighter)
                    draw.Color(255, 50, 50, POINT_ALPHA + 100) -- Brighter red for target

                    -- Use rectangles in a cross pattern to simulate circle
                    draw.FilledRect(x - size - 1, y - 1, x + size + 1, y + 1) -- Horizontal
                    draw.FilledRect(x - 1, y - size - 1, x + 1, y + size + 1) -- Vertical
                else
                    -- Check if this point has been adjusted for stabilization
                    local prediction = nil
                    local player = entities.GetLocalPlayer()

                    -- Safely get the player eye position
                    if player and player:IsAlive() then
                        local view_pos = player:GetAbsOrigin() + player:GetPropVector("localdata", "m_vecViewOffset[0]")
                        prediction = PredictViewPath(engine.GetViewAngles(), view_pos)
                    else
                        prediction = { adjusted = {} }
                    end

                    if prediction.adjusted and prediction.adjusted[i] then
                        -- Magenta for adjusted points (stabilized)
                        draw.Color(255, 0, 255, POINT_ALPHA)
                    else
                        -- Blue for raw prediction points
                        draw.Color(50, 200, 255, POINT_ALPHA)
                    end

                    -- Use rectangles in a cross pattern to simulate circle
                    draw.FilledRect(x - size, y - 1, x + size, y + 1) -- Horizontal
                    draw.FilledRect(x - 1, y - size, x + 1, y + size) -- Vertical
                end

                ::continue::
            end
        end

        -- If we have a target, draw a line from the best prediction to target
        if best_target and best_target.position then
            local target_screen = WorldToScreen(best_target.position)
            if target_screen then
                local step_pos = prediction_path[best_target.tick_offset]
                if step_pos then
                    -- Draw line from prediction to target
                    draw.Color(255, 0, 0, 180) -- Bright red line
                    draw.Line(
                        math.floor(step_pos.x + 0.5),
                        math.floor(step_pos.y + 0.5),
                        math.floor(target_screen.x + 0.5),
                        math.floor(target_screen.y + 0.5)
                    )

                    -- Draw target point
                    draw.Color(255, 255, 0, 200) -- Yellow
                    local tx = math.floor(target_screen.x + 0.5)
                    local ty = math.floor(target_screen.y + 0.5)
                    draw.FilledRect(tx - 3, ty - 3, tx + 3, ty + 3)
                    draw.OutlinedRect(tx - 3, ty - 3, tx + 3, ty + 3)
                end
            end
        end
    end
end

-- Register callbacks
callbacks.Register("CreateMove", CreateMove)
callbacks.Register("Draw", OnDraw)
