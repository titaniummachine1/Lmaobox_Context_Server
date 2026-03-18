# Install And Operations

## One-Command Install

From repository root:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
```

Remote bootstrap:

```powershell
irm https://raw.githubusercontent.com/titaniummachine1/Lmaobox_Context_Server/main/scripts/install.ps1 | iex
```

## Installer Flags

- `-SkipNodeInstall`: skip `npm ci` in `automations/`
- `-SkipLuaInstall`: skip Lua 5.4+ setup
- `-SkipDocsFetch`: skip syncing `https://github.com/lbox-src/docs`
- `-RunWebRefresh`: run website crawler/type refresh after install

Example:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1 -RunWebRefresh
```

## MCP Config Example

```json
{
  "servers": {
    "lmaobox-context": {
      "type": "stdio",
      "command": "python",
      "args": ["C:/path/to/Lmaobox_Context_Server/launch_mcp.py"],
      "cwd": "C:/path/to/Lmaobox_Context_Server",
      "disabled": false
    }
  }
}
```

## Run Modes

Stdio mode (for MCP client):

```powershell
python launch_mcp.py
```

HTTP mode (debug/testing):

```powershell
python -m src.mcp_server.server
```

## Operational Commands

Sync upstream docs mirror only:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/fetch-upstream-docs.ps1
```

Regenerate types from website crawler:

```powershell
node automations/refresh-docs.js
```

Health check (HTTP mode):

```powershell
powershell -File scripts/test-get-types.ps1
```
