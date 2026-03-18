## Class: ViewSetup

> Snapshot of the current render view parameters. Returned by `client.GetPlayerView()`. Passed to `render.Push3DView()`.

### Fields

| Field            | Type          | Description                       |
| ---------------- | ------------- | --------------------------------- |
| `x`              | `integer`     | Left edge of view window (pixels) |
| `y`              | `integer`     | Top edge of view window (pixels)  |
| `width`          | `integer`     | View window width (pixels)        |
| `height`         | `integer`     | View window height (pixels)       |
| `unscaledX`      | `integer`     | Left edge without HUD scaling     |
| `unscaledY`      | `integer`     | Top edge without HUD scaling      |
| `unscaledWidth`  | `integer`     | Width without HUD scaling         |
| `unscaledHeight` | `integer`     | Height without HUD scaling        |
| `origin`         | `Vector3`     | Camera origin (world position)    |
| `angles`         | `EulerAngles` | Camera angles                     |
| `fov`            | `number`      | Field of view (degrees)           |
| `fovViewmodel`   | `number`      | Viewmodel field of view           |
| `zNear`          | `number`      | Near clipping plane               |
| `zFar`           | `number`      | Far clipping plane                |
| `aspectRatio`    | `number`      | Width / Height ratio              |
| `ortho`          | `boolean`     | Whether the view is orthographic  |
| `orthoLeft`      | `number`      | Ortho view left boundary          |
| `orthoTop`       | `number`      | Ortho view top boundary           |
| `orthoRight`     | `number`      | Ortho view right boundary         |
| `orthoBottom`    | `number`      | Ortho view bottom boundary        |

### Curated Usage Examples

#### Get current camera state

```lua
local view = client.GetPlayerView()
if not view then return end

local camOrigin = view.origin
local camAngles = view.angles
local currentFov = view.fov

print("Camera at: " .. tostring(camOrigin))
print("Looking: " .. tostring(camAngles))
print("FOV: " .. currentFov)
```

#### Compute aspect ratio for FOV math

```lua
local view = client.GetPlayerView()
if not view then return end

local screenW = view.width
local screenH = view.height
local aspect  = screenW / screenH
```

#### Use with WorldToScreen bounds checking

```lua
local view = client.GetPlayerView()
if not view then return end

local function IsOnScreen(screenPos)
    local isInX = screenPos.x >= 0 and screenPos.x <= view.width
    local isInY = screenPos.y >= 0 and screenPos.y <= view.height
    return isInX and isInY
end
```

### Notes

- `client.GetPlayerView()` returns `nil` if called outside a valid render context (e.g. at init time)
- `origin` and `angles` reflect the **camera**, not the player's GetEyePos — they may differ under demo playback or spectator
- `unscaled*` variants reflect the true pixel dimensions ignoring any UI scaling options
