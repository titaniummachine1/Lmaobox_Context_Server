## Function/Symbol: entities.CreateTempEntityByName

> Create a non-networkable temporary entity (TempEntity)

### Required Context

- Parameters: className (string)
- Returns: TempEntity
- You must call `:Release()` when done; call `PostDataUpdate()` to trigger

### Curated Usage Examples

```lua
local te = entities.CreateTempEntityByName("Explosion")
if te then
    -- configure TE props as needed
    te:PostDataUpdate() -- trigger
    te:Release()
end
```

### Notes

- Manual lifecycle: PostDataUpdate then Release
- Use for temporary visual effects; does not network

