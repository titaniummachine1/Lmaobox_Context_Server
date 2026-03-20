# Lmaobox Context Engine (MCP)

MCP server for Lmaobox Lua context with generated type lookups, curated smart context files, and Lua tooling helpers.

## Quick Start (Windows)

Local clone bootstrap:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/install.ps1
```

Remote one-liner bootstrap:

```powershell
irm https://raw.githubusercontent.com/titaniummachine1/Lmaobox_Context_Server/main/scripts/install.ps1 | iex
```

## MCP Setup (VS Code / Cursor / Claude)

**Easy setup for AI or manual install:**

```powershell
# Auto-generate and display the config (copy & paste into settings)
.\scripts\setup-mcp-config.ps1

# OR: Auto-install directly into VS Code
.\scripts\setup-mcp-config.ps1 -EditorConfigPath "$env:APPDATA\Code\User\settings.json"

# OR: Auto-install directly into Cursor
.\scripts\setup-mcp-config.ps1 -EditorConfigPath "$env:APPDATA\Cursor\User\settings.json"
```

**After running one of the above:**

1. Restart your editor (VS Code / Cursor)
2. You should see "lmaobox-context" MCP server in the status bar at the bottom

**Manual config (if preferred):** Add this to your editor's `settings.json` under `"modelContextProtocol.servers"`:

```json
{
  "modelContextProtocol.servers": {
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

**If using the pre-built executable instead of Python:**

```json
{
  "modelContextProtocol.servers": {
    "lmaobox-context": {
      "type": "stdio",
      "command": "C:/path/to/Lmaobox_Context_Server/lmaobox-context-server.exe",
      "cwd": "C:/path/to/Lmaobox_Context_Server",
      "disabled": false
    }
  }
}
```

## Source Of Truth

- Python stdio entrypoint: `launch_mcp.py`
- Python MCP tool implementation: `src/mcp_server/mcp_stdio.py`
- Python HTTP/type lookup logic: `src/mcp_server/server.py`
- Native Go MCP implementation: `main.go`
- Bundling automation: `automations/bundle-and-deploy.js`

## Smart Context Rules

- Layout mirrors `types/lmaobox_lua_api/` under `smart_context/lmaobox_lua_api/`.
- Smart files are additive only (extra tips/examples).
- `get_smart_context` always includes base type context from `get_types`.
- If no additive smart file exists, `get_smart_context` falls back to type-derived context automatically.

## Available MCP Tools

- `get_types(symbol)`
- `get_smart_context(symbol)`
- `smart_search(query, limit?, searchWindow?, includeExamples?)`
- `bundle(projectDir, entryFile?, bundleOutputDir?, deployDir?)`
- `luacheck(filePath, checkBundle?)`

## Recommended VS Code Extensions

This repo now includes workspace recommendations in `.vscode/extensions.json`.
When prompted by VS Code after clone, install recommended extensions to avoid missing tooling.

- `golang.go` (Go language server, formatting, diagnostics)
- `ms-python.python` + `ms-python.vscode-pylance` (Python env + type checking)
- `sumneko.lua` (Lua language features)
- `ms-vscode.powershell` (PowerShell scripts and debugging)
- `emeraldwalk.runonsave` (auto-deploy prototypes on save)
- `yzhang.markdown-all-in-one` (maintaining docs/smart context markdown)

## Contributor First-Clone Checklist

1. Run `powershell -ExecutionPolicy Bypass -File scripts/install.ps1`
2. Install recommended extensions from `.vscode/extensions.json`
3. Use the repo virtualenv Python for scripts: `./.venv/Scripts/python.exe ...`
4. Use env-based paths (for example `%LOCALAPPDATA%\\lua`) and avoid hardcoded user paths in scripts/docs

### Path Portability Policy

- Do not commit `C:\Users\<name>\...` paths
- Prefer `${workspaceFolder}` in VS Code settings/tasks
- Prefer `$env:LOCALAPPDATA` in PowerShell and `Path(__file__)` / repo-relative paths in Python
- Keep repo scripts runnable from any clone location

## Development Notes

- `launch_mcp.py` auto-runs Lua setup so first launch is usually zero-touch.
- Prefer the Python launcher for source-based development.
- For HTTP mode: `python -m src.mcp_server.server` (default `127.0.0.1:8765`).
- Health endpoint: `/health`
- Sample test script: `scripts/test-get-types.ps1`
