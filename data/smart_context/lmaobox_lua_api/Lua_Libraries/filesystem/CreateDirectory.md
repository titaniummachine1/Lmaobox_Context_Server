## Function/Symbol: filesystem.CreateDirectory

> Create a directory for storing files

### Curated Usage Examples

```lua
local success, fullPath = filesystem.CreateDirectory("Lua MyScript")
if success then
    print("Dir: " .. fullPath)
    -- Use fullPath for file operations
end
```

### Notes

- Returns success (bool) and full path
- Succeeds even if directory already exists

