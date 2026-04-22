## Function/Symbol: engine.GetMapName

> Get current map name

### Curated Usage Examples

```lua
local map = engine.GetMapName()
print("Current map: " .. map)

if map == "pl_upward" then
    print("On Upward")
end
```

### Notes

- Returns map file name without extension

