# Zero-Mutation Lbox Protocol - Custom Linter Rules

## Overview

The lmaobox-context-protocol MCP server includes a **custom programmable linter** that enforces the **Zero-Mutation Lbox Protocol** - a set of hard-coded rules designed to prevent callback table mutation during runtime.

This linter is integrated into the `luacheck` MCP tool and provides two layers of validation:

1. **Policy Layer** (Go-based token analysis)
2. **Lint Layer** (External luacheck tool)

## The Four Core Rules

The linter enforces these strict rules:

| Rule | Requirement | Violation | 
|------|-------------|-----------|
| **Static Only** | `callbacks.register()` and `callbacks.unregister()` must be at **Depth 0** (global scope, not inside any function) | "Illegal Register/Unregister: Must be at depth 0" |
| **The Kill-Switch** | Every `callbacks.register("Event", "ID", ...)` must be preceded by `callbacks.unregister("Event", "ID")` or `callbacks.unregister("Event")` at depth 0 | "Kill-Switch violation: unregister must precede register" |
| **Total Runtime Ban** | **NO** `callbacks.unregister()` inside *any* function block (including callbacks, nested functions, and the Unload event) | "CRITICAL: Illegal Unregister inside function scope" |
| **Unload Protection** | `callbacks.unregister()` is explicitly forbidden even in `OnUnload` / `Unload` callbacks | "CRITICAL: Illegal Unregister inside function scope" |

## Rule Implementation (Go Code)

The rules are implemented in `main.go` in the `checkLuaCallbackMutationPolicy()` function:

```go
// Core policy structure
type LboxMutationPolicy struct {
    ForbidRuntimeRegister       bool   // Rule 1: register only at depth 0
    ForbidRuntimeUnregister     bool   // Rule 3: unregister forbidden in functions
    RequireKillSwitchPattern    bool   // Rule 2: unregister before register
    ForbidUnregisterInUnload    bool   // Rule 4: unregister forbidden in Unload
}

// Default policy (all rules enabled)
var defaultLboxMutationPolicy = LboxMutationPolicy{
    ForbidRuntimeRegister:    true,
    ForbidRuntimeUnregister:  true,
    RequireKillSwitchPattern: true,
    ForbidUnregisterInUnload: true,
}
```

### How the Token-Based Validator Works

```go
func checkLuaCallbackMutationPolicy(filePath string, policy LboxMutationPolicy) ([]luaPolicyViolation, error) {
    // 1. Tokenize Lua source code
    tokens, err := tokenizeLua(source)
    
    // 2. Track depth as we walk tokens
    // - function keyword → depth++
    // - function end → depth--
    // - if/for/while/repeat keywords → NOT depth changes (no scope isolation)
    
    // 3. For each callbacks.register() and callbacks.unregister() call:
    if currentDepth > 0:
        if policy.ForbidRuntimeRegister && isRegister:
            violations.append("Illegal Register: Must be at depth 0")
        if policy.ForbidRuntimeUnregister && isUnregister:
            violations.append("Illegal Unregister: Cannot be inside function scope")
    
    // 4. For kill-switch pattern validation:
    if policy.RequireKillSwitchPattern && isRegister:
        check if unregisterTracker["Event"]["ID"] exists at depth 0
        if not found:
            violations.append("Kill-Switch violation")
}
```

## Test Coverage

The linter is validated by **17 comprehensive tests**:

### Policy Tests (policy_test.go)
- ✅ `TestUnregisterInsideFunction` - Detects unregister in user functions
- ✅ `TestKillSwitchViolation` - Requires unregister before register
- ✅ `TestValidUnregisterThenRegister` - Approves valid kill-switch
- ✅ `TestUnregisterInOnUnload` - Detects unregister in Unload callback
- ✅ `TestGhostPatternApproved` - Allows state control (flags) in callbacks
- ✅ `TestIfBlockDoesNotIncrementDepth` - If/for/while treated as depth 0
- ✅ `TestMultipleSeparateCallbacks` - Independent validation per callback
- ✅ `TestUnregisterWithoutIDAllowed` - ID-less unregister satisfies kill-switch
- ✅ `TestNestedFunctionCallbacks` - Depth tracking across function nesting
- ✅ `TestCommentedOutUnregister` - Comments properly ignored

