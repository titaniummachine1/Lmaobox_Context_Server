# Bulk Parsing Workflow (234+ Scripts)

## Overview
This document describes the workflow for parsing 234+ Lua scripts and building comprehensive Smart Context.

## Phase 1: Preparation

### 1.1 Folder Structure
Ensure these folders exist:
- `processing_zone/01_TO_PROCESS/` - Drop all 234 scripts here
- `processing_zone/02_IN_PROGRESS/` - Working files (agents process these)
- `processing_zone/03_DONE/` - Completed files
- `RAW_NOTES/` - Raw JSON extractions (one per script)

### 1.2 Verify MCP Server
Ensure MCP server is running:
```bash
# Check health
curl http://127.0.0.1:8765/health

# Test get_types
curl "http://127.0.0.1:8765/get_types?symbol=engine.TraceLine"
```

### 1.3 Batch Setup
```bash
# Move first batch (e.g., 20 files) to IN_PROGRESS
python scripts/batch_extract.py --max-files 20
```

## Phase 2: Extraction (Multiple Agents)

### 2.1 Agent Assignment
Distribute files from `02_IN_PROGRESS/` among multiple AI agents (Cursor instances, etc.).

**Each agent:**
- Takes 5-10 files from `02_IN_PROGRESS/`
- Follows `AGENT_EXTRACTION_PROMPT.md`
- Outputs JSON files to `RAW_NOTES/`
- Moves processed files to `03_DONE/`

### 2.2 Extraction Process

**Per file:**
1. Read Lua file
2. Identify all API symbol usages
3. Use MCP `get_types` to verify API functions
4. Extract verbatim code snippets
5. Create JSON file in `RAW_NOTES/` with schema:
   ```json
   [
     {
       "symbol": "engine.TraceLine",
       "source_file": "script.lua",
       "example": "local trace = engine.TraceLine(src, dst, MASK_SHOT_HULL)",
       "line_number": 42
     }
   ]
   ```
6. Move source file to `03_DONE/`

### 2.3 Quality Check
After extraction batch:
```bash
# Validate all extracted JSON
python scripts/validate_extractions.py
```

### 2.4 Repeat
Move next batch from `01_TO_PROCESS` → `02_IN_PROGRESS`:
```bash
python scripts/batch_extract.py --max-files 20
```

### 2.5 Query Examples from Documentation
During extraction, agents can check official examples:
```bash
# Get examples for a symbol from database and HTML cache
python scripts/query_examples.py engine.TraceLine

# View all examples
python scripts/query_examples.py --all --html-only
```

**Cached HTML locations:**
- Library functions: `.cache/docs/Lua_Libraries/<library>.html`
- Class methods: `.cache/docs/Lua_Classes/<Class>.html`
- Constants: `.cache/docs/Lua_Constants.html`

## Phase 3: Consolidation (Single Agent)

### 3.1 Preparation
Wait until all 234 scripts are extracted (all JSON files in `RAW_NOTES/`).

### 3.2 Consolidation Process
**Single agent** (for consistency) follows `AGENT_CONSOLIDATION_PROMPT.md`:

1. **Load all JSON**: Read all files from `RAW_NOTES/`
2. **Group by symbol**: Create map of `symbol → list of examples`
3. **For each unique symbol**:
   - Call `get_types(symbol)` via MCP
   - Select 1-3 best examples
   - Write MD file to `data/smart_context/`
   - If custom symbol, insert via `mcp_insert_custom.py`

### 3.3 Output Structure
Files placed in `data/smart_context/` mirroring types:
- `engine.TraceLine` → `data/smart_context/engine/TraceLine.md`
- `custom.normalize_vector` → `data/smart_context/custom/normalize_vector.md`

### 3.4 Custom Symbols
For custom helpers/patterns:
```bash
python scripts/mcp_insert_custom.py md \
  --file "data/smart_context/custom/pattern_name.md" \
  --symbol custom.pattern_name \
  --allow-create
```

## Phase 4: Verification

### 4.1 Manual Review
Review files flagged with `DO_MANUAL_REVIEW` sections.

### 4.2 Spot Check
Randomly sample 10% of generated MD files for quality.

### 4.3 Test MCP Integration
```bash
# Test get_smart_context
curl "http://127.0.0.1:8765/smart_context?symbol=engine.TraceLine"
```

## Tools Reference

### Batch Extraction
```bash
# Move files in batches
python scripts/batch_extract.py --max-files 20

# Check status
python scripts/batch_extract.py --dry-run
```

### Validation
```bash
# Validate all extractions
python scripts/validate_extractions.py
```

### Custom Symbol Insertion
```bash
python scripts/mcp_insert_custom.py md \
  --file "data/smart_context/custom/name.md" \
  --symbol custom.name \
  --allow-create
```

### Query Examples from Documentation
```bash
# Get examples for a symbol
python scripts/query_examples.py engine.TraceLine

# Get all examples (HTML cache only)
python scripts/query_examples.py --all --html-only

# Database only
python scripts/query_examples.py engine.TraceLine --db-only
```

### MCP CLI
```bash
# Get types
python scripts/mcp_cli.py get_types engine.TraceLine

# Get smart context
python scripts/mcp_cli.py get_smart_context engine.TraceLine
```

## Progress Tracking

### Extraction Status
- Check `01_TO_PROCESS/`: Remaining files
- Check `02_IN_PROGRESS/`: Currently processing
- Check `03_DONE/`: Completed files
- Check `RAW_NOTES/`: Extracted JSON count

### Consolidation Status
- Check `data/smart_context/`: Generated MD files count
- Compare with unique symbols from `RAW_NOTES/`

## Tips

1. **Batch size**: Process 10-20 files at a time for manageable batches
2. **Parallel agents**: Use multiple Cursor instances for faster extraction
3. **Consistency**: Use single agent for consolidation to maintain consistency
4. **Validation**: Run validation after each batch
5. **Backup**: Commit progress regularly after each batch

## Troubleshooting

### MCP server not responding
```bash
# Restart MCP server
python scripts/launch_mcp_standalone.py
```

### JSON validation errors
- Check schema matches required fields
- Ensure valid JSON syntax
- Use `scripts/validate_extractions.py` to find issues

### Missing symbols
- Custom functions may not be in API
- Still extract them as custom symbols
- Add to Smart Context with inferred signature

## Next Steps After Completion

1. Full refresh of types/docs (if API updated)
2. Update Smart Context with new examples
3. Test MCP server with new context
4. Deploy to production

