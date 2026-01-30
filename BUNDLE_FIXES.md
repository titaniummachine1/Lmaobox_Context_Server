# Bundle Tool Fixes - January 30, 2026

## Issue 1: Bundle Tool Not Blocking (FIXED)

**Problem:** Bundle tool was non-blocking, causing AI to spawn multiple bundle requests.

**Solution:** Changed bundle tool to BLOCK with 15-second HARD timeout enforced at multiple checkpoints.

### Changes:

- Timeout: **15 seconds HARD LIMIT** (line 130 in main.go)
- Operation now **BLOCKS** - AI must wait for completion or timeout
- **Aggressive timeout enforcement** - context checked at:
  - Start of bundling
  - After syntax validation
  - After dependency analysis
  - After bundle generation
  - Start of each recursive dependency resolution
  - Inside validation loops
  - Inside dependency resolution loops
- Clear error messaging when timeout occurs:

  ```
  BUNDLE TIMEOUT (15s exceeded)

  Likely causes:
  1. Circular dependency in require() statements
  2. Very large project
  3. Invalid require() paths

  DO NOT retry immediately. Fix the issue first:
  - Check for circular dependencies (A requires B, B requires A)
  - Verify all require() paths exist
  - Split large modules into smaller files
  ```

### Tool Description (for AI):

```
Bundle and deploy Lua to %LOCALAPPDATA%/lua.
BLOCKS for up to 15 seconds.
If timeout occurs, DO NOT retry until you fix the underlying issue
(circular deps, missing files, etc).
After fixing issues, you SHOULD retry bundling.
```

### AI Guidance:

- Tool will **BLOCK for up to 15 seconds MAXIMUM**
- Timeout is enforced at multiple checkpoints - cannot hang indefinitely
- After 15s, returns clear failure message
- AI should **NOT retry** without fixing the underlying issue
- **After fixing issues, AI SHOULD retry** - this is the key clarification
- Error message explicitly tells AI not to retry immediately

---

## Issue 2: Bundled Error Tracing (FIXED)

**Problem:** Runtime errors in bundled files show line numbers from bundled file, impossible to trace back to source.

Example error:

```
C:\Users\...\AppData\Local\lua\simtest.lua:1514: attempt to index a nil value (local 'simCtx')
```

Line 1514 is in the bundled file, but which source module is it from?

**Solution:** Added `trace_bundle_error` MCP tool to map bundled errors back to source files.

### New Tool: `trace_bundle_error`

**Parameters:**

- `bundledFilePath` (string, required): Path to bundled file (e.g., `C:/Users/.../AppData/Local/lua/Main.lua`)
- `errorLine` (number, required): Line number from error message

**Usage Example:**

```javascript
mcp.trace_bundle_error({
  bundledFilePath: "C:/Users/Terminatort8000/AppData/Local/lua/simtest.lua",
  errorLine: 1514,
});
```

**Output Format:**

```
=== ERROR TRACE ===

Bundled file: C:/Users/.../lua/simtest.lua
Error at line: 1514

Module: simulation.Player.player_tick
Module starts at line: 1200
Module ends at line: 1600
Relative line in module: ~314

This is in module: simulation.Player.player_tick
Likely source file: simulation/Player/player_tick.lua

=== CODE CONTEXT ===

    1509: ---@param playerCtx PlayerContext
    1510: ---@param simCtx SimulationContext
    1511: ---@return Vector3 newOrigin
    1512: function PlayerTick.simulateTick(playerCtx, simCtx)
    1513:     local tickinterval = simCtx.tickinterval
>>>  1514:     local yawDelta = playerCtx.yawDeltaPerTick or 0
    1515:
    1516:     -- Phase 1: Friction
    1517:     local is_on_ground =
    1518:         checkIsOnGround(playerCtx.origin, playerCtx.velocity, playerCtx.mins, playerCtx.maxs, playerCtx.index)
    1519:     if is_on_ground and playerCtx.velocity.z < 0 then
```

### How It Works:

1. Parses bundled file to find `__bundle_register()` boundaries
2. Maps error line to specific module
3. Shows module name and likely source file path
4. Displays code context around error line
5. Calculates relative line number within module

### Special Cases:

- `__root` module = Main.lua (entry file)
- Lines outside modules = bundle loader infrastructure
- Shows +/- 5 lines of context around error

---

## Deployment

### Steps to Apply:

1. **Rebuild binary** (already done):

   ```bash
   cd C:\Users\Terminatort8000\Desktop\Lmaobox_Context_Server
   go build -o lmaobox-context-server.exe main.go
   ```

2. **Restart MCP server**:
   - Close Windsurf/Cascade
   - Reopen Windsurf/Cascade
   - MCP server will auto-start with new binary

3. **Verify tools available**:
   - `bundle` - should now block with 15s timeout
   - `trace_bundle_error` - new tool for error tracing

### Testing trace_bundle_error:

When you get an error like:

```
C:\Users\...\lua\simtest.lua:1514: attempt to index a nil value (local 'simCtx')
```

Use the tool:

```
trace_bundle_error({
  bundledFilePath: "C:/Users/Terminatort8000/AppData/Local/lua/simtest.lua",
  errorLine: 1514
})
```

It will tell you:

- Which source module contains the error
- Likely source file path
- Code context with the actual error line highlighted

---

## Summary

✅ **Bundle tool now blocks** - prevents AI from spawning duplicate requests  
✅ **15-second timeout** - reasonable for most projects  
✅ **Clear timeout messaging** - tells AI not to retry without fixing issue  
✅ **Error tracer tool** - maps bundled errors to source files instantly

Both issues resolved.
