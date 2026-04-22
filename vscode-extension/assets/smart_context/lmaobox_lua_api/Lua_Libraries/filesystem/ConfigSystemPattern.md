## Pattern: Custom Config Save/Load System

> Persistent config storage for Lua scripts

### Required Context

- Functions: filesystem.CreateDirectory, io.open, load, pcall
- Pattern: Serialize tables to files, validate on load

### Curated Usage Examples

#### Config path builder

```lua
local function GetConfigPath(folder_name)
    folder_name = folder_name or "Lua MyScript"
    local _, fullPath = filesystem.CreateDirectory(folder_name)
    local sep = package.config:sub(1, 1)
    return fullPath .. sep .. "config.cfg"
end
```

#### Table serializer

```lua
local function serializeTable(tbl, level)
    level = level or 0
    local indent = string.rep("    ", level)
    local out = indent .. "{\n"
    for k, v in pairs(tbl) do
        local keyRepr = (type(k) == "string") and string.format("[\"%s\"]", k) or string.format("[%s]", k)
        out = out .. indent .. "    " .. keyRepr .. " = "
        if type(v) == "table" then
            out = out .. serializeTable(v, level + 1) .. ",\n"
        elseif type(v) == "string" then
            out = out .. string.format("\"%s\",\n", v)
        else
            out = out .. tostring(v) .. ",\n"
        end
    end
    out = out .. indent .. "}"
    return out
end
```

#### Save config

```lua
local function SaveCFG(cfg, folder_name)
    local path = GetConfigPath(folder_name)
    local f = io.open(path, "w")
    if not f then return false end
    f:write(serializeTable(cfg))
    f:close()
    return true
end
```

#### Load config with validation

```lua
local function LoadCFG(defaults, folder_name)
    local path = GetConfigPath(folder_name)
    local f = io.open(path, "r")
    if not f then
        SaveCFG(defaults, folder_name)
        return defaults
    end

    local content = f:read("*a")
    f:close()

    local chunk, err = load("return " .. content)
    if not chunk then
        print("Config compile error, regenerating")
        SaveCFG(defaults, folder_name)
        return defaults
    end

    local ok, cfg = pcall(chunk)

    -- Optional: hold SHIFT to force-reset config (useful during development)
    local shiftHeld = input.IsButtonDown(KEY_LSHIFT)

    if not ok or type(cfg) ~= "table" or not keysMatch(defaults, cfg) or shiftHeld then
        if shiftHeld then
            printc(255, 200, 100, 255, "[Config] SHIFT held – resetting to defaults")
        else
            printc(255, 100, 100, 255, "[Config] Outdated/invalid config – regenerating")
        end
        SaveCFG(defaults, folder_name)
        return defaults
    end

    return cfg
end
```

#### Deep copy (for defaults — avoids mutating them)

```lua
local function deepCopy(orig)
    if type(orig) ~= "table" then return orig end
    local copy = {}
    for k, v in pairs(orig) do
        copy[k] = deepCopy(v)
    end
    return copy
end
```

#### Key validation (detects added settings in newer versions)

```lua
-- Returns false if any key from `template` is missing in `loaded`
local function keysMatch(template, loaded)
    for k, v in pairs(template) do
        if loaded[k] == nil then return false end
        if type(v) == "table" and type(loaded[k]) == "table" then
            if not keysMatch(v, loaded[k]) then return false end
        end
    end
    return true
end
```

#### Full example

```lua
local Default_Config = {
    Main    = { Active = true, Keybind = KEY_B },
    Aimbot  = { Enabled = true, FOV = 360, Silent = true },
    Visuals = { Enabled = false },
}

-- Derive folder name from script filename
local scriptName = GetScriptName():match("([^/\\]+)%.lua$"):gsub("%.lua$", "")
local FOLDER     = string.format("Lua %s", scriptName)

-- Load at startup
local Menu = LoadCFG(deepCopy(Default_Config), FOLDER)

-- Save on unload
callbacks.Unregister("Unload", "save_config")
callbacks.Register("Unload", "save_config", function()
    SaveCFG(Menu, FOLDER)
end)
```

### Notes

- `filesystem.CreateDirectory` creates the folder and returns the writable `fullPath` — use that with `io.open`
- There is **no** `filesystem.WriteFile` or `filesystem.ReadFile` in lmaobox
- `load("return " .. content)` deserializes serialized table back to a Lua table
- `keysMatch` detects when a config is missing keys from new defaults; regenerates instead of crashing
- `deepCopy` prevents mutations to the `Default_Config` table when using it as a fallback
- SHIFT-held reset is optional but very useful for testing/development
