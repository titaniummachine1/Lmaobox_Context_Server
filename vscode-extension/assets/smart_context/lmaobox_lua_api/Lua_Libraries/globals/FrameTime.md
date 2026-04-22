## Function/Symbol: globals.FrameTime

> Get delta time between frames

### Curated Usage Examples

```lua
local dt = globals.FrameTime()
-- use for frame-independent timers
```

### Notes
- May return tick interval in some callbacks; use AbsoluteFrameTime if needed

