## Function/Symbol: Entity.IsDormant

> Check if entity is dormant (not being updated by server)

### Curated Usage Examples

```lua
local ent = entities.GetByIndex(idx)
if ent and not ent:IsDormant() and ent:IsAlive() then
    -- entity is active and alive
end
```

### Notes

- Dormant means the server is no longer simulating or fully networking that player to the client
- You may still have an entity handle because sound and partial client data can keep it around, but props like health, flags, and position can be stale
- Treat dormant players as invalid for targeting and most gameplay logic
- Rendering dormant entities is also misleading unless you intentionally want stale last-known-position visuals
- Common filter: `if ent and not ent:IsDormant() and ent:IsAlive()`
