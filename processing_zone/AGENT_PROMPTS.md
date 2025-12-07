# Agent Prompts (English)

Use these prompts to keep extraction and consolidation consistent.

## Extractor Agent (per batch in `02_IN_PROGRESS/`)
Goal: Parse Lua scripts and emit raw, unopinionated examples into `RAW_NOTES/` (one JSON per source file).

Key rules:
- Do not rewrite or simplify code; capture it as-is.
- Collect all symbol usages (functions, methods, callbacks, globals, constants).
- Include minimal surrounding context if it clarifies parameters/returns.
- No deduplication at this stage.

Suggested prompt:
```
You are an Extractor. Input: one Lua file. Output: a JSON array of example records.
For each symbol usage you see, append:
{
  "symbol": "<library_or_class_or_global.name>",
  "source_file": "<input filename>",
  "example": "<verbatim Lua snippet>",
  "notes": "<optional short note if needed>"
}
Do not invent symbols. Keep code verbatim.
```

## RAW_NOTES JSON shape
- File per source script: `RAW_NOTES/<original_name>.json`
- Content: JSON array of objects with keys:
  - `symbol` (string)
  - `source_file` (string)
  - `example` (string; verbatim Lua)
  - `notes` (string, optional)

## Consolidator Agent (single agent for consistency)
Goal: Merge raw notes by symbol into curated Markdown in `data/smart_context/`.

Process (per symbol):
1) Load all RAW_NOTES entries for that symbol.
2) Call `get_types(symbol)` (or simulate if offline) and fill header fields:
   - Signature
   - Required Context (types/constants)
3) Select the best 1–3 unique examples; drop duplicates.
4) Flag conflicts under `DO_MANUAL_REVIEW` if types/behavior disagree.
5) Save to `data/smart_context/{symbol}.md`.

Required Markdown schema:
```
## Function/Symbol: <symbol>
> Signature: <from get_types>

### Required Context (from get_types):
- Types: <from get_types>
- Notes: Use this context when writing code with this symbol.

### Curated Usage Examples:
#### 1. Standard
```lua
<clean example>
```

#### 2. Complex / Edge Case
```lua
<edge example>
```

#### DO_MANUAL_REVIEW (optional)
- <list conflicts or uncertainties>
```

## Final placement
- Curated files live in `data/smart_context/`.
- If a symbol is custom (not in docs), still follow the same schema and include the best known implementations.

