## Function/Symbol: warp.TriggerDoubleTap

> Trigger double tap (shoot twice instantly)

### Curated Usage Examples

```lua
local weapon = me:GetPropEntity("m_hActiveWeapon")
if weapon and warp.CanDoubleTap(weapon) then
    warp.TriggerDoubleTap()
end
```

### Notes
- Requires charged ticks; use CanDoubleTap before calling
