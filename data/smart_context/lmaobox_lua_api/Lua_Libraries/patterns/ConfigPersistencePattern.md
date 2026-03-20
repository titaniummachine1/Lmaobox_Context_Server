## Pattern: Config Persistence via io.open

> Lmaobox uses `io.open` for file I/O. There is no `filesystem.WriteFile` or `filesystem.ReadFile`.
> Use `filesystem.CreateDirectory` to create a folder and get a **guaranteed writable absolute path**,
> then use `io.open` with that path to read/write files.

### Sandbox Rules

- `filesystem.CreateDirectory(folder_name)` returns `success, fullPath` — `fullPath` is inside TF2's writable data dir
- `io.open(fullPath .. "/config.cfg", "w")` writes there safely
- Scripts **cannot** access arbitrary paths like `C:\Users\...` or `%APPDATA%\...`
- Config files from `GetScriptName()` match the known game working directory; use `filesystem.CreateDirectory` for portable path resolution

### Correct Config Path Pattern

```lua
-- Derive folder name from script filename (portable)
local Lua__fullPath = GetScriptName()
local Lua__fileName = Lua__fullPath:match("([^/\\]+)%.lua$"):gsub("%.lua$", "")
local FOLDER_NAME   = string.format("Lua %s", Lua__fileName)

local function GetConfigPath()
    local _, fullPath = filesystem.CreateDirectory(FOLDER_NAME)
    local sep = package.config:sub(1, 1)   -- "/" on Linux, "\" on Windows
    return fullPath .. sep .. "config.cfg"
end
```

### Table Serializer (recursive, supports nested tables)

```lua
-- Produces valid Lua table literal that can be deserialized with load()
local function serializeTable(tbl, level)
    level = level or 0
    local indent      = string.rep("    ", level)
    local innerIndent = indent .. "    "
    local entries = {}
    for k, v in pairs(tbl) do
        local safeKey = tostring(k):gsub('\\', '\\\\'):gsub('"', '\\"')
        local keyRepr = (type(k) == "string") and ('["' .. safeKey .. '"]') or ('[' .. safeKey .. ']')
        local valRepr
        if type(v) == "table" then
            valRepr = serializeTable(v, level + 1)
        elseif type(v) == "string" then
            local s = v:gsub('[^%z\32-\126]', ''):sub(1, 128)
            s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n')
            valRepr = '"' .. s .. '"'
        else
            valRepr = tostring(v)
        end
        table.insert(entries, innerIndent .. keyRepr .. " = " .. valRepr)
    end
    if #entries == 0 then return "{}" end
    return "{\n" .. table.concat(entries, ",\n") .. "\n" .. indent .. "}"
end
```

### Save

```lua
local function CreateCFG(cfg)
    local path = GetConfigPath()
    local file = io.open(path, "w")
    if not file then
        printc(255, 0, 0, 255, "[Config] Failed to write: " .. path)
        return false
    end
    file:write(serializeTable(cfg))
    file:close()
    printc(100, 183, 0, 255, "[Config] Saved: " .. path)
    return true
end
```

### Load with validation (regenerate if corrupt/outdated)

```lua
-- Check that all keys from template exist in loaded config (handles added settings)
local function keysMatch(template, loaded)
    for k, v in pairs(template) do
        if loaded[k] == nil then return false end
        if type(v) == "table" and type(loaded[k]) == "table" then
            if not keysMatch(v, loaded[k]) then return false end
        end
    end
    return true
end

local function LoadCFG(defaults)
    local path = GetConfigPath()
    local file = io.open(path, "r")
    if not file then
        -- First run: write defaults
        CreateCFG(defaults)
        return defaults
    end
    local content = file:read("*a")
    file:close()

    local chunk, err = load("return " .. content)
    if not chunk then
        printc(255, 100, 100, 255, "[Config] Compile error, regenerating: " .. tostring(err))
        CreateCFG(defaults)
        return defaults
    end

    local ok, cfg = pcall(chunk)

    -- Optional: SHIFT held forces reset (useful during development)
    local shiftHeld = input.IsButtonDown(KEY_LSHIFT)

    if not ok or type(cfg) ~= "table" or not keysMatch(defaults, cfg) or shiftHeld then
        if shiftHeld then
            printc(255, 200, 100, 255, "[Config] SHIFT held – resetting to defaults")
        else
            printc(255, 100, 100, 255, "[Config] Outdated/invalid config – regenerating")
        end
        CreateCFG(defaults)
        return defaults
    end

    printc(0, 255, 140, 255, "[Config] Loaded: " .. path)
    return cfg
end
```

### Full bootstrap pattern

```lua
local Default_Config = {
    Main = {
        Active  = true,
        Keybind = KEY_B,
    },
    Aimbot = {
        Enabled    = true,
        FOV        = 360,
        Silent     = true,
        MaxDist    = 1000,
    },
    Visuals = {
        Enabled = false,
    },
}

-- Load (or reset to defaults) at startup
local Menu = LoadCFG(Default_Config)

-- Save on unload
callbacks.Unregister("Unload", "Config_Unload")
callbacks.Register("Unload", "Config_Unload", function()
    CreateCFG(Menu)
end)
```

### Notes

- `io.open` returns `nil` if the file does not exist — always nil-check
- `file:close()` is mandatory; unclosed file handles leak
- Do NOT use `collectgarbage()` — call `file:close()` explicitly
- There is **no** `filesystem.WriteFile` or `filesystem.ReadFile` in lmaobox
- `filesystem.CreateDirectory` gives you the correct writable path to pass to `io.open`
- Deserialization uses `load("return " .. content)` — serialized content must be a valid Lua table literal
- `keysMatch` catches configs with missing keys from new defaults; regenerates cleanly instead of erroring at runtime
