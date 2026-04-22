## Function/Symbol: Vector3.LengthSqr

> Get squared length (faster than Length)

### Curated Usage Examples

```lua
local dist2 = (pos2 - pos1):LengthSqr()
if dist2 < (500 * 500) then
    print("Within 500 units")
end
```

### Notes

- Use for distance comparisons without sqrt

