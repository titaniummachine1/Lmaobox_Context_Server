## Function/Symbol: client.GetConVar

> Get a console variable value

### Required Context
- Parameters: name (string)
- Returns: int?, float, string

### Curated Usage Examples

```lua
local fovInt, fovFloat, fovStr = client.GetConVar("fov_desired")
print("FOV: " .. fovInt)
```

### Notes
- Returns all three representations; use the one you need
