## Pattern: Chams – ForcedMaterialOverride + Stencil Outline

> Full DrawModel callback chams pattern: flat color, wallhack depth range, stencil outline.
> Source-verified from real scripts. Uses `callbacks.Register("DrawModel", ...)`.

### Core Concepts

- `materials.Create(name, vmt)` — create a custom material once at load time (never inside callbacks)
- `ctx:ForcedMaterialOverride(mat)` — swap material for this draw pass
- `ctx:SetColorModulation(r, g, b)` — tint (0–1 float range for this method)
- `ctx:SetAlphaModulation(a)` — alpha (0.0–1.0 float)
- `ctx:Execute()` — draw the model now with current settings
- `render.SetStencilEnable(true)` — enable stencil buffer operations
- `ctx:DepthRange(near, far)` — modify depth for wallhack; **always reset to (0, 1) when done**
- `render.OverrideDepthEnable(true, true)` — required before `DepthRange` calls
- `render.ClearBuffers(false, false, true)` — clear stencil buffer only

### Material VMT Formats

```lua
-- Flat unlit (most common for chams)
local matFlat = materials.Create("my_flat_chams", [[
"UnlitGeneric"
{
    $basetexture "vgui/white_additive"
    $model "1"
    $nofog "1"
}]])

-- Wireframe
local matWire = materials.Create("my_wire_chams", [[
"UnlitGeneric"
{
    $basetexture "vgui/white_additive"
    $wireframe "1"
    $additive "1"
}]])

-- Shiny (VertexLitGeneric with phong)
local matShiny = materials.Create("my_shiny_chams", [[
"VertexLitGeneric"
{
    $basetexture "vgui/white_additive"
    $model "1"
    $nofog "1"
    $phong "1"
    $phongexponent "30"
    $phongboost "10"
    $halflambert "1"
    $envmap "env_cubemap"
    $envmaptint "[1 1 1]"
    $envmapfresnel "1"
}]])

-- Existing game material (e.g. uber effect)
local uberRed = materials.Find("models/effects/invulnfx_red")
local uberBlue = materials.Find("models/effects/invulnfx_blue")
```

### Pattern 1: Simple Flat Chams (no wallhack)

```lua
local flat = materials.Create("simple_flat_chams", [[
"UnlitGeneric"
{
    $basetexture "vgui/white_additive"
    $model "1"
}]])

local function OnDrawModel(ctx)
    local ent = ctx:GetEntity()
    if not ent then return end
    if not ent:IsPlayer() then return end
    if not ent:IsAlive() then return end
    if ent:IsDormant() then return end
    if ctx:IsDrawingGlow() then return end

    local r, g, b = 1.0, 0.2, 0.2 -- red (0.0-1.0)
    ctx:ForcedMaterialOverride(flat)
    ctx:SetColorModulation(r, g, b)
    ctx:SetAlphaModulation(1.0)
    -- no Execute() needed; engine draws automatically
end

callbacks.Unregister("DrawModel", "simple_chams")
callbacks.Register("DrawModel", "simple_chams", OnDrawModel)
```

### Pattern 2: Stencil Outline + Wallhack (advanced)

Uses two stencil passes: one fills the stencil buffer (player shape), second renders a border.

