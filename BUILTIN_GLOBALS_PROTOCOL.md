# Lmaobox Built-In Globals Protocol

## Overview

Lmaobox exposes certain globals (`http`, `entities`, `callbacks`, `engine`, `draw`, etc.) as special userdata/function objects that **do NOT respond to standard Lua validation patterns**. This protocol enforces safe patterns by forbidding dangerous validation checks and requiring direct `pcall()` wrapping for all built-in function calls.

## The Problem

Attempting to validate Lmaobox built-in globals with standard Lua patterns causes silent failures or crashes:

```lua
-- ❌ FORBIDDEN: These all fail silently (object exists but doesn't validate)
if http then end                      -- always false, misleading
if entities ~= nil then end           -- always false, misleading
if type(callbacks) == "userdata" then end  -- always false, misleading

-- ❌ FORBIDDEN: Indirection doesn't help
if globals.http then end              -- still won't work
local http_copy = http                -- creates invalid reference

-- ❌ FORBIDDEN: Fallback patterns crash at runtime
local client = http or fallback       -- crashes when http.Get() is called
```

## The Solution

Always use direct `pcall()` wrapping. The runtime will raise an error if the function is truly unavailable (e.g., in free-run context without HTTP API):

```lua
-- ✅ CORRECT: Direct pcall() wrapping
local function SafeHttpGet(url)
    return pcall(function()
        return http.Get(url)
    end)
end

-- Usage:
local ok, result = SafeHttpGet("https://example.com")
if ok then
    print("Success:", result)
else
    print("Error:", result)
end
```

## Validation Rules

The MCP tool and bundle validation now enforce:

### 1. Forbidden: `if`/`while`/`until` checks
```lua
-- ❌ FORBIDDEN
if http then
    http.Get(url)
end

-- ✅ CORRECT
if pcall(function() http.Get(url) end) then
    -- ...
end
```

### 2. Forbidden: nil comparisons
```lua
-- ❌ FORBIDDEN
if entities == nil then return end
if callbacks ~= nil then ... end

-- ✅ CORRECT
return pcall(function() entities.GetLocalPlayer() end)
```

### 3. Forbidden: type() checks
```lua
-- ❌ FORBIDDEN
if type(draw) == "userdata" then ... end

-- ✅ CORRECT
if pcall(function() draw.Color(255, 0, 0, 255) end) then
    -- ...
end
```

### 4. Forbidden: globals.X access (indirect)
```lua
-- ❌ FORBIDDEN
if globals.http then ... end

-- ✅ CORRECT (if you must store reference)
local http_fn = function(url)
    return pcall(http.Get, url)
end
```

## Known Lmaobox Built-In Globals

The following globals require direct `pcall()` wrapping:

- `http` – HTTP client
- `entities` – Entity/player access
- `callbacks` – Event system (note: `callbacks.Register` is a special case with other rules)
- `engine` – Game engine API
- `draw` – Drawing/rendering
- `input` – Input handling
- `profiler` – Profiling tools
- `warp` – Warp/strafe triggers

## MCP Tool Integration

When using the MCP tool (`luacheck`, `bundle`, etc.), the validation automatically:

1. **Detects** any use of forbidden patterns
2. **Reports** the violation with line number and explanation
3. **Blocks** bundling if violations are found

Example violation message:
```
CRITICAL: Lmaobox built-in 'http' must NOT be validated with 'if' checks — use direct pcall() instead.
Pattern: pcall(function() ... http.SomeCall(...) ... end)
```

## Configuration

### .luacheckrc Setup

Create or copy `.luacheckrc.example` to `.luacheckrc` and add:

```lua
globals = {
    "http", "entities", "callbacks", "engine", "draw", "input",
    "profiler", "warp", "globals"
}
```

This suppresses false "undefined global" warnings while MCP enforces the protocol.

### Bundling

When bundling Lua code:

```bash
mcp_lmaobox_conte_bundle --projectDir=/path/to/project
```

The bundle tool will:
1. Run syntax check
2. Run **Lmaobox Built-In Globals Protocol** validation
3. Reject the bundle if violations are found
4. Deploy only if all checks pass

## Common Patterns

### Safe HTTP Request
```lua
-- ✅ CORRECT: Wrapped in pcall with error handling
local function FetchData(url)
    local ok, result = pcall(function()
        return http.Get(url)
    end)
    
    if not ok then
        print("HTTP request failed:", result)
        return nil
    end
    return result
end
```

### Safe Entity Access
```lua
-- ✅ CORRECT: Direct call in pcall
local function GetMyPlayer()
    local ok, player = pcall(function()
        return entities.GetLocalPlayer()
    end)
    
    if not ok or not player then
        return nil
    end
    return player
end
```

### Safe Draw Call
```lua
-- ✅ CORRECT: Set state and draw in same callback
function OnDraw()
    draw.Color(255, 0, 0, 255)
    draw.FilledRect(10, 10, 50, 50)
end
```

### Storing References
```lua
-- ✅ CORRECT: Store wrapper function, not the reference itself
local GetPlayer = function()
    return pcall(entities.GetLocalPlayer)
end

-- Usage:
local ok, player = GetPlayer()
```

## Migration Guide

If you have existing code with forbidden patterns:

**Before:**
```lua
if entities then
    local player = entities.GetLocalPlayer()
    if player then
        print(player:GetHealth())
    end
end
```

**After:**
```lua
local ok, player = pcall(entities.GetLocalPlayer)
if ok and player then
    print(player:GetHealth())
end
```

## Testing

The validation includes comprehensive test coverage:

```bash
go test -run TestBuiltin ./...
```

This runs all tests related to the Lmaobox Built-In Globals Protocol validation.

## FAQ

### Q: Can I test if a global exists?
**A:** No. Use `pcall()` and let it fail gracefully if unavailable.

### Q: Why not just use `type()`?
**A:** Lmaobox built-ins don't respond to `type()`. They appear as neither "userdata" nor "function" to Lua's type system.

### Q: Can I assign a built-in to a variable?
**A:** Only if you wrap calls to it in `pcall()`. Direct references won't work.

### Q: What if the API call truly fails?
**A:** The `pcall()` will return `false, error_message`. Check the first return value.

### Q: Does this apply to Lua standard library (math, table, string)?
**A:** No, only Lmaobox-specific built-ins. Standard library validation is normal.

## References

- **MCP Documentation:** See `mcp_lmaobox_conte_luacheck` and `mcp_lmaobox_conte_bundle`
- **Bundle Tool:** See [BUNDLE_TOOL_FIX.md](./BUNDLE_TOOL_FIX.md)
- **Zero-Mutation Policy:** See [lua_policy.go](./lua_policy.go)
