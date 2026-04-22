# Quaternion Math - Advanced Angle Representation

## Why Quaternions?

From `AngleExtrapolation.lua` in processing zone:

- **Euler angles**: Simple (pitch, yaw, roll) but suffer from gimbal lock
- **Quaternions**: Smooth interpolation, no singularities, better for rotation prediction

## Basic Quaternion Operations

### Normalization

```lua
function Quat.normalize(q)
    -- Ensure unit quaternion (length = 1)
    local mag = math.sqrt(q.x * q.x + q.y * q.y + q.z * q.z + q.w * q.w)
    if mag == 0 then return q end
    return {
        x = q.x / mag,
        y = q.y / mag,
        z = q.z / mag,
        w = q.w / mag
    }
end
```

### Quaternion Multiplication (Rotate by another rotation)

```lua
function Quat.multiply(q1, q2)
    return {
        x = q1.w * q2.x + q1.x * q2.w + q1.y * q2.z - q1.z * q2.y,
        y = q1.w * q2.y - q1.x * q2.z + q1.y * q2.w + q1.z * q2.x,
        z = q1.w * q2.z + q1.x * q2.y - q1.y * q2.x + q1.z * q2.w,
        w = q1.w * q2.w - q1.x * q2.x - q1.y * q2.y - q1.z * q2.z
    }
end
```

### Quaternion Conjugate (Inverse rotation)

```lua
function Quat.conjugate(q)
    return { x = -q.x, y = -q.y, z = -q.z, w = q.w }
end
```

### Relative Rotation (q1 relative to q2)

```lua
function Quat.getRelativeRotation(q1, q2)
    return Quat.normalize(
        Quat.multiply(q2, Quat.conjugate(q1))
    )
end
```

## Real-World Usage: Angle Extrapolation

From processing zone script:

```lua
-- Convert angle to quaternion
local ang_quat = eulerToQuat(player_angles)

-- Apply relative rotation for next frame
local relative_rotation = Quat.getRelativeRotation(
    last_frame_quat,
    current_frame_quat
)

-- Predict next frame by applying same rotation
local predicted_quat = Quat.normalize(
    Quat.multiply(current_frame_quat, relative_rotation)
)

-- Convert back to Euler angles for output
local predicted_angles = quatToEuler(predicted_quat)
```

## When to Use Quaternions

✅ **Use Quaternions for**:

- Smooth angle interpolation
- Predicting rotation trajectories
- Advanced resolver logic
- Complex rotation combinations

❌ **Don't use Quaternions for**:

- Simple angle wrapping (use `Math.NormalizeAngle()`)
- Single axis adjustments (use Euler angles)
- Beginner aimbot logic
