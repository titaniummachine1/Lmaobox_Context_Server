#!/usr/bin/env python3
"""Force extract ALL files - no skipping."""
import json
import re
import shutil
from pathlib import Path

TO_PROCESS = Path("processing_zone/01_TO_PROCESS")
DONE = Path("processing_zone/03_DONE")
RAW_NOTES = Path("processing_zone/RAW_NOTES")

RAW_NOTES.mkdir(parents=True, exist_ok=True)
DONE.mkdir(parents=True, exist_ok=True)


def extract(content, filename):
    examples = []
    lines = content.split('\n')
    seen = set()

    api_ns = ['engine', 'entities', 'globals', 'callbacks', 'draw', 'input', 'client', 'render', 'utils', 'gui', 'models', 'aimbot',
              'party', 'playerlist', 'steam', 'gamerules', 'clientstate', 'msg', 'string', 'table', 'math', 'Vector3', 'BitBuffer']

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
            if '_' in const and const not in ['LUA', 'API', 'HTTP', 'XML', 'HTML', 'SVG', 'IF', 'THEN', 'END', 'FOR', 'DO', 'WHILE', 'AND', 'OR', 'NOT']:
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


# Get ALL files - no skipping
files = sorted([f for f in TO_PROCESS.glob("*.lua") if f.name != '.gitkeep'])

print(f"Processing {len(files)} files...")

success = 0
for i, f in enumerate(files, 1):
    try:
        content = f.read_text(encoding='utf-8', errors='ignore')
        examples = extract(content, f.name)

        json_file = RAW_NOTES / f"{f.stem}.json"
        json_file.write_text(json.dumps(examples, indent=2), encoding='utf-8')

        done_file = DONE / f.name
        shutil.move(str(f), str(done_file))

        success += 1
        if i % 25 == 0:
            print(f"Progress: {i}/{len(files)} ({i*100//len(files)}%)")
    except Exception as e:
        print(f"ERROR {f.name}: {e}")

print(f"\nComplete! Processed {success}/{len(files)} files")
print(f"JSON files: {len(list(RAW_NOTES.glob('*.json')))}")
print(f"Files in DONE: {len(list(DONE.glob('*.lua')))}")