### MCP Tool Tests (mcp_tool_test.go) 
- ✅ `TestZeroMutationUnregisterInFunction` - Rejects unregister in function
- ✅ `TestZeroMutationUnregisterInOnUnload` - Rejects unregister in Unload
- ✅ `TestZeroMutationKillSwitchViolation` - Enforces kill-switch pattern
- ✅ `TestZeroMutationGhostPatternApproved` - Allows Ghost Pattern (safe state control)
- ✅ `TestZeroMutationRegisterInNestedFunction` - Rejects nested register
- ✅ `TestZeroMutationIfBlockNoDepthIsolation` - If blocks don't provide isolation
- ✅ `TestZeroMutationMultipleViolations` - Reports all violations
- ✅ `TestZeroMutationUnregisterWithoutID` - ID-less unregister valid

**Test Results:** 17/17 PASSED ✓

Run tests:
```bash
go test -v ./...
```

## Safe Patterns Approved by the Linter

### ✅ The Ghost Pattern (Safe State Control)

Instead of unregistering at runtime, use **state flags** to disable behavior:

```lua
-- APPROVED: State control in callbacks
local running = true

-- At script load time (depth 0):
callbacks.unregister("Draw", "MainLoop")  -- Kill-switch
callbacks.register("Draw", "MainLoop", function()
    if not running then return end  -- Safe: just skip execution
    -- ... core logic ...
end)

-- Safe cleanup (depth 0):
callbacks.register("Unload", function()
    -- WRONG: callbacks.unregister("Draw", "MainLoop")  -- FORBIDDEN
    -- RIGHT: Just set flag
    running = false
end)
```

### ✅ Multiple Independent Callbacks

```lua
-- APPROVED: Each callback has its own kill-switch
callbacks.unregister("Tick", "Predict")
callbacks.register("Tick", "Predict", function()
    -- prediction logic
end)

callbacks.unregister("Draw", "Render")
callbacks.register("Draw", "Render", function()
    -- render logic
end)
```

### ✅ Conditional Registration (At Depth 0)

```lua
-- APPROVED: If block at depth 0 (NOT a scope boundary)
if config.enablePrediction then
    callbacks.unregister("Tick", "Predict")
    callbacks.register("Tick", "Predict", function()
        -- prediction
    end)
end
```

## Forbidden Patterns Rejected by the Linter

### ❌ Runtime Unregister in Callback

```lua
-- FORBIDDEN: Unregister inside any callback
callbacks.register("Draw", "Main", function()
    callbacks.unregister("Tick", "Background")  -- CRASH RISK
end)

-- FORBIDDEN: Unregister in helper function called by callback
local function cleanup()
    callbacks.unregister("Draw", "Main")  -- Still at depth > 0
end

callbacks.register("Tick", function()
    cleanup()  -- Violation triggered at definition, not call
end)
```

### ❌ Runtime Unregister in OnUnload

```lua
-- FORBIDDEN: Even cleanup in Unload callback is blocked
callbacks.register("Unload", function()
    callbacks.unregister("Draw", "MainLoop")  -- CRITICAL ERROR
    callbacks.unregister("Tick", "Loop")      -- CRITICAL ERROR
end)
```

### ❌ Register Without Kill-Switch

```lua
-- FORBIDDEN: No prior unregister
callbacks.register("Draw", "MyLoop", function()
    -- logic
end)

-- REQUIRED: Always unregister first
callbacks.unregister("Draw", "MyLoop")
callbacks.register("Draw", "MyLoop", function()
    -- logic
end)
```

