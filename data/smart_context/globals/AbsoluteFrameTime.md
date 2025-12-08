## Function/Symbol: globals.AbsoluteFrameTime

> Get delta time between frames (more reliable than FrameTime)

### Curated Usage Examples

```lua
local dt = globals.AbsoluteFrameTime()
-- use for frame-independent calculations
```

### Notes

- Prefer over FrameTime in most callbacks

