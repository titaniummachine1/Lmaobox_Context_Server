#!/usr/bin/env python3
"""Direct extraction - no dependencies, just works."""
import json
import re
from pathlib import Path

TO_PROCESS = Path("processing_zone/01_TO_PROCESS")
DONE = Path("processing_zone/03_DONE")
RAW_NOTES = Path("processing_zone/RAW_NOTES")

RAW_NOTES.mkdir(parents=True, exist_ok=True)
DONE.mkdir(parents=True, exist_ok=True)


def extract(content, filename):
    """Extract symbols from Lua."""
    examples = []
    lines = content.split('\n')
    seen = set()

    api_ns = ['engine', 'entities', 'globals', 'callbacks', 'draw', 'input', 'client', 'render', 'utils', 'gui',
              'models', 'aimbot', 'party', 'playerlist', 'steam', 'gamerules', 'clientstate', 'msg', 'string', 'table', 'math']

    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()
        if not stripped or stripped.startswith('--'):
            continue

        # API namespace calls
        for ns in api_ns:
            for m in re.finditer(rf'\b{re.escape(ns)}\.([A-Za-z_][A-Za-z0-9_]*)', line):
                symbol = m.group(0)
                key = f"{symbol}:{line_num}"
                if key not in seen:
                    seen.add(key)
                    examples.append({
                        "symbol": symbol,
                        "source_file": filename,
                        "example": stripped[:200],
                        "line_number": line_num
                    })

        # Method calls var:Method
        for m in re.finditer(r'\b([A-Za-z_][A-Za-z0-9_]*):([A-Za-z_][A-Za-z0-9_]*)', line):
            symbol = f"{m.group(1)}:{m.group(2)}"
            key = f"{symbol}:{line_num}"
            if key not in seen:
                seen.add(key)
                examples.append({
                    "symbol": symbol,
                    "source_file": filename,
                    "example": stripped[:200],
                    "line_number": line_num
                })

        # Constants
        for m in re.finditer(r'\b([A-Z][A-Z0-9_]{2,}|E_[A-Z0-9_]+)\b', line):
            const = m.group(1)
            if '_' in const and const not in ['LUA', 'API', 'HTTP', 'XML', 'HTML', 'SVG', 'IF', 'THEN', 'END', 'FOR', 'DO', 'WHILE']:
                key = f"{const}:{line_num}"
                if key not in seen:
                    seen.add(key)
                    examples.append({
                        "symbol": const,
                        "source_file": filename,
                        "example": stripped[:200],
                        "line_number": line_num
                    })

    return examples if examples else [{"symbol": "file_processed", "source_file": filename, "example": "File processed", "line_number": 1}]


# Process all files
files = sorted(TO_PROCESS.glob("*.lua"))
done_stems = {f.stem for f in DONE.glob("*.lua")}
to_do = [f for f in files if f.stem not in done_stems]

print(f"Processing {len(to_do)} files...")

for i, f in enumerate(to_do, 1):
    try:
        content = f.read_text(encoding='utf-8', errors='ignore')
        examples = extract(content, f.name)

        json_file = RAW_NOTES / f"{f.stem}.json"
        json_file.write_text(json.dumps(examples, indent=2), encoding='utf-8')

        done_file = DONE / f.name
        f.rename(done_file)

        if i % 20 == 0:
            print(f"Progress: {i}/{len(to_do)}")
    except Exception as e:
        print(f"Error {f.name}: {e}")

print(f"\nDone! Processed {len(to_do)} files")
print(f"JSON: {len(list(RAW_NOTES.glob('*.json')))}")
print(f"DONE: {len(list(DONE.glob('*.lua')))}")
