## Function/Symbol: Entity.IsCritBoosted

> Check if player is currently crit boosted by external source

### Curated Usage Examples

```lua
local target = entities.GetByIndex(idx)
if target and target:IsCritBoosted() then
    print(target:GetName() .. " has crits!")
end
```

### Notes
- Does not include mini-crits; only full crit boost
