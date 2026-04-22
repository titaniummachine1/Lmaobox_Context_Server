# Architecture Map

## Runtime Entry Points

- MCP server binary (Go): `lmaobox-mcp.exe` (built from `main.go`)
- MCP config: `C:\Users\<user>\AppData\Roaming\Code\User\mcp.json`

## Data Layout

- Curated smart context files (types-mirrored): `data/smart_context/lmaobox_lua_api/`
- Upstream docs mirror (install-time sync): `data/upstream_docs/lbox-src-docs/`
- Generated types for symbol lookup: `types/lmaobox_lua_api/`
- Metadata/index files: `types/docs-index.json`

## Tool Responsibilities

- `get_types`: returns type signature and related constants using DB and type-file fallback scanning.
- `get_smart_context`: composes base type context from `get_types` plus optional additive markdown from mirrored smart-context files.
- `bundle`: runs Go-native bundler; resolves require() dependencies from project root and writes to `build/Main.lua`, then deploys to `%LOCALAPPDATA%/lua`.
- `luacheck`: validates Lua syntax with Lua 5.4+ compiler, then runs Zero-Mutation policy linter, then runs luacheck if available.
- `smart_search`: full-text + fuzzy search over all type and smart-context data.

## Zero-Mutation Policy Linter Rules

Enforced by `checkLuaCallbackMutationPolicy` in `main.go`:

| Rule | Description |
|------|-------------|
| `RequireDepthZeroRegister` | `callbacks.Register` must be at file scope (depth 0) |
| `RequireDepthZeroUnregister` | `callbacks.Unregister` must be at file scope |
| `RequireKillSwitchOrder` | `Unregister` must precede `Register` for same event+id at depth 0 |
| `ForbidRuntimeUnregister` | `Unregister` inside any function body is forbidden |
| `ForbidCollectGarbage` | `collectgarbage()` calls are forbidden — masks leaks |
| `ForbidRequireInFunction` | `require()` inside a function causes memory leaks |
| `ForbidGlobalTable` | `_G` usage is forbidden — use the `G` module instead |

## Automation Layout

- Crawler + type generation: `automations/refresh-docs.js`
- Install bootstrap script: `scripts/install.ps1`
- Upstream docs sync script: `scripts/fetch-upstream-docs.ps1`

## What To Edit For Common Changes

- Add or improve smart context for symbol: create/update markdown in `data/smart_context/`.
- Add a new linter rule: add field to `LboxMutationPolicy` struct, enforce in `checkLuaCallbackMutationPolicy`, add test in `mcp_tool_test.go` or `policy_test.go`.
- Add MCP tool or adjust tool schema: update `main.go` (add `mcp.NewTool` registration + handler function).
- Change installation/setup behavior: update `scripts/install.ps1`.
- Update docs source sync behavior: update `scripts/fetch-upstream-docs.ps1`.
