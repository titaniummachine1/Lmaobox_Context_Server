## Function/Symbol: Entity.GetAbsOrigin

> Get the world position (Vector3) of an entity

### Required Context

- Returns: Vector3
- Types: Entity, Vector3

### Curated Usage Examples

#### Basic position

```lua
local ent = entities.GetByIndex(idx)
if ent then
    local pos = ent:GetAbsOrigin()
    print(tostring(pos))
end
```

#### Distance between entities

```lua
local function Distance(entA, entB)
    return (entB:GetAbsOrigin() - entA:GetAbsOrigin()):Length()
end
```

#### World-to-screen for ESP

```lua
local function WorldToScreen(pos)
    local screen = client.WorldToScreen(pos)
    return screen -- {x, y} or nil
end

local ent = entities.GetByIndex(idx)
if ent then
    local screen = WorldToScreen(ent:GetAbsOrigin())
    if screen then
        draw.Text(screen[1], screen[2], ent:GetName())
    end
end
```

#### Predict movement

```lua
local function PredictPos(ent, dt)
    local vel = ent:GetPropVector("localdata", "m_vecVelocity[0]")
    return ent:GetAbsOrigin() + vel * dt
end
```

### Notes

- Use with `GetPropVector("localdata", "m_vecViewOffset[0]")` to get eye position
- Use subtraction for direction: `dir = targetPos - myPos`
