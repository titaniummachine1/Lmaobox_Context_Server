## Pattern: Config Persistence via io.open

> Lmaobox scripts run sandboxed to the TF2 directory (same as `GetScriptPath()` context).
> Standard `io.open` works for reading and writing within the TF2 folder.
> There is no `filesystem.WriteFile` — `io.open` is the correct API.

### Sandbox Rules

- Scripts can **read and write** files inside the TF2 installation directory
- Scripts **cannot** access paths outside TF2 (no `C:\Users\...`, no `%APPDATA%\...`)
- Lua scripts load from `%localappdata%\Lmaobox\scripts\` (or similar) and that path is accessible
- Config files created with `io.open` will appear relative to the working directory TF2 was launched from, or at an absolute path you specify inside TF2

### Save/Load a Flat Key=Value Config

```lua
-- Config file lives next to scripts or at a known TF2-relative path
local CONFIG_PATH = "lmaobox_myscript_config.txt"

local function SaveConfig(cfg)
    local file = io.open(CONFIG_PATH, "w")
    if not file then
        print("[Config] Could not open config for writing: " .. CONFIG_PATH)
        return false
    end

    file:write(string.format("enabled=%s\n",      tostring(cfg.enabled)))
    file:write(string.format("fov=%d\n",          cfg.fov))
    file:write(string.format("color_r=%d\n",      cfg.color.r))
    file:write(string.format("color_g=%d\n",      cfg.color.g))
    file:write(string.format("color_b=%d\n",      cfg.color.b))
    file:write(string.format("aim_key=%d\n",      cfg.aimKey))

    file:close()
    return true
end

local function LoadConfig()
    local file = io.open(CONFIG_PATH, "r")
    if not file then
        print("[Config] No config found, using defaults")
        return nil
    end

    local cfg = {}
    for line in file:lines() do
        local key, value = line:match("([^=]+)=(.+)")
        if key and value then
            cfg[key] = value
        end
    end
    file:close()

    return {
        enabled = cfg.enabled == "true",
        fov     = tonumber(cfg.fov)     or 30,
        color   = {
            r = tonumber(cfg.color_r) or 255,
            g = tonumber(cfg.color_g) or 100,
            b = tonumber(cfg.color_b) or 100,
        },
        aimKey  = tonumber(cfg.aim_key) or 0,
    }
end
```

### Auto-Save Pattern (every N seconds)

```lua
local lastSaveTime = 0
local SAVE_INTERVAL = 5.0  -- seconds

local function MaybeSave(config)
    local now = globals.RealTime()
    local timeSinceSave = now - lastSaveTime
    if timeSinceSave < SAVE_INTERVAL then return end
    SaveConfig(config)
    lastSaveTime = now
end

-- In Draw callback:
callbacks.Register("Draw", "config_autosave", function()
    MaybeSave(myConfig)
end)
```

### Init (try load, fall back to defaults)

```lua
local DEFAULT_CONFIG = {
    enabled = true,
    fov     = 30,
    color   = { r = 255, g = 100, b = 100 },
    aimKey  = 0,
}

local myConfig = LoadConfig() or DEFAULT_CONFIG

callbacks.Register("Unload", "save_on_unload", function()
    SaveConfig(myConfig)
end)
```

### Storing/Loading Numeric Arrays

```lua
-- Write an array as comma-separated
local function WriteArray(file, key, arr)
    local parts = {}
    for i, v in ipairs(arr) do
        parts[i] = tostring(v)
    end
    file:write(key .. "=" .. table.concat(parts, ",") .. "\n")
end

-- Read it back
local function ParseArray(str)
    local result = {}
    for v in str:gmatch("[^,]+") do
        result[#result + 1] = tonumber(v)
    end
    return result
end
```

### Notes

- `io.open` returns `nil` if the file does not exist — always nil-check before using
- `file:close()` is mandatory — unclosed handles leak until gc
- Do NOT use `collectgarbage()` to force-close files — just call `file:close()`
- There is **no** `filesystem.WriteFile` or `filesystem.ReadFile` in lmaobox
- `filesystem.CreateDirectory` exists for creating directories but NOT for file I/O
- Writing a config in `Unload` callback ensures settings survive script restarts
- For large configs, prefer a structured format (JSON-like) but hand-rolled for simplicity
