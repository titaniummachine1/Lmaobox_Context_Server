## Function/Symbol: Vector3.Length2D

> Get 2D (horizontal) length of vector

### Curated Usage Examples

```lua
local vel = player:EstimateAbsVelocity()
local groundSpeed = vel:Length2D()
print("Ground speed: " .. math.floor(groundSpeed))
```

### Notes

- Ignores Z component
- Use for ground/horizontal speed checks

