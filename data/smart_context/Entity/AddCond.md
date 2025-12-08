## Function/Symbol: Entity.AddCond

> Add a TF2 condition to a player

### Required Context
- Parameters: condition (E_TFCOND), duration (optional, -1 = infinite)
- Constants: E_TFCOND

### Curated Usage Examples

```lua
local me = entities.GetLocalPlayer()
if me then
    me:AddCond(TFCond_CritOnKill, 5.0) -- 5 second crit
end
```

### Notes
- Use sparingly; server may reject invalid conditions

