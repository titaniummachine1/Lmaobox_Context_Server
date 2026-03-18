## Function/Symbol: playerlist.GetPriority

> Get aimbot priority of a player

### Curated Usage Examples

```lua
local player = entities.GetByIndex(idx)
if player then
    local prio = playerlist.GetPriority(player)
    print("Priority: " .. prio)
end
```

### Notes
- Higher priority = more likely to be targeted

