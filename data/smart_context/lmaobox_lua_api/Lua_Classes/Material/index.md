## Class: Material

> Represents a Source Engine material. Obtained from `materials.Find()`, `materials.Create()`, or `materials.FindAll()`.

### Key Methods

| Method | Description |
|---|---|
| `GetName()` → `string` | Material path (e.g. `"effects/grayscale"`) |
| `GetTextureGroupName()` → `string` | Group the material belongs to |
| `AlphaModulate(alpha)` | Set transparency (0.0–1.0, increments of 0.1) |
| `ColorModulate(r, g, b)` | Tint the material (values 0.0–1.0) |
| `SetMaterialVarFlag(flag, value)` | Set a material flag (E_MaterialFlag constants) |
| `SetShaderParam(name, value)` | Set a shader parameter by name |

### Curated Usage Patterns

#### Chams (replace player material)

```lua
-- Called inside DrawModel callback to override the model's material
local chamsMat = materials.Create("chams_flat", [[
    "UnlitGeneric"
    {
        "$basetexture" "vgui/white"
        "$ignorez" "0"
    }
]])

callbacks.Register("DrawModel", "chams", function(ctx)
    local ent = ctx:GetEntity()
    if not ent or not ent:IsPlayer() then return end
    if ent == entities.GetLocalPlayer() then return end
    if ent:GetTeamNumber() == entities.GetLocalPlayer():GetTeamNumber() then return end

    chamsMat:ColorModulate(1, 0, 0)  -- red
    ctx:ForcedMaterialOverride(chamsMat)
end)
```

#### Find and modulate existing material

```lua
local mat = materials.Find("effects/yellowflare")
if mat then
    mat:AlphaModulate(0.5)   -- 50% transparent
    mat:ColorModulate(1, 0.5, 0)  -- orange tint
end
```

#### Wallhack (see-through walls)

```lua
local wallhackMat = materials.Create("wallhack_flat", [[
    "UnlitGeneric"
    {
        "$basetexture" "vgui/white"
        "$ignorez" "1"
    }
]])
```

### Notes

- `SetShaderParam` accepts string key names matching the VMT shader parameters (e.g. `"$color2"`, `"$alpha"`).
- `AlphaModulate` values below 0.1 may have no visible effect due to engine rounding.
- Materials created with `materials.Create` persist until the script is unloaded. Avoid creating materials inside per-frame callbacks.
- `ColorModulate` RGB values are in `[0, 1]` range — **not** 0–255.
