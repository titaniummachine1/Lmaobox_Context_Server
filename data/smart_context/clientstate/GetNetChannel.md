## Function/Symbol: clientstate.GetNetChannel

> Get the NetChannel object

### Curated Usage Examples

```lua
local nc = clientstate.GetNetChannel()
if nc then
    local latency = nc:GetLatency(0) -- incoming
    print("Latency: " .. math.floor(latency * 1000) .. " ms")
end
```

### Notes
- Returns nil if not connected
- Use NetChannel methods for latency/packet stats