```lua
local flat = materials.Create("chams_flat", [[
"UnlitGeneric"
{
    $basetexture "vgui/white_additive"
    $model "1"
    $nofog "1"
}]])

local wireframe = materials.Create("chams_wire", [[
"UnlitGeneric"
{
    $basetexture "vgui/white_additive"
    $wireframe "1"
    $additive "1"
}]])

-- Stencil: write 1 wherever this model is drawn
local function SetPlayerStencil()
    render.SetStencilCompareFunction(E_StencilComparisonFunction.STENCILCOMPARISONFUNCTION_ALWAYS)
    render.SetStencilPassOperation(E_StencilOperation.STENCILOPERATION_REPLACE)
    render.SetStencilFailOperation(E_StencilOperation.STENCILOPERATION_KEEP)
    render.SetStencilZFailOperation(E_StencilOperation.STENCILOPERATION_REPLACE)
    render.SetStencilTestMask(0x0)
    render.SetStencilWriteMask(0xFF)
    render.SetStencilReferenceValue(1)
end

-- Stencil: draw only where stencil == 0 (the border ring)
local function SetOutlineStencil()
    render.SetStencilCompareFunction(E_StencilComparisonFunction.STENCILCOMPARISONFUNCTION_EQUAL)
    render.SetStencilPassOperation(E_StencilOperation.STENCILOPERATION_KEEP)
    render.SetStencilFailOperation(E_StencilOperation.STENCILOPERATION_KEEP)
    render.SetStencilZFailOperation(E_StencilOperation.STENCILOPERATION_KEEP)
    render.SetStencilTestMask(0xFF)
    render.SetStencilWriteMask(0x0)
    render.SetStencilReferenceValue(0)
end

local function OnDrawModel(ctx)
    local ent = ctx:GetEntity()
    if not ent then return end
    if not ent:IsPlayer() then return end
    if not ent:IsAlive() then return end
    if ent:IsDormant() then return end
    if ctx:IsDrawingGlow() then return end

    local r, g, b = 0.2, 0.8, 1.0  -- solid color (0.0-1.0)

    -- Wallhack: depth range for see-through pass
    -- zNear=0, zFar=0.3 = draws in front of everything
    local useWallhack = true
    local zNear, zFar = 0, 0.3

    render.ClearBuffers(false, false, true)
    render.SetStencilEnable(true)
    render.OverrideDepthEnable(true, true)

    -- Pass 1: fill stencil buffer (model silhouette)
    SetPlayerStencil()
    ctx:ForcedMaterialOverride(flat)
    ctx:SetColorModulation(r, g, b)
    ctx:SetAlphaModulation(1.0)
    if useWallhack then ctx:DepthRange(zNear, zFar) end
    ctx:Execute()

    -- Pass 2: outline border (draws only outside the silhouette)
    SetOutlineStencil()
    ctx:ForcedMaterialOverride(wireframe)
    ctx:SetColorModulation(1.0, 1.0, 1.0)
    ctx:SetAlphaModulation(1.0)
    if useWallhack then ctx:DepthRange(zNear, zFar) end
    ctx:Execute()

    -- Pass 3: clear stencil by drawing black/invisible fill over player area
    render.ClearBuffers(false, false, true)
    SetPlayerStencil()
    ctx:ForcedMaterialOverride(flat)
    ctx:SetColorModulation(0, 0, 0)
    ctx:SetAlphaModulation(0)
    if useWallhack then ctx:DepthRange(zNear, zFar) end
    ctx:Execute()

    render.SetStencilEnable(false)
    render.OverrideDepthEnable(false, false)
    ctx:DepthRange(0, 1) -- ALWAYS reset depth range
end

-- Cleanup on FrameStageNotify to recover from any leaked state
local function OnFrameStage(stage)
    if stage == E_ClientFrameStage.FRAME_RENDER_END then
        render.OverrideDepthEnable(false, false)
        render.SetStencilEnable(false)
    end
end

callbacks.Unregister("DrawModel", "chams_v1")
callbacks.Unregister("FrameStageNotify", "chams_v1_fsn")
callbacks.Register("DrawModel", "chams_v1", OnDrawModel)
callbacks.Register("FrameStageNotify", "chams_v1_fsn", OnFrameStage)
```

### Pattern 3: Team Color Chams

```lua
local teamColors = {
    [2] = {1.0, 0.2, 0.2},  -- RED team (0.0-1.0)
    [3] = {0.2, 0.4, 1.0},  -- BLU team
}

local function OnDrawModel(ctx)
    local ent = ctx:GetEntity()
    if not ent then return end
    if not ent:IsPlayer() then return end
    if not ent:IsAlive() then return end
    if ent:IsDormant() then return end

    local teamNum = ent:GetTeamNumber()
    local color = teamColors[teamNum] or {1.0, 1.0, 1.0}

    ctx:ForcedMaterialOverride(flat)
    ctx:SetColorModulation(color[1], color[2], color[3])
end
```

### Pattern 4: Entity Type Filtering (players, buildings, viewmodel)

```lua
local function OnDrawModel(ctx)
    if ctx:IsDrawingGlow() then return end

    local ent = ctx:GetEntity()
    local modelName = ctx:GetModelName()
    if not modelName then return end

    -- Viewmodel / arms
    local isArms = string.find(modelName, "models/weapons/c_arms", 1, true)
    -- Weapon viewmodel
    local isWeapon = string.find(modelName, "models/weapons/c_models", 1, true)
    -- Cosmetics / wearables
    local isCosmetic = string.find(modelName, "models/player/items/", 1, true)

    if ent and ent:IsPlayer() and ent:IsAlive() and not ent:IsDormant() then
        -- player body chams
        ctx:ForcedMaterialOverride(flat)
        ctx:SetColorModulation(0.2, 1.0, 0.2)
    elseif isArms then
        -- arm chams
        ctx:ForcedMaterialOverride(flat)
        ctx:SetColorModulation(1.0, 0.5, 0.0)
    end
end
```

### Critical Rules

1. **Create materials at module top level** — NEVER inside a callback or loop (causes memory leaks)
2. **Always reset `DepthRange(0, 1)`** after wallhack — or all subsequent models will be bugged
3. **`ctx:Execute()` is for extra passes** — the engine draws the model once automatically after the callback
4. **`SetColorModulation` takes 0.0–1.0 floats**, not 0–255 integers
5. **`collectgarbage()` is banned** — it masks memory leaks, not fixes them
6. **Only draw chams for valid, non-dormant entities** to avoid flicker on disconnected players
7. **`ctx:IsDrawingGlow()`** — always check this and return early to avoid chams on glow pass
