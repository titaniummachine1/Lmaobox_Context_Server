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
    if not ok or type(cfg) ~= "table" then
        print("Invalid config, regenerating")
        SaveCFG(defaults, folder_name)
        return defaults
    end

    return cfg
end
```

#### Full example

```lua
local Menu = {
    Aimbot = true,
    FOV = 360,
    Silent = true,
}

-- Load at startup
local cfg = LoadCFG(Menu, "Lua MyScript")
if cfg then Menu = cfg end

-- Save on unload
callbacks.Register("Unload", "save_config", function()
    SaveCFG(Menu, "Lua MyScript")
end)
```

### Notes

- Store in filesystem.CreateDirectory result path
- Validate structure on load; regenerate if outdated
- Hold LSHIFT during load to force reset (optional check)
