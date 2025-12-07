# Processing Zone Workflow

English-only guide for batching raw scripts and consolidating smart context.

## Folders
- `01_TO_PROCESS/` — drop source scripts to be parsed.
- `02_IN_PROGRESS/` — work-in-progress items while agents parse/clean.
- `03_DONE/` — finished, ready-to-ingest artifacts (e.g., cleaned JSON/MD).
- `../RAW_NOTES/` — raw JSON notes per script (one file per source).

Empty folders are tracked via `.gitkeep`.

## Suggested flow
1) Copy Lua scripts into `01_TO_PROCESS/`.
2) Move a batch into `02_IN_PROGRESS/` while agents extract examples.
3) Store raw extraction output in `RAW_NOTES/` (JSON per script/symbol).
4) Consolidate to markdown smart-context files and place final outputs in `03_DONE/` or directly into `data/smart_context/`.

Keep naming predictable; avoid spaces in filenames.***

