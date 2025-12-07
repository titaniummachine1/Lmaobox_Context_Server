# Lmaobox Context Engine (MCP)

Single-purpose MCP server for serving Lmaobox Lua API context, generated types, and curated smart-context notes. Everything is in English to keep the workflow consistent.

## What’s here

- **MCP server** (`src/mcp_server/server.py`): endpoints for `/health`, `/get_types`, and `/smart_context`.
- **Smart context store** (`data/smart_context/`): curated `.md` files per symbol (API or custom helpers). Nearest-definition lookup with fuzzy fallback.
- **Generated types** (`types/lmaobox_lua_api/`): fast type/signature lookup and fallback source when the DB is empty.
- **Processing zones** (`processing_zone/01_TO_PROCESS`, `02_IN_PROGRESS`, `03_DONE` + `RAW_NOTES/`): staging for mining/consolidation workflows.
- **Crawler** (`automations/crawler/`): existing JS crawler and type generator. Keep this intact; bundler artifacts were removed.

## Running the MCP server

### For Cursor IDE / Claude Desktop (MCP Protocol)

The server supports the MCP (Model Context Protocol) stdio interface for integration with Cursor IDE and Claude Desktop.

**Quick Setup:**

1. See `MCP_SETUP.md` for detailed configuration instructions
2. Add the server to your Cursor/Claude Desktop MCP config
3. Restart Cursor/Claude Desktop to load the server

**Manual test:**

```bash
python launch_mcp.py
# Server will communicate via JSON-RPC over stdin/stdout
```

### HTTP Server (Alternative)

For HTTP-based access:

```bash
python -m src.mcp_server.server
# or
python src/mcp_server/server.py
```

Defaults: `127.0.0.1:8765`. Configure via env:

- `MCP_HOST`, `MCP_PORT`
- `MCP_DB_PATH` (defaults to `.cache/docs-graph.db`)

**Available MCP Tools:**

- `get_types(symbol)` - Get type information for a Lmaobox Lua API symbol
  - Reads SQLite `symbol_metadata`; falls back to scanning `types/` for a signature and caches it.
- `get_smart_context(symbol)` - Get curated smart context for a symbol
  - Nearest-definition search in `data/smart_context/` (e.g., `Foo.Bar.Baz.md`, `Foo.Bar.md`, `Foo.md`), then fuzzy `*symbol*.md`.

**HTTP Endpoints (if using HTTP server):**

- `/health` → `{status:"ok"}`
- `/get_types?symbol=Symbol.Name` → `{symbol, signature, required_constants, source}`
- `/smart_context?symbol=Symbol.Name` → `{symbol, path, content}` or 404

### Quick sanity check

1. Start the server (task: **Start MCP Server (bg)**).
2. Run the VS Code task **Test get_types (sample)** or execute:
   ```powershell
   pwsh -File scripts/test-get-types.ps1
   ```
   Optional envs: `MCP_HOST`, `MCP_PORT`, `MCP_TEST_SYMBOL` (default symbol: `Draw`).

## Adding smart context (API or custom helpers)

1. Create a markdown file in `data/smart_context/` named after the symbol, e.g. `render.text.md` or `custom.normalize_vector.md`.
2. Include signature and minimal curated examples (keep it short; 1–3 examples).
3. If it depends on constants or other helpers, list them up top.
4. For custom helpers not in docs, follow the same pattern—this lets the AI reuse past solutions instead of reinventing them.

Example file:

````
## Function/Symbol: custom.normalize_vector
> Signature: function normalize_vector(vec)

### Required Context:
- Types: Vector3
- Notes: Safe even if length is zero (engine handles divide-by-zero).

### Curated Usage Examples:
```lua
local function normalize_vector(vec)
    return vec / vec:Length()
end
````

```

## Types and crawler
- Generated types live in `types/lmaobox_lua_api/` (constants, classes, libraries, entity props, globals).
- Docs index: `types/docs-index.json`.
- Crawler entrypoint: `node automations/refresh-docs.js` (see `automations/README.md`).
- Keep `types/` and `Lmaobox-Annotations-master/`—they seed fast lookups for `get_types`.

## Housekeeping
- `.gitignore` excludes caches, build outputs, and processing churn; `.gitkeep` pins empty staging folders.
- Removed legacy bundler scripts and node_modules to keep the repo focused on MCP, crawler, and types.

```
