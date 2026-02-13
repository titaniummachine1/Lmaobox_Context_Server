# Lua Runner - Integrated Lmaobox Development Tool

Fast iteration Lua development for Lmaobox with hot-reload, error capture, and bundle integration.

## Quick Start

### 1. Setup In-Game Helper

Copy `lua_runner_helper.lua` to your Lmaobox Lua folder and load it:

```bash
# Find your Lmaobox Lua folder (typically in TF2 directory)
cp lua_runner_helper.lua "C:/Program Files (x86)/Steam/steamapps/common/Team Fortress 2/lmaobox/lua/"
```

In Lmaobox console:
```
lua_load lua_runner_helper
```

You should see: `[LuaRunner] Helper loaded. Polling http://127.0.0.1:27182`

### 2. Start MCP Server

The MCP server now includes the Lua runner automatically:

```bash
python -m src.mcp_server.server
```

Or use the CLI tool directly (it will auto-start the runner):

```bash
python lua_runner_cli.py state
```

## Usage

### Execute a Lua File

```bash
# Execute and wait for result
python lua_runner_cli.py execute -f myscript.lua --wait

# Execute without waiting
python lua_runner_cli.py execute -f myscript.lua
```

### Execute Inline Code

```bash
python lua_runner_cli.py execute -c "print(engine.GetMapName())" --wait
```

### Bundle and Execute Project

```bash
# Bundle Main.lua and execute
python lua_runner_cli.py bundle ./my_project --wait

# Bundle with different entry point
python lua_runner_cli.py bundle ./my_project -e Server.lua --wait
```

### Debug Session (60s Error Capture)

```bash
# Start 60-second debug session
python lua_runner_cli.py debug -d 60

# While debugging, play the game normally. All errors are captured.
# Press Ctrl+C to stop early and see the report.
```

### Check Execution Status

```bash
python lua_runner_cli.py status -i exec_1234567890 --show-output
```

### Check Runner State

```bash
python lua_runner_cli.py state
```

## Architecture

```
┌─────────────────┐     HTTP (port 27182)      ┌──────────────────┐
│   Lua Runner    │◄──────────────────────────►│  lua_runner_     │
│   Server        │  /getscript, /output, etc  │  helper.lua      │
│   (Python)      │                            │  (runs in game)  │
└────────┬────────┘                            └──────────────────┘
         │
         │ HTTP (port 8765)
         ▼
┌─────────────────┐
│   MCP Server    │◄── CLI tool, IDE, curl
│   (extended)    │
└─────────────────┘
```

## API Endpoints

### GET /lua/state
Get runner state and current execution status.

### GET /lua/status?id=<execution_id>
Get results for a specific execution.

### GET /lua/debug_status
Get current debug session status.

### POST /lua/execute
Execute a Lua script.
```json
{
  "script": "print('hello')",
  "script_id": "optional_id"
}
```

### POST /lua/execute_bundle
Bundle a project and execute it.
```json
{
  "project_dir": "/path/to/project",
  "entry_file": "Main.lua"
}
```

### POST /lua/debug
Start a debug session.
```json
{
  "duration_seconds": 60
}
```

### POST /lua/debug_stop
Stop debug session early and get results.

## Workflow Examples

### Fast Iteration Loop

```bash
# 1. Start debugging (catches all errors for 60s)
python lua_runner_cli.py debug &

# 2. Make changes and hot-reload
python lua_runner_cli.py bundle ./my_cheat --wait

# 3. See if it worked, fix errors if any
# (errors appear in real-time in the debug session)

# 4. Repeat steps 2-3 rapidly
```

### Single File Testing

```bash
# Edit file in VS Code, then:
python lua_runner_cli.py execute -f test_feature.lua --wait
```

### Full Bundle Testing

```bash
# Before deploying, test the full bundle:
python lua_runner_cli.py bundle ./my_project --wait

# Check for errors, then deploy for real:
node automations/bundle-and-deploy.js ./my_project
```

## Error Capture

The helper script captures:
- Compile errors (syntax errors)
- Runtime errors (uncaught exceptions)
- Callback errors (errors in registered callbacks)
- All `print()` output

Errors are sent to the external tool in real-time.

## Callback Tracking

The helper tracks all `callbacks.Register()` calls and reports them. This lets you:
- See what callbacks your script registered
- Know which callbacks might need cleanup
- Detect callback leaks

## Port Configuration

Default ports (fixed to avoid mismatches):
- **27182**: Lua Runner internal communication (runner ↔ in-game helper)
- **8765**: MCP server (CLI/tool ↔ MCP server)

Both ports must be available. If you need to change them, edit:
- `src/mcp_server/lua_runner.py` - `LuaRunnerServer.PORT`
- `lua_runner_helper.lua` - `CONFIG.server_url`
- `lua_runner_cli.py` - `MCP_BASE_URL`

## Troubleshooting

### "Connection refused" errors
1. Make sure `lua_runner_helper.lua` is loaded in Lmaobox
2. Check that the MCP server is running: `python lua_runner_cli.py state`
3. Verify ports 27182 and 8765 are not blocked by firewall

### Scripts not executing
1. Check that the helper shows "Polling" message on load
2. Verify no other process is using port 27182
3. Try reloading the helper: `lua_load lua_runner_helper`

### Bundle execution fails
1. Make sure `node` and `luabundle` are installed
2. Check that the project has valid Lua syntax
3. Verify the entry file exists

## Integration with IDE

You can create VS Code tasks:

```json
{
  "version": "2.0.0",
  "tasks": [
    {
      "label": "Execute Lua",
      "type": "shell",
      "command": "python",
      "args": [
        "${workspaceFolder}/lua_runner_cli.py",
        "execute",
        "-f",
        "${file}",
        "--wait"
      ],
      "group": "build",
      "presentation": {
        "echo": true,
        "reveal": "always",
        "focus": false,
        "panel": "shared"
      }
    },
    {
      "label": "Bundle Project",
      "type": "shell",
      "command": "python",
      "args": [
        "${workspaceFolder}/lua_runner_cli.py",
        "bundle",
        "${workspaceFolder}",
        "--wait"
      ],
      "group": "build"
    }
  ]
}
```

Bind to keyboard shortcuts for instant execution.
