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

What install does:

1. Ensures Lua 5.4+ is available (auto-installs to `automations/bin/lua/` when needed).
2. Installs Node dependencies for bundling/crawler automation.
3. Pulls the upstream docs repository (`https://github.com/lbox-src/docs`) into `data/upstream_docs/lbox-src-docs/`.
4. Leaves website crawl refresh optional (`-RunWebRefresh`) so startup stays fast.

## MCP Config (VS Code / Cursor / Claude)

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

If you use the bundled executable instead of Python launcher:

```json
{
  "servers": {
    "lmaobox-context": {
      "type": "stdio",
      "command": "C:/path/to/Lmaobox_Context_Server/lmaobox-context-server.exe",
      "cwd": "C:/path/to/Lmaobox_Context_Server",
      "disabled": false
    }
  }
}
```

## New Here? Start With These Paths

- MCP stdio entrypoint: `launch_mcp.py`
- MCP tool protocol implementation: `src/mcp_server/mcp_stdio.py`
- HTTP/API logic + symbol lookup: `src/mcp_server/server.py`
- Smart context content: `data/smart_context/README.md`
- Generated types used by `get_types`: `types/lmaobox_lua_api/`
- Bundler and docs automation: `automations/`

## Smart Context Rules

- Layout mirrors `types/lmaobox_lua_api/` under `data/smart_context/lmaobox_lua_api/`.
- Smart files are additive only (extra tips/examples).
- `get_smart_context` always includes base type context from `get_types`.
- If no additive smart file exists, `get_smart_context` falls back to type-derived context automatically.

## Available MCP Tools

- `get_types(symbol)`
- `get_smart_context(symbol)`
- `bundle(projectDir, entryFile?, bundleOutputDir?, deployDir?)`
- `luacheck(filePath, checkBundle?)`

## Docs Update Flow

Install-time default:

- `scripts/fetch-upstream-docs.ps1` syncs `https://github.com/lbox-src/docs` into `data/upstream_docs/lbox-src-docs/`

Manual refresh options:

- Upstream docs repo only:

```powershell
powershell -ExecutionPolicy Bypass -File scripts/fetch-upstream-docs.ps1
```

- Website crawl + type regeneration:

```powershell
node automations/refresh-docs.js
```

## Development Notes

- `launch_mcp.py` auto-runs Lua setup so first launch is usually zero-touch.
- For HTTP mode: `python -m src.mcp_server.server` (default `127.0.0.1:8765`).
- Health endpoint: `/health`
- Sample test script: `scripts/test-get-types.ps1`

## Extra Navigation

- Architecture map: `docs/ARCHITECTURE.md`
- Install and operations guide: `docs/INSTALL_AND_OPERATIONS.md`
