# Lmaobox Context Engine (MCP)

MCP server for Lmaobox Lua context with generated type lookups, curated smart context files, and Lua tooling helpers.

## Marketplace Distribution

This repo now includes a Marketplace-ready VS Code extension wrapper in [vscode-extension](vscode-extension) and a GitHub runtime release workflow in [.github/workflows/release.yml](.github/workflows/release.yml).

The intended flow is:

1. Push a version tag such as `v1.0.0`.
2. GitHub Actions builds the packaged runtime archives and `checksums.txt`.
3. Publish the VS Code extension from [vscode-extension](vscode-extension).
4. The installed extension downloads the matching GitHub-built runtime into VS Code storage and configures the MCP server automatically.

See [docs/MARKETPLACE_RELEASE.md](docs/MARKETPLACE_RELEASE.md) for the full publish flow.

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

## Adding Or Editing Smart Context

Yes, you can add new context files or modify existing ones directly under `smart_context/`.

### Edit Existing Context

1. Locate the current file for the symbol in `smart_context/lmaobox_lua_api/...`
2. Update notes/examples in that markdown file
3. Re-run a lookup to verify output:

```powershell
./.venv/Scripts/python.exe scripts/mcp_cli.py get_smart_context engine.TraceLine
```

### Add New Context For A Symbol

Create a markdown file in the mirrored path for that symbol:

- Library symbol example: `engine.TraceLine` -> `smart_context/lmaobox_lua_api/Lua_Libraries/engine/TraceLine.md`
- Class member example: `Entity.GetHealth` -> `smart_context/lmaobox_lua_api/Lua_Classes/Entity/GetHealth.md`
- Class overview example: `Trace` -> `smart_context/lmaobox_lua_api/Lua_Classes/Trace/index.md`
- Constants example: `E_TraceLine` -> `smart_context/lmaobox_lua_api/constants/E_TraceLine.md` (optional; type fallback already works)

### Add New Custom Topic (No Exact Type Symbol)

You can also add helper/pattern docs (for example under `Lua_Libraries/patterns/`).
These may be found through fallback matching and are useful for workflows, not just raw API symbols.

For extra structure details, see `smart_context/README.md`.

## Available MCP Tools

- `get_types(symbol)`
- `get_smart_context(symbol)`
- `smart_search(query, limit?, searchWindow?, includeExamples?)`
- `bundle(projectDir, entryFile?, bundleOutputDir?, deployDir?)`
- `luacheck(filePath, checkBundle?)`
  - Includes hard-fail Zero-Mutation callback policy checks in Go runtime:
    - `callbacks.Register` and `callbacks.Unregister` must be at depth 0 (global scope)
    - `callbacks.Unregister(event, id)` must appear before `callbacks.Register(event, id, fn)` (Kill-Switch)
    - `callbacks.Unregister` is forbidden inside any function block, including unload handlers

## Recommended VS Code Extensions

This repo now includes workspace recommendations in `.vscode/extensions.json`.
When prompted by VS Code after clone, install recommended extensions to avoid missing tooling.

- `golang.go` (Go language server, formatting, diagnostics)
- `ms-python.python` + `ms-python.vscode-pylance` (Python env + type checking)
- `sumneko.lua` (Lua language features)
- `ms-vscode.powershell` (PowerShell scripts and debugging)
- `emeraldwalk.runonsave` (auto-deploy prototypes on save)
- `yzhang.markdown-all-in-one` (maintaining docs/smart context markdown)

## VS Code: Sumneko (Lua) Auto-Configuration

The extension and installer now attempt to make Sumneko (Lua language server) work out-of-the-box by adding our packaged `types/` annotations to the user's Lua workspace library.

- On first-run the extension will try to auto-install `sumneko.lua` and will inject `Lua.workspace.library` entries into the user's settings (unless disabled).
- The installer (`scripts/install.ps1`) copies the repo `types/` into `%LOCALAPPDATA%/lmaobox-context-server/types` so the annotations are available across workspaces.
- If you prefer manual steps, run:

```powershell
# install runtime + copy packaged types to local appdata
powershell -ExecutionPolicy Bypass -File .\scripts\install.ps1

# inject Lua workspace library entries into your VS Code settings
.\scripts\setup-mcp-config.ps1 -EditorConfigPath "$env:APPDATA\Code\User\settings.json"

# install Sumneko extension (optional)
code --install-extension sumneko.lua
```

The extension also exposes two commands:

- `Lmaobox Context: Inject Lua Workspace Library` — manually injects the library entries into user settings.
- `Lmaobox Context: Toggle Auto-Configure Lua Library` — toggles automatic injection on/off.

If a user reports Sumneko is "broken", ask them to run the two commands above — most issues are resolved by installing the Sumneko extension and restarting the Lua language server.

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
