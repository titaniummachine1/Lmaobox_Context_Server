## Function/Symbol: entities.GetPlayerResources

> Get the player resources entity

### Curated Usage Examples

#### Read scores/latency (if exposed)

```lua
local pr = entities.GetPlayerResources()
if pr then
    -- Example: read a resource prop (depends on game / props available)
    -- local score = pr:GetPropInt("m_iScore", playerIndex)
end
```

### Notes

- Props depend on game schema; use dump/inspection to find available fields

