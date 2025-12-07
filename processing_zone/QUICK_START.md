# Quick Start: Bulk Parsing Session

## Immediate Setup (5 minutes)

### 1. Verify MCP Server

```bash
# Start MCP server if not running
python scripts/launch_mcp_standalone.py

# Test it works
python scripts/mcp_cli.py get_types engine.TraceLine
```

### 2. Prepare Folders

All folders should already exist:

- ✅ `01_TO_PROCESS/` - Drop your 234 scripts here
- ✅ `02_IN_PROGRESS/` - Files being processed
- ✅ `03_DONE/` - Completed files
- ✅ `RAW_NOTES/` - JSON extractions

### 3. Load Scripts

Copy all 234 Lua scripts into `processing_zone/01_TO_PROCESS/`

## Start Extraction

### Move First Batch

```bash
# Move 20 files to start
python scripts/batch_extract.py --max-files 20
```

### Agent Instructions

**Give each agent this prompt:**

> I need you to extract API usage examples from Lua scripts.
> Read the guide: `processing_zone/AGENT_EXTRACTION_PROMPT.md`
>
> Take files from `02_IN_PROGRESS/`, extract examples, save JSON to `RAW_NOTES/`,
> and move processed files to `03_DONE/`.
>
> Use MCP server tools (`get_types`, `get_smart_context`) to verify API symbols.

### Process Next Batches

After agents finish a batch:

```bash
# Move next 20 files
python scripts/batch_extract.py --max-files 20

# Check progress
python scripts/validate_extractions.py
```

## After All Extraction Complete

### Consolidation Phase

Single agent follows:

> Read guide: `processing_zone/AGENT_CONSOLIDATION_PROMPT.md`
>
> Load all JSON from `RAW_NOTES/`, group by symbol, select best examples,
> and create curated MD files in `data/smart_context/`.

## Key Tools

```bash
# Batch management
python scripts/batch_extract.py --max-files 20

# Validation
python scripts/validate_extractions.py

# MCP CLI
python scripts/mcp_cli.py get_types <symbol>
python scripts/mcp_cli.py get_smart_context <symbol>

# Query examples from documentation (HTML cache + database)
python scripts/query_examples.py engine.TraceLine
python scripts/query_examples.py --all --html-only  # All examples

# Insert custom symbols
python scripts/mcp_insert_custom.py md --file <path> --symbol <name> --allow-create
```

## Full Workflow

See `processing_zone/BULK_PARSING_WORKFLOW.md` for complete details.
