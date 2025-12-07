# Examples Sources Guide

During extraction and consolidation, agents should check multiple sources for examples:

## 1. Official Documentation (Cached HTML)

**Location**: `.cache/docs/`

**Structure:**
- Library functions: `.cache/docs/Lua_Libraries/<library>.html`
  - Example: `.cache/docs/Lua_Libraries/engine.html` for `engine.TraceLine`
- Class methods: `.cache/docs/Lua_Classes/<Class>.html`
  - Example: `.cache/docs/Lua_Classes/Entity.html` for `Entity:GetAbsOrigin`
- Constants: `.cache/docs/Lua_Constants.html`

**Query tool:**
```bash
python scripts/query_examples.py engine.TraceLine
```

This tool:
- Extracts code blocks from cached HTML files
- Queries examples stored in the database
- Shows source URL for each example

## 2. Database Examples

The crawler has already extracted examples from HTML and stored them in the database.

**Query:**
```bash
python scripts/query_examples.py engine.TraceLine --db-only
```

Examples are stored in `.cache/docs-graph.db` in the `examples` table.

## 3. User Scripts (RAW_NOTES)

Extracted from scripts in `processing_zone/01_TO_PROCESS/`:
- Real-world usage patterns
- Custom implementations
- Edge cases not in documentation

**Location**: `RAW_NOTES/*.json`

## Priority Order

When consolidating examples:

1. **Official documentation examples** (from cached HTML) - Most authoritative
2. **Real-world script examples** - Shows actual usage patterns
3. **Custom helper patterns** - Useful for reuse

## Example Query Workflow

For a symbol like `engine.TraceLine`:

1. **Get types**:
   ```bash
   python scripts/mcp_cli.py get_types engine.TraceLine
   ```

2. **Get official examples**:
   ```bash
   python scripts/query_examples.py engine.TraceLine
   ```

3. **Check HTML directly** (if needed):
   - Open `.cache/docs/Lua_Libraries/engine.html`
   - Search for "TraceLine"
   - Extract code blocks manually

4. **Get script examples**:
   - Load all JSON from `RAW_NOTES/`
   - Filter for `symbol == "engine.TraceLine"`

5. **Consolidate**:
   - Include 1-2 official examples (if available)
   - Include 1-2 best script examples
   - Write to `data/smart_context/engine/TraceLine.md`

## Benefits

- **Official examples**: Authoritative, well-documented
- **Script examples**: Real-world usage, edge cases
- **Combined**: Comprehensive coverage

## Tools Reference

```bash
# Query examples (database + HTML)
python scripts/query_examples.py <symbol>

# HTML cache only
python scripts/query_examples.py <symbol> --html-only

# Database only
python scripts/query_examples.py <symbol> --db-only

# All examples
python scripts/query_examples.py --all

# JSON output
python scripts/query_examples.py engine.TraceLine --format json
```

