## Function/Symbol: Entity.GetMaxBuffedHealth

> Get player's max health including buffs (overheal)

### Curated Usage Examples

```lua
local player = entities.GetLocalPlayer()
if player then
    local hp = player:GetHealth()
    local maxBuffed = player:GetMaxBuffedHealth()
    local overheal = hp - player:GetMaxHealth()
    print("Overheal: " .. overheal .. " / " .. maxBuffed)
end
```

### Notes
- Use with GetHealth and GetMaxHealth to compute overheal amount

