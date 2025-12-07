#!/usr/bin/env python3
"""Extract with explicit logging to file."""
import json
import re
import shutil
from pathlib import Path
from datetime import datetime

TO_PROCESS = Path("processing_zone/01_TO_PROCESS")
DONE = Path("processing_zone/03_DONE")
RAW_NOTES = Path("processing_zone/RAW_NOTES")
LOG_FILE = Path("extraction_log.txt")

# Clear log
LOG_FILE.write_text(f"Extraction started: {datetime.now()}\n\n")


def log(msg):
    """Write to log file and print."""
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(f"{msg}\n")
    print(msg)


def extract(content, filename):
    """Extract symbols."""
    examples = []
    lines = content.split('\n')
    seen = set()

    api_ns = ['engine', 'entities', 'globals', 'callbacks', 'draw', 'input', 'client', 'render', 'utils',
              'gui', 'models', 'aimbot', 'party', 'playerlist', 'steam', 'gamerules', 'clientstate', 'msg']

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

        # Method calls
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

    return examples if examples else [{"symbol": "file_processed", "source_file": filename, "example": "File processed", "line_number": 1}]


# Ensure directories exist
RAW_NOTES.mkdir(parents=True, exist_ok=True)
DONE.mkdir(parents=True, exist_ok=True)

# Get files
files = sorted([f for f in TO_PROCESS.glob("*.lua") if f.name != '.gitkeep'])
log(f"Found {len(files)} files to process")

success = 0
errors = 0

for i, f in enumerate(files, 1):
    try:
        log(f"[{i}/{len(files)}] Processing: {f.name}")

        # Read
        content = f.read_text(encoding='utf-8', errors='ignore')
        log(f"  Read {len(content)} characters")

        # Extract
        examples = extract(content, f.name)
        log(f"  Extracted {len(examples)} symbols")

        # Write JSON
        json_file = RAW_NOTES / f"{f.stem}.json"
        json_file.write_text(json.dumps(examples, indent=2), encoding='utf-8')
        log(f"  Created: {json_file}")

        # Move file
        done_file = DONE / f.name
        shutil.move(str(f), str(done_file))
        log(f"  Moved to: {done_file}")

        success += 1

        if i % 25 == 0:
            log(f"\nProgress: {i}/{len(files)} ({i*100//len(files)}%) - {success} success, {errors} errors\n")

    except Exception as e:
        errors += 1
        log(f"  ERROR: {e}")
        import traceback
        log(traceback.format_exc())

log(f"\n=== COMPLETE ===")
log(f"Processed: {success}/{len(files)}")
log(f"Errors: {errors}")
log(f"JSON files: {len(list(RAW_NOTES.glob('*.json')))}")
log(f"Files in DONE: {len(list(DONE.glob('*.lua')))}")
log(f"Finished: {datetime.now()}")

