## Function/Symbol: Entity.RemoveCond

> Remove a TF2 condition from a player

### Curated Usage Examples

```lua
local me = entities.GetLocalPlayer()
if me and me:InCond(TFCond_OnFire) then
    me:RemoveCond(TFCond_OnFire)
end
```

### Notes
- Server may reject; use carefully
