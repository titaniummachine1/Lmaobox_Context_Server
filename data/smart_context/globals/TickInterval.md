## Function/Symbol: globals.TickInterval

> Get server tick interval (usually 1/66 or ~0.015 seconds)

### Curated Usage Examples

```lua
local ti = globals.TickInterval()
print("Tick interval: " .. ti .. " sec")
```

### Notes
- Use for time conversions: ticks * TickInterval = seconds
