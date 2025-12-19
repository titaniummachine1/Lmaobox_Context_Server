# Bundle Tool Timeout Fix

## Problem

The MCP `bundle` tool would hang indefinitely when called by AI models, causing the entire MCP server to become unresponsive.

## Root Cause

`subprocess.run()` in `mcp_stdio.py:148-155` had **no timeout parameter**:

```python
process = subprocess.run(
    ["node", str(script_path)],
    cwd=str(mcp_server_root),
    env=env,
    capture_output=True,
    text=True,
    check=False,
    # ❌ Missing timeout parameter!
)
```

If the Node.js bundler script hung for any reason:

- File I/O deadlock
- Infinite loop in dependency resolution
- Unhandled promise rejection
- Node.js process stuck

...the Python subprocess would wait forever, blocking the MCP tool call indefinitely.

## Solution

Added **10-second hard timeout** with proper exception handling:

```python
try:
    process = subprocess.run(
        ["node", str(script_path)],
        cwd=str(mcp_server_root),
        env=env,
        capture_output=True,
        text=True,
        check=False,
        timeout=10.0,  # ✓ Guaranteed exit after 10s
    )
except subprocess.TimeoutExpired as e:
    raise RuntimeError(
        f"Bundle operation timed out after 10 seconds.\n"
        f"project_dir: {env.get('PROJECT_DIR')}\n"
        f"This usually indicates:\n"
        f"  1. Infinite loop in bundler script\n"
        f"  2. Hanging file I/O operation\n"
        f"  3. Node.js process stuck\n"
        f"Captured output before timeout:\n"
        f"stdout: {e.stdout.decode('utf-8') if e.stdout else '<none>'}\n"
        f"stderr: {e.stderr.decode('utf-8') if e.stderr else '<none>'}"
    )
```

## Verification of bundle-and-deploy.js Safety

Checked for potential infinite loop risks:

### ✓ Circular Dependency Protection

Lines 159-161 handle circular deps:

```javascript
if (stack.has(normalizedEntry)) {
  circularDeps.add(normalizedEntry);
  return; // Exits recursion
}
```

### ✓ Visited Set Prevention

Lines 164-166:

```javascript
if (visited.has(normalizedEntry)) {
  return; // Prevents re-processing
}
```

### ✓ Regex Loop Safety

Line 102 uses proper regex exec pattern:

```javascript
while ((match = requirePattern.exec(content)) !== null) {
  requires.push(match[1]);
}
```

Global regex resets properly with `exec()` in while loops.

### ✓ Async Operations

All file I/O uses `fs.promises` with proper `await`, no blocking operations.

## What This Guarantees

1. **MCP tool will exit within 10 seconds**, even if bundler hangs
2. **AI models won't get stuck waiting** for unresponsive tool calls
3. **Diagnostic info captured** - timeout exception includes partial stdout/stderr
4. **Process killed** - subprocess.TimeoutExpired terminates the child process

## Testing

To test timeout behavior:

```python
# Simulate hanging bundler by adding sleep in bundle-and-deploy.js:
# setTimeout(() => {}, 60000);  // 60s sleep
```

Expected result: RuntimeError raised after exactly 10 seconds with timeout message.
