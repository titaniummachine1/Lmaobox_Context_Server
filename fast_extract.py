#!/usr/bin/env python3
"""Fast batch extraction - processes ALL files without printing delays."""
import json
import re
import shutil
from pathlib import Path

TO_PROCESS = Path("processing_zone/01_TO_PROCESS")
DONE = Path("processing_zone/03_DONE")
RAW_NOTES = Path("processing_zone/RAW_NOTES")
IN_PROGRESS = Path("processing_zone/02_IN_PROGRESS")


def extract_symbols(content, filename):
    """Extract symbols from Lua code."""
    examples = []
    lines = content.split('\n')
    seen = set()

    api_namespaces = ['engine', 'entities', 'globals', 'callbacks', 'draw', 'input', 'client', 'render',
                      'utils', 'gui', 'models', 'aimbot', 'party', 'playerlist', 'steam', 'gamerules', 'clientstate', 'msg']

    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith('--'):
            continue

        # API namespace calls
        for ns in api_namespaces:
            for match in re.finditer(rf'\b{re.escape(ns)}\.([A-Za-z_][A-Za-z0-9_]*)', line):
                symbol = match.group(0)
                key = f"{symbol}:{line_num}"
                if key not in seen:
                    seen.add(key)
                    examples.append({
                        "symbol": symbol,
                        "source_file": filename,
                        "example": stripped,
                        "line_number": line_num
                    })

        # Method calls (var:Method)
        for match in re.finditer(r'\b([A-Za-z_][A-Za-z0-9_]*):([A-Za-z_][A-Za-z0-9_]*)', line):
            symbol = f"{match.group(1)}:{match.group(2)}"
            key = f"{symbol}:{line_num}"
            if key not in seen:
                seen.add(key)
                examples.append({
                    "symbol": symbol,
                    "source_file": filename,
                    "example": stripped,
                    "line_number": line_num
                })

        # Constants
        for match in re.finditer(r'\b([A-Z][A-Z0-9_]{2,}|E_[A-Z0-9_]+)\b', line):
            const = match.group(1)
            key = f"{const}:{line_num}"
            if key not in seen:
                seen.add(key)
                examples.append({
                    "symbol": const,
                    "source_file": filename,
                    "example": stripped,
                    "line_number": line_num
                })

    return examples


# Make directories
DONE.mkdir(parents=True, exist_ok=True)
RAW_NOTES.mkdir(parents=True, exist_ok=True)
IN_PROGRESS.mkdir(parents=True, exist_ok=True)

# Get all Lua files
all_files = sorted(TO_PROCESS.glob("*.lua"))
done_stems = {f.stem for f in DONE.glob("*.lua")}
to_process_files = [f for f in all_files if f.stem not in done_stems]

# Process each file
for lua_file in to_process_files:
    try:
        # Read
        content = lua_file.read_text(encoding='utf-8', errors='ignore')
        examples = extract_symbols(content, lua_file.name)

        # Write JSON
        json_file = RAW_NOTES / f"{lua_file.stem}.json"
        json_file.write_text(json.dumps(
            examples, indent=2, ensure_ascii=False), encoding='utf-8')

        # Move to done
        done_file = DONE / lua_file.name
        lua_file.rename(done_file)
    except:
        pass

# Stats
json_count = len(list(RAW_NOTES.glob("*.json")))
done_count = len(list(DONE.glob("*.lua")))
to_proc_count = len(list(TO_PROCESS.glob("*.lua")))

# Write summary
summary = f"Extraction Complete\n\nProcessed: {done_count}\nJSON: {json_count}\nRemaining in TO_PROCESS: {to_proc_count}\n"
Path("EXTRACTION_SUMMARY.txt").write_text(summary)
