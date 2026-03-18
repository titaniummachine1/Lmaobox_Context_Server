## Function/Symbol: engine.RandomFloat / RandomInt / RandomSeed / RandomFloatExp

> Engine-seeded RNG functions — share the engine's random seed state

### Signatures

```lua
engine.RandomSeed(seed: integer)                              → void
engine.RandomFloat(min: number, max?: number)                 → number
engine.RandomInt(min: integer, max: integer)                  → integer
engine.RandomFloatExp(min: number, max: number, exp?: number) → number
```

### Curated Usage Examples

```lua
-- Seed before use when you need reproducible output
engine.RandomSeed(42)
local x = engine.RandomFloat(0, 1)     -- [0.0, 1.0]
local n = engine.RandomInt(1, 6)        -- 1–6 inclusive
local exp = engine.RandomFloatExp(0, 1, 2.0)  -- exponential bias toward 0
```

### Notes

- `RandomFloat(min)` without `max` returns a float in `[min, 1.0]` (max defaults to 1.0)
- `RandomFloatExp` biases toward `min` as `exp` increases (exp > 1 = lower values more likely)
- Shares state with the game engine's own RNG — calling `RandomSeed` may affect engine behavior; use only when needed
- For unbiased coin flips use `engine.RandomInt(0, 1) == 1`
