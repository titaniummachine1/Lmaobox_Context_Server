## Constants Reference: Trace Masks

> Common mask constants for TraceLine/TraceHull

### Core Masks

- `MASK_SHOT_HULL` - Standard weapon traces (players + world)
- `MASK_SHOT` - Hitscan traces
- `MASK_PLAYERSOLID` - Movement collision (players + world)
- `MASK_PLAYERSOLID_BRUSHONLY` - Movement collision (world only, ignore entities)
- `MASK_SOLID` - Solid surfaces
- `MASK_WATER` - Water volumes
- `MASK_ALL` - Everything (0xFFFFFFFF)

### Contents Flags

- `CONTENTS_EMPTY` - Air/empty (0)
- `CONTENTS_SOLID` - Solid geometry (0x1)
- `CONTENTS_GRATE` - Grates (0x8)
- `CONTENTS_WATER` - Water (0x20)
- `CONTENTS_HITBOX` - Entity hitboxes (0x40000000)

### Common Usage

#### Visibility check (ignore grates)

```lua
local trace = engine.TraceLine(src, dst, MASK_SHOT_HULL)
```

#### Visibility with grates counted as solid

```lua
local trace = engine.TraceLine(src, dst, MASK_SHOT | CONTENTS_GRATE)
```

#### Movement path check (ignore entities)

```lua
local trace = engine.TraceHull(from, to, mins, maxs, MASK_PLAYERSOLID_BRUSHONLY)
```

#### Splash damage check (entities + grates)

```lua
local trace = engine.TraceLine(explosionPos, targetCOM, MASK_SHOT | CONTENTS_GRATE)
```

### Notes

- Combine masks with `|` operator: `MASK_SHOT | CONTENTS_GRATE`
- `BRUSHONLY` variants ignore entities (faster for wall checks)
- Use `MASK_SHOT_HULL` for standard visibility/aimbot traces

