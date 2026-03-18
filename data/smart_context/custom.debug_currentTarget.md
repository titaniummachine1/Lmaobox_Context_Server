## Function/Symbol: custom.debug_currentTarget

> Plain-global debug bridge for inspecting target tables across separate scripts

### Required Context:

- Use a normal global like `debug_currentTarget`, not `_G`, unless `_G` is absolutely necessary
- Export from the script that actually owns the local target value
- Read from a separate prototype or debug script
- Common target shape is `entity`, `angles`, `factor`; projectile-oriented variants may also include `pos`

### Curated Usage Examples:

#### Export from the real target-producing script

```lua
local currentTarget = GetBestTarget(me, weapon)
debug_currentTarget = currentTarget
if not currentTarget then
    return
end
```

#### Read from a separate prototype script

```lua
local target = debug_currentTarget
if not target then
    print("no exported target")
    return
end

print("entity", target.entity ~= nil)
print("angles", target.angles ~= nil)
print("factor", target.factor ~= nil)
print("pos", target.pos ~= nil)
```

### Notes:

- A standalone prototype cannot see another script's `local currentTarget`
- Export after the final target-selection step, not before, or the debug value can be stale
- Clear or overwrite the debug global every frame by assigning the current target result directly
- Do not assume `target.pos` exists on every target table; it is commonly an extra field used by projectile-target variants
