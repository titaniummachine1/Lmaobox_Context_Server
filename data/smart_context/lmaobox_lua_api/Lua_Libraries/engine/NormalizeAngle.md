# Math.NormalizeAngle() - Euler Angle Wrapping

## Basic Usage

```lua
local wrapped_angle = Math.NormalizeAngle(raw_angle)
-- Result: angle in range [-180, 180] degrees
```

## Real-World Pattern: Angle Delta Calculation

The most common use case in TF2 aimbots — detecting yaw changes:

```lua
local current_yaw = player_angles.y
local previous_yaw = last_angles[player_index].y

-- RAW DELTA (can be -360 to +360):
local raw_delta = current_yaw - previous_yaw

-- WRAPPED DELTA (normalized to [-180, 180]):
local delta = Math.NormalizeAngle(raw_delta)

if math.abs(delta) > 45 then
    -- Player snapped >45 degrees, likely anti-aim
end
```

## Why Normalize?

Without normalization:

- 359° - 1° = 358° (wrong! should be -2°)
- 180° - (-180°) = 360° (wrong! should be 0°)

With normalization:

- 359° - 1° → `-2°` ✓
- 180° - (-180°) → `0°` ✓

## Processing Zone Example

From resolver code:

```lua
local function checkYawChange(player_index, current_angles)
    local last_angles = player_history[player_index]

    if not last_angles then
        return nil  -- First frame
    end

    local yaw_delta = Math.NormalizeAngle(
        current_angles.y - last_angles.y
    )

    player_history[player_index] = current_angles
    return yaw_delta
end
```

## Note

- Only normalizes **yaw** (Y-axis / horizontal)
- Angle math in Lmaobox scripts is conventionally in **degrees**, not radians
- Pitch (X) and Roll (Z) rarely need wrapping in gameplay
- Legit player pitch is typically clamped near `[-89, 89]`, while resolver or exploit code may observe wider values
- Used in anti-aim detection, angle prediction, and resolver logic
