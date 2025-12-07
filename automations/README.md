# Automation Scripts

This folder contains automation scripts for building, deploying, and maintaining the Lua development environment.

## Main Scripts

### `refresh-docs.js` ⭐ **Primary Entry Point**

**Purpose**: Crawl entire documentation site, build graph of all docs, parse everything, and generate type definitions.

**Usage**:

```bash
# Full refresh (bypasses 24-hour rate limit)
node automations/refresh-docs.js

# Single-page debug mode
node automations/refresh-docs.js --url=https://lmaobox.net/lua/Lua_Constants/
```

**What it does**:

1. Fetches `https://lmaobox.net/lua/sitemap.xml`
2. Discovers all documentation pages
3. Builds a graph/hierarchy of all documentation pages
4. Fetches and parses each page (with rate limiting and caching)
5. Extracts: libraries, classes, functions, methods, callbacks, globals, constants, examples
6. Generates type definitions in `types/lmaobox_lua_api/`
7. Updates `.luarc.json` with discovered globals
8. Creates docs index for AI

**Rate limiting**:

- Automatic runs: Limited to once per 24 hours
- Manual refresh: Bypasses rate limit (forces full crawl)
- Page fetches: 1 second delay between requests

### `auto-commit.js`

**Purpose**: Auto-commit when >10 lines changed  
**When it runs**: After successful bundle/deploy (via BundleAndDeploy.bat)  
**Note**: Only commits, never pushes

### `bundle.js`

**Purpose**: Bundle Lua files  
**When it runs**: On file save (via BundleAndDeploy.bat)

### `BundleAndDeploy.bat`

**Purpose**: Bundle and deploy Lua files  
**When it runs**: On `.lua` file save (via Run On Save extension)  
**What it does**:

1. Bundles Lua files using `bundle.js`
2. Deploys to `%localappdata%\lua\`
3. Runs `auto-commit.js` for Git commits

## Installation

```bash
cd automations
npm install
```

## Output Locations

- **Type Definitions**: `types/lmaobox_lua_api/**/*.d.lua`
- **Database**: `.cache/docs-graph.db`
- **HTML Cache**: `.cache/docs/**/*.html`
- **Config**: `.vscode/.luarc.json` (globals updated)

## Troubleshooting

**No output?**

- Check the terminal panel in VS Code
- Make sure Node.js is installed: `node --version`
- Run `cd automations && npm install`

**Types not updating?**

- Reload VS Code window: `Ctrl+Shift+P` → "Developer: Reload Window"
- Check `types/lmaobox_lua_api/` folder exists and has `.d.lua` files

**Crawler errors?**

- Check internet connection
- Verify `https://lmaobox.net/lua/sitemap.xml` is accessible
- Check `.cache/` folder permissions

## Crawler System

See `crawler/README.md` for detailed information about the crawler architecture and internals.

### `fast-refresh.js` (no crawl; reuse cache/parsed data)
**Purpose**: Regenerate types, docs index, and materialized symbols graph without hitting the network (uses cached HTML and stored parsed_data).

**Usage**:
```bash
node automations/fast-refresh.js
```

**What it does**:
1. Regenerates types from existing DB/cache (no fetch).
2. Regenerates `types/docs-index.json`.
3. Materializes the symbols graph (functions/classes/constants/examples) into SQLite for Smart Context reuse.
