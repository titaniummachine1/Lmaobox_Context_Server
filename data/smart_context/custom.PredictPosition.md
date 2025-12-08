## Function/Symbol: custom.PredictPosition

> Predict an entity's future position using velocity

### Required Context

- Functions: Entity:GetAbsOrigin, Entity:EstimateAbsVelocity
- Types: Vector3, Entity

### Curated Usage Examples

#### Linear prediction

```lua
local function PredictPosition(ent, dt)
    local pos = ent:GetAbsOrigin()
    local vel = Entity:EstimateAbsVelocity()
    return pos + vel * dt
end

-- Usage for projectile lead
local target = entities.GetByIndex(targetIdx)
local predicted = PredictPosition(target, 0.1) -- 100 ms ahead
local aim = AngleToPosition(eyePos, predicted)
```

#### Clamp vertical for ground prediction

```lua
local function PredictFlat(ent, dt)
    local pos = ent:GetAbsOrigin()
    local vel = ent:EstimateAbsVelocity()
    vel.z = 0
    return pos + vel * dt
end
```

### Notes

- Simple linear model; adjust dt based on projectile speed
- For hitscan, prediction often unnecessary; for projectiles, essential
