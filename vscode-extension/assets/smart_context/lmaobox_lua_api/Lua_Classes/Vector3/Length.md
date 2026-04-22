## Function/Symbol: Vector3.Length

> Get the magnitude/length of a Vector3

### Required Context

- Returns: number
- Types: Vector3

### Curated Usage Examples

#### Distance between points

```lua
local delta = pos2 - pos1
local dist = delta:Length()
```

#### Normalize direction

```lua
local dir = (to - from)
local norm = dir / dir:Length()
```

#### Speed from velocity

```lua
local vel = player:GetPropVector("localdata", "m_vecVelocity[0]")
local speed = vel:Length()
if speed > 300 then
    print("Running fast")
end
```

#### 2D speed (ignore vertical)

```lua
local vel = player:GetPropVector("localdata", "m_vecVelocity[0]")
vel.z = 0
local groundSpeed = vel:Length()
```

### Notes

- Division by zero handled by engine, but avoid `Length()` on zero vector for logic
- For unit direction, use `v / v:Length()`
