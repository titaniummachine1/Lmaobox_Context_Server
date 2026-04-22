## Function/Symbol: Entity.IsAttackCritical

> Check if a given command number would result in a crit

### Required Context
- Parameters: commandNumber (from UserCmd)
- Returns: boolean

### Curated Usage Examples

```lua
callbacks.Register("CreateMove", "crit_check", function(cmd)
    local weapon = me:GetPropEntity("m_hActiveWeapon")
    if weapon then
        local isCrit = weapon:IsAttackCritical(cmd.command_number)
        if isCrit then
            print("This attack will crit!")
        end
    end
end)
```

### Notes
- Use for crit exploit detection/prediction

