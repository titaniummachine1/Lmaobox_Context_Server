## Class: TempEntity

> Represents a temporary entity (non-networked). Created via entities.CreateTempEntityByName

### Lifecycle

- Create with `entities.CreateTempEntityByName(className)`
- Configure props (if needed)
- Trigger with `:PostDataUpdate()`
- Release with `:Release()`

### Curated Usage Examples

```lua
local te = entities.CreateTempEntityByName("Explosion")
if te then
    -- set props if applicable
    te:PostDataUpdate()
    te:Release()
end
```

### Notes

- For visual/temp effects; does not network
- Manual cleanup required (Release)
