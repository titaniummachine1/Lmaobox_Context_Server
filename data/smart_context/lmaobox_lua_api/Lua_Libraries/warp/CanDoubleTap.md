## Function/Symbol: warp.CanDoubleTap

> Check if weapon can double tap (shoot twice instantly via warp)

### Required Context
- Parameters: weapon (Entity)
- Returns: boolean

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon and warp.CanDoubleTap(weapon) then
    warp.TriggerDoubleTap()
end
```

### Notes
- Requires sufficient charged ticks
- Use for instant double-shot exploit

