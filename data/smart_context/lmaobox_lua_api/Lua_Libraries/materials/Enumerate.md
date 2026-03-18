## Function/Symbol: materials.Enumerate / materials.FindTexture / materials.CreateTextureRenderTarget

### Signatures

```lua
materials.Enumerate(callback: fun(material: Material))                              → void
materials.FindTexture(name: string, groupName: string, complain: boolean)           → Texture?
materials.CreateTextureRenderTarget(name: string, width: integer, height: integer)  → Texture
```

### Curated Usage Examples

#### Enumerate all loaded materials (debug / inspection)

```lua
-- WARNING: enumerate fires the callback for every single loaded material.
-- Do NOT call inside a per-frame callback.
materials.Enumerate(function(mat)
    local name = mat:GetName()
    if string.find(name, "player") then
        print(name)
    end
end)
```

#### FindTexture — get a built-in render target

```lua
-- "_rt_FullFrameFB" is the full-frame framebuffer texture used for post-process effects
-- groupName "RenderTargets" is standard for engine render targets
local rtFB = materials.FindTexture("_rt_FullFrameFB", "RenderTargets", true)
-- rtFB may be nil if the texture isn't loaded yet; guard before use
```

#### CreateTextureRenderTarget — allocate an off-screen buffer

```lua
-- Typically called once at init time (not per-frame)
local screenW, screenH = draw.GetScreenSize()
local glowBuffer = materials.CreateTextureRenderTarget("GlowBuffer", screenW, screenH)
```

#### Glow effect pattern (combining both)

```lua
-- Init
local screenW, screenH = draw.GetScreenSize()
local GLOW_RT = materials.CreateTextureRenderTarget("MyGlowRT", screenW, screenH)
local FB_TEX  = materials.FindTexture("_rt_FullFrameFB", "RenderTargets", true)

-- In Draw callback: render to the RT, blur it, composite onto FB
-- (requires render library for stencil and Push3DView operations)
```

### Notes

- `Enumerate` iterates **all** currently loaded materials — only suitable for debug/init, never per-frame
- `FindTexture` with `complain = true` will print a console warning if the texture is not found; use `false` to suppress
- `CreateTextureRenderTarget` allocates GPU memory; call once at module init, not per-frame
- The returned `Texture` from `CreateTextureRenderTarget` is used as a texture in a `Material` via `mat:SetTexture()`
- Render target textures may need a frame delay before they are usable; check for `nil` on first use
