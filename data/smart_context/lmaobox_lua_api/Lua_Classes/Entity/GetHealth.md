## Function/Symbol: Entity.GetHealth

> Get current health of an entity

### Required Context

- Returns: integer
- Types: Entity

### Curated Usage Examples

#### Basic health read

```lua
local ent = entities.GetByIndex(idx)
if ent then
    print("HP: " .. ent:GetHealth())
end
```

#### Health-based ESP color

```lua
local function HealthColor(ent)
    local hp = ent:GetHealth()
    local max = ent:GetMaxHealth()
    local pct = hp / max
    if pct > 0.6 then
        draw.Color(0, 255, 0, 255)
    elseif pct > 0.3 then
        draw.Color(255, 255, 0, 255)
    else
        draw.Color(255, 0, 0, 255)
    end
end
```

#### Low health warning

```lua
local me = entities.GetLocalPlayer()
if me and me:GetHealth() < 40 then
    client.Command("voicemenu 0 0", true) -- play medic call
end
```

### Notes

- Pair with `GetMaxHealth` for percentages
- Dead entities may return 0 or negative
