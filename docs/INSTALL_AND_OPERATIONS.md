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
      "command": "C:/path/to/lmaobox-context-protocol/lmaobox-mcp.exe",
      "args": [],
      "disabled": false
    }
  }
}
```

## Run Modes

Build binary:

```powershell
cd c:\gitProjects\lmaobox-context-protocol
go build -o lmaobox-mcp.exe .
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
