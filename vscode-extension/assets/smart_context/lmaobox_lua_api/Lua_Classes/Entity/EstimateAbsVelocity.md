## Function/Symbol: Entity.EstimateAbsVelocity

> Get estimated absolute velocity (Vector3)

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent then
    local vel = ent:EstimateAbsVelocity()
    local speed = vel:Length()
    print("Speed: " .. math.floor(speed))
end
```

### Notes

- Alternative to `GetPropVector("localdata", "m_vecVelocity[0]")`

