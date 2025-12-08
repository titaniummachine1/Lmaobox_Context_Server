## Function/Symbol: Vector3.Length2DSqr

> Get squared 2D length (faster than Length2D)

### Curated Usage Examples

```lua
local vel = player:EstimateAbsVelocity()
local speed2DSqr = vel:Length2DSqr()

if speed2DSqr > (300 * 300) then
    print("Moving fast horizontally")
end
```

### Notes

- Use for comparisons without sqrt

