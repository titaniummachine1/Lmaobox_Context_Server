## Class: DrawModelContext

> Provided in the `"DrawModel"` callback. Controls how the current model draw call is executed. All methods must be called during active callback execution only.

### API Reference

| Method                                     | Returns   | Notes                                                                       |
| ------------------------------------------ | --------- | --------------------------------------------------------------------------- |
| `ctx:GetEntity()`                          | `Entity?` | Returns the entity being drawn; may be `nil` for non-entity models          |
| `ctx:GetModelName()`                       | `string`  | Full model path, e.g. `"models/player/heavy.mdl"`                           |
| `ctx:ForcedMaterialOverride(mat)`          | —         | Replaces the draw material for this pass                                    |
| `ctx:DrawExtraPass()`                      | —         | Redraws the model immediately; used for multi-layer effects                 |
| `ctx:Execute()`                            | —         | Forces an immediate draw; model always draws once even without calling this |
| `ctx:StudioSetColorModulation(r, g, b, a)` | —         | Tint studio models; r/g/b/a are integers 0–255                              |
| `ctx:StudioSetAlphaModulation(alpha)`      | —         | Alpha for studio models; 0.0–1.0                                            |
| `ctx:SetColorModulation(r, g, b)`          | —         | Tint non-studio models; integers 0–255                                      |
| `ctx:SetAlphaModulation(alpha)`            | —         | Alpha for non-studio models; 0.0–1.0                                        |
| `ctx:DepthRange(min, max)`                 | —         | Set depth range [0,1]; **reset to (0, 1) when done**                        |
| `ctx:SuppressEngineLighting(bool)`         | —         | Flatten engine lighting on this model                                       |
| `ctx:IsDrawingAntiAim()`                   | `boolean` | True when drawing the anti-aim indicator ghost                              |
| `ctx:IsDrawingBackTrack()`                 | `boolean` | True when drawing the backtrack indicator ghost                             |
| `ctx:IsDrawingGlow()`                      | `boolean` | True when drawing the glow model pass                                       |

### Key Facts

- **`Execute` vs `DrawExtraPass`:** The engine always draws the model once automatically. `DrawExtraPass()` adds extra passes _before_ the automatic one. `Execute()` forces an immediate draw _now_ and the automatic one still happens after.
- **`StudioSetColorModulation` vs `SetColorModulation`:** Studio models (players, weapons) use `Studio*` variants. Non-studio models use the non-prefixed variants.
- **Color range:** `r/g/b/a` in `StudioSetColorModulation` are integers 0–255. Alpha in `StudioSetAlphaModulation` and `SetAlphaModulation` is a float 0.0–1.0.
- **`DepthRange` leak:** If you call `ctx:DepthRange(0, 0.1)` and do not reset it, subsequent models in the frame will also render with that depth range.

### Curated Usage Examples

#### Basic Entity Chams (flat color)

```lua
local MATERIAL_VAR_IGNOREZ = 32 -- bit flag index for IgnoreZ

local matFlat = materials.Create("my_flat_chams", [[
    "UnlitGeneric"
    {
        "$basetexture" "vgui/white_additive"
        "$model" "1"
    }
]])

callbacks.Unregister("DrawModel", "basic_chams")
callbacks.Register("DrawModel", "basic_chams", function(ctx)
    local ent = ctx:GetEntity()
    if not ent then return end
    local isPlayer = ent:IsPlayer()
    if not isPlayer then return end
    local isAlive = ent:IsAlive()
    if not isAlive then return end
    local isDormant = ent:IsDormant()
    if isDormant then return end

    ctx:ForcedMaterialOverride(matFlat)
end)
```

#### Double-Pass Chams (wallhack layer + solid layer)

```lua
-- Wall-through (red, always visible) + solid (green, only in front of walls)
local matWall = materials.Create("my_chams_wall", [[
    "UnlitGeneric"
    {
        "$basetexture" "vgui/white_additive"
        "$model" "1"
        "$ignorez" "1"
    }
]])

local matSolid = materials.Create("my_chams_solid", [[
    "UnlitGeneric"
    {
        "$basetexture" "vgui/white_additive"
        "$model" "1"
        "$ignorez" "0"
    }
]])

callbacks.Unregister("DrawModel", "double_chams")
callbacks.Register("DrawModel", "double_chams", function(ctx)
    local ent = ctx:GetEntity()
    if not ent then return end
    if not ent:IsPlayer() then return end
    if not ent:IsAlive() then return end
    if ent:IsDormant() then return end

    -- Pass 1: behind-wall ghost (red tint)
    matWall:ColorModulate(1, 0, 0)
    ctx:ForcedMaterialOverride(matWall)
    ctx:DrawExtraPass()  -- fires before the engine's automatic pass

    -- Pass 2: solid (overrides the automatic engine pass)
    matSolid:ColorModulate(0, 1, 0)
    ctx:ForcedMaterialOverride(matSolid)
    -- engine draws this automatically, no Execute() needed
end)
```

#### Team-Colored Chams

```lua
local MAT_RED = materials.Create("chams_red", [["UnlitGeneric" { "$basetexture" "vgui/white_additive" "$model" "1" }]])
local MAT_BLU = materials.Create("chams_blu", [["UnlitGeneric" { "$basetexture" "vgui/white_additive" "$model" "1" }]])

callbacks.Unregister("DrawModel", "team_chams")
callbacks.Register("DrawModel", "team_chams", function(ctx)
    local ent = ctx:GetEntity()
    if not ent then return end
    if not ent:IsPlayer() then return end
    if not ent:IsAlive() then return end
    if ent:IsDormant() then return end

    local teamNum = ent:GetTeamNumber()
    local isRedTeam = teamNum == 2
    if isRedTeam then
        MAT_RED:ColorModulate(1, 0, 0)
        ctx:ForcedMaterialOverride(MAT_RED)
    else
        MAT_BLU:ColorModulate(0, 0.4, 1)
        ctx:ForcedMaterialOverride(MAT_BLU)
    end
end)
```

#### Skip Indicator Model Passes

```lua
callbacks.Register("DrawModel", "skip_indicators", function(ctx)
    local isIndicator = ctx:IsDrawingAntiAim() or ctx:IsDrawingBackTrack() or ctx:IsDrawingGlow()
    if isIndicator then return end
    -- your chams logic here
end)
```

### Notes

- Always guard with `ent:IsPlayer()`, `ent:IsAlive()`, `ent:IsDormant()` before applying chams — otherwise projectiles and world models get tinted
- `materials.Create()` must be called **outside** the callback (module init time), never inside per-frame
- The `DrawModel` callback fires for all visible models including viewmodels, world props, and lmaobox indicator ghosts
- Use `ctx:IsDrawingAntiAim()` / `ctx:IsDrawingBackTrack()` / `ctx:IsDrawingGlow()` to skip those indicator passes if you don't want them chammed
