# Architecture Map

## Runtime Entry Points

- Stdio MCP launcher: `launch_mcp.py`
- Stdio MCP protocol handler and tools: `src/mcp_server/mcp_stdio.py`
- HTTP server and lookup logic: `src/mcp_server/server.py`
- Shared config: `src/mcp_server/config.py`

## Data Layout

- Curated smart context files: `data/smart_context/`
- Upstream docs mirror (install-time sync): `data/upstream_docs/lbox-src-docs/`
- Generated types for symbol lookup: `types/lmaobox_lua_api/`
- Metadata/index files: `types/docs-index.json`

## Tool Responsibilities

- `get_types`: returns type signature and related constants using DB and type-file fallback scanning.
- `get_smart_context`: resolves closest matching markdown context in `data/smart_context/`.
- `bundle`: runs Node bundler automation from `automations/bundle-and-deploy.js`.
- `luacheck`: validates Lua syntax with Lua 5.4+ compiler; optional bundle dry-run.

## Automation Layout

- Install Lua runtime helper: `automations/install_lua.py`
- Crawler + type generation: `automations/refresh-docs.js`
- Install bootstrap script: `scripts/install.ps1`
- Upstream docs sync script: `scripts/fetch-upstream-docs.ps1`

## What To Edit For Common Changes

- Add or improve smart context for symbol: create/update markdown in `data/smart_context/`.
- Improve type extraction or fallback behavior: update `src/mcp_server/server.py`.
- Add MCP tool or adjust tool schema: update `src/mcp_server/mcp_stdio.py`.
- Change installation/setup behavior: update `scripts/install.ps1` and `automations/install_lua.py`.
- Update docs source sync behavior: update `scripts/fetch-upstream-docs.ps1`.
