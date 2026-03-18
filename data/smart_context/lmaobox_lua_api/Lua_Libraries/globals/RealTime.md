## Function/Symbol: globals.RealTime

> Get time since game start (seconds)

### Curated Usage Examples

```lua
local uptime = globals.RealTime()
print("Game running for: " .. math.floor(uptime) .. " seconds")
```

### Notes

- Continues counting even when paused/loading
- Use CurTime for gameplay timing

