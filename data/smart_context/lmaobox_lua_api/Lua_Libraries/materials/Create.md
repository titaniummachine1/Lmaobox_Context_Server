## Function/Symbol: materials.Create

> Create a custom material from VMT data

### Required Context
- Parameters: name (string), vmt (string - VMT syntax)
- Returns: Material

### Curated Usage Examples

```lua
local chamsMat = materials.Create("chams_flat", [[
"UnlitGeneric"
{
    "$basetexture" "vgui/white"
    "$ignorez" "1"
}
]])
```

### Notes
- VMT syntax: see Valve Developer Wiki for material parameters

