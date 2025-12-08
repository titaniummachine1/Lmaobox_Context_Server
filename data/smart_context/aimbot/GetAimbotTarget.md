## Function/Symbol: aimbot.GetAimbotTarget

> Get entity index of current aimbot target (if built-in aimbot is active)

### Curated Usage Examples

```lua
local targetIdx = aimbot.GetAimbotTarget()
if targetIdx and targetIdx > 0 then
    local target = entities.GetByIndex(targetIdx)
    if target then
        print("Aiming at: " .. target:GetName())
    end
end
```

### Notes
- Returns 0 or nil if no target
- Use to integrate with built-in aimbot or debug target selection
