# Documentation Crawler System

The crawler automatically discovers, fetches, parses, and generates type definitions for the Lmaobox Lua API.

## Architecture

### Core Components

- **`index.js`** - Main crawler orchestrator
- **`config.js`** - Configuration and paths
- **`database/`** - SQLite database for page tracking
- **`fetcher/`** - Incremental fetching with caching
- **`graph/`** - Sitemap parsing and path analysis
- **`parser/`** - HTML parsing and type generation
- **`utils/`** - Helper utilities

### How It Works

1. **Sitemap Discovery** - Fetches and parses `sitemap.xml` to discover all pages
2. **Graph Building** - Builds hierarchical structure from URL paths
3. **Incremental Fetching** - Fetches only new/changed pages (with rate limiting)
4. **HTML Parsing** - Extracts functions, classes, libraries, constants, examples
5. **Type Generation** - Generates `.d.lua` files organized by URL hierarchy
6. **Index Creation** - Creates docs index for AI access

## Configuration

### Environment Variables

- `TYPES_ROOT` - Base directory for generated types (default: `<workspace>/types`)
- `TYPES_NAMESPACE` - Nested folder name for API surface (default: `lmaobox_lua_api`)

### Output Structure

```
types/
└── lmaobox_lua_api/          # Configurable via TYPES_NAMESPACE
    ├── constants/             # Constant definitions by category
    ├── entity_props/         # Entity property definitions
    ├── Lua_Classes/          # Class definitions
    └── Lua_Libraries/        # Library definitions
```

## Rate Limiting

- **Sitemap fetch**: Max once per 24 hours (stored in `.cache/last-update.json`)
- **Page fetches**: 1 second delay between requests
- **Session cache**: Prevents duplicate fetches in same session

## Debug Tools

Debug scripts are located in `crawler/debug/`:

- `debug-constants.js` - Test constants parsing
- `debug-parse.js` - Test HTML parsing
- `test-constants-parse.js` - Validate constants extraction
- `test-entity-props.js` - Test entity props parsing
- `test-parse-simple.js` - Simple parsing tests

## Database Schema

The crawler uses SQLite to track:

- Page URLs and metadata
- Parsed content (functions, classes, etc.)
- Link relationships
- Type definitions
- Update timestamps

## Type Generation

### Special Handling

- **Constants Page** (`Lua_Constants`) - Generates per-category files in `constants/`
- **Entity Props Page** (`TF2_props`) - Generates per-entity files in `entity_props/`
- **Index/Changelog** - Skipped (pollutes output)

### Parsing Logic

- Extracts function signatures from h3 headings
- Parses parameter types from function definitions
- Infers return types from function names
- Extracts constants from HTML tables
- Handles generic-style parameters (`table<TempEntity,EventInfo>`)

## Maintenance

### Adding New Parsers

1. Add parsing logic to `parser/html.js`
2. Update type generation in `parser/types.js`
3. Test with single-page mode: `node automations/refresh-docs.js --url=<page>`

### Debugging

Use single-page mode to test specific pages:

```bash
node automations/refresh-docs.js --url=https://lmaobox.net/lua/Lua_Constants/
```

This regenerates types for just that page without running the full crawl.