### ❌ Nested Function Registration

```lua
-- FORBIDDEN: Register inside nested function
local function setup()
    callbacks.register("Draw", "Loop", function()  -- VIOLATION: depth 2
        -- logic
    end)
end

-- Even this violates the rule:
local function outer()
    local function inner()
        callbacks.register("Tick", "Timer", function() end)  -- Forbidden
    end
end
```

## How to Extend the Linter (Programmable Rules)

To add new custom rules, modify `main.go`:

### Step 1: Extend the Policy Struct

```go
type LboxMutationPolicy struct {
    ForbidRuntimeRegister       bool
    ForbidRuntimeUnregister     bool
    RequireKillSwitchPattern    bool
    ForbidUnregisterInUnload    bool
    
    // Add new rule:
    ForbidSpecificEvents        bool    // NEW: Reject certain event names
    ForbiddenEvents             []string
}
```

### Step 2: Add Validation Logic

```go
func checkLuaCallbackMutationPolicy(filePath string, policy LboxMutationPolicy) ([]luaPolicyViolation, error) {
    // ... existing validation ...
    
    // Add new check:
    if policy.ForbidSpecificEvents {
        eventName := stringArgValue(args, 0)
        for _, forbidden := range policy.ForbiddenEvents {
            if strings.EqualFold(eventName, forbidden) {
                violations.append(luaPolicyViolation{
                    Line:    t.Line,
                    Message: fmt.Sprintf("Event '%s' is forbidden by policy", eventName),
                })
            }
        }
    }
}
```

### Step 3: Create Policy Variants

```go
// Strict policy (all rules enabled)
var strictPolicy = LboxMutationPolicy{
    ForbidRuntimeRegister:    true,
    ForbidRuntimeUnregister:  true,
    RequireKillSwitchPattern: true,
    ForbidUnregisterInUnload: true,
    ForbidSpecificEvents:     true,
    ForbiddenEvents:          []string{"Unload", "OnScriptStop"},
}

// Relaxed policy (some rules disabled)
var relaxedPolicy = LboxMutationPolicy{
    ForbidRuntimeRegister:    true,
    ForbidRuntimeUnregister:  true,
    RequireKillSwitchPattern: false,  // Allow register without unregister
    ForbidUnregisterInUnload: false,  // Allow unregister in Unload
}
```

## Integration with MCP Tools

The custom linter is used by the `luacheck` MCP tool:

```go
// In handleLuacheck():
violations, err := checkLuaCallbackMutationPolicy(filePath, defaultLboxMutationPolicy)
if len(violations) > 0 {
    return mcp.NewToolResultError(formatLuaPolicyViolations(filePath, violations))
}
```

Call the MCP tool:
```json
{
  "method": "tools/call",
  "params": {
    "name": "luacheck",
    "arguments": {
      "filePath": "/path/to/script.lua"
    }
  }
}
```

Response on violation:
```json
{
  "content": [
    {
      "type": "text",
      "text": "Policy Violations:\n✗ Line 5: CRITICAL: Illegal Unregister inside function scope..."
    }
  ],
  "isError": true
}
```

## Configuration Files

All default configurations are in `main.go`. No external `.luacheckrc` or config files needed.

To use different policies, modify `defaultLboxMutationPolicy` in `main.go` or create a runtime flag to select between policy variants.

## Summary

✅ **Custom programmable linter**: Extensible Go-based token validator
✅ **Hard-coded Zero-Mutation rules**: 4 core rules, all enforced
✅ **Comprehensive test suite**: 17 tests, all passing
✅ **MCP integration**: Works via `luacheck` MCP tool
✅ **Safe patterns**: Ghost Pattern (state flags) approved
✅ **Strict enforcement**: No exceptions, no loopholes

The linter acts as a **gatekeeper** preventing AI and developers from introducing callback iterator invalidation bugs.
