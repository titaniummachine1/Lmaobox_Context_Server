## Constants Reference: E_LifeState

> Life state constants. More granular than `Entity:IsAlive()` — use `m_lifeState` prop or compare against these.

### Constants

| Constant               | Value | Meaning                                 |
| ---------------------- | ----- | --------------------------------------- |
| `LIFE_ALIVE`           | 0     | Alive and active                        |
| `LIFE_DYING`           | 1     | In death animation (no longer hittable) |
| `LIFE_DEAD`            | 2     | Fully dead                              |
| `LIFE_RESPAWNABLE`     | 3     | Dead but can respawn                    |
| `LIFE_DISCARDAIM_BODY` | 4     | Rag-doll, discard aim                   |

### Curated Usage Examples

#### Precise alive check (vs IsAlive)

```lua
-- Entity:IsAlive() is equivalent to m_lifeState == LIFE_ALIVE.
-- Reading the prop directly lets you distinguish dying vs dead.
local lifeState = entity:GetPropInt("m_lifeState")
local isAlive      = lifeState == LIFE_ALIVE
local isDying      = lifeState == LIFE_DYING  -- death anim, not valid target
local isFullyDead  = lifeState == LIFE_DEAD or lifeState == LIFE_RESPAWNABLE
```

### Notes

- For targeting, `LIFE_DYING` is not a valid target (no hitbox interaction).
- `Entity:IsAlive()` is the preferred shorthand for `LIFE_ALIVE` checks — use the prop directly only when you need the finer distinction.
