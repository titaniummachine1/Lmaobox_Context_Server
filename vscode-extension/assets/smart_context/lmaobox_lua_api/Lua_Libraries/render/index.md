## Library: render

> Low-level 3D rendering pipeline. Used for custom views, off-screen render targets, and screen-space material drawing. **Not the same as `draw` — `draw` is 2D HUD; `render` is 3D/material pipeline.**

### Key Functions

| Function | Description |
|---|---|
| `render.Push3DView(view, clearFlags, texture?)` | Push a custom 3D view (perspective camera) onto the render stack |
| `render.PopView()` | Pop the current view off the stack |
| `render.ViewDrawScene(draw3Dskybox, drawSkybox, view)` | Draw the scene to the current render target |
| `render.DrawScreenSpaceRectangle(mat, x, y, w, h, u0, v0, u1, v1, texW, texH)` | Blit a material into a screen rect |
| `render.DrawScreenSpaceQuad(material)` | Full-screen material quad |
| `render.GetViewport()` → `x, y, w, h` | Current viewport bounds |
| `render.Viewport(x, y, w, h)` | Set viewport |
| `render.SetRenderTarget(texture)` | Redirect rendering to a texture |
| `render.GetRenderTarget()` → `Texture` | Get current render target |
| `render.PushRenderTargetAndViewport()` | Save current target+viewport to stack |
| `render.PopRenderTargetAndViewport()` | Restore from stack |
| `render.ClearBuffers(color, depth, stencil)` | Clear render target buffers |
| `render.ClearColor3ub(r, g, b)` | Clear color buffer to RGB |
| `render.ClearColor4ub(r, g, b, a)` | Clear color buffer to RGBA |
| `render.DepthRange(zNear, zFar)` | Set depth range |
| `render.OverrideDepthEnable(enable, depthEnable)` | Override depth test |
| `render.OverrideAlphaWriteEnable(enable, alphaWriteEnable)` | Override alpha write |
| `render.SetStencilEnable(enable)` | Enable/disable stencil test |

### Curated Usage Patterns

#### Render scene to a texture (off-screen camera)

```lua
-- Requires draw.CreateTexture to pre-allocate the target.
-- Only valid inside a rendering callback (e.g. Draw).
local renderTex = draw.CreateTexture(512, 512)

local view = {}  -- Construct ViewSetup fields
view.origin = entity:GetAbsOrigin()
view.angles = EulerAngles(0, entity:GetAbsAngles().yaw, 0)
view.fov = 90
view.width = 512
view.height = 512
view.zNear = 1
view.zFar = 8192

render.PushRenderTargetAndViewport()
render.SetRenderTarget(renderTex)
render.Viewport(0, 0, 512, 512)
render.ClearBuffers(true, true, false)
render.Push3DView(view, VIEW_CLEAR_COLOR | VIEW_CLEAR_DEPTH, renderTex)
render.ViewDrawScene(false, false, view)
render.PopView()
render.PopRenderTargetAndViewport()
```

#### Full-screen material blit

```lua
-- Blit a material over the full screen (e.g. post-process effect).
callbacks.Register("Draw", "fullscreen_overlay", function()
    local sw, sh = draw.GetScreenSize()
    local mat = materials.Find("effects/grayscale")
    if not mat then return end
    render.DrawScreenSpaceRectangle(mat, 0, 0, sw, sh, 0, 0, 1, 1, sw, sh)
end)
```

### Notes

- `render` is for **3D/material work**. For text, colored boxes, and 2D lines, use the `draw` library.
- Push/Pop operations must be balanced — a missing `PopView()` will corrupt the render stack.
- `VIEW_CLEAR_COLOR`, `VIEW_CLEAR_DEPTH`, etc. are `E_ClearFlags` constants used as bitfield in `Push3DView`'s `clearFlags` param.
- `render.ViewDrawScene` must be called between `Push3DView` and `PopView`.
- Off-screen render targets are expensive. Only render per-frame if necessary, and reuse textures.
