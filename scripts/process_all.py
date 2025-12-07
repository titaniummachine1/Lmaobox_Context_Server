#!/usr/bin/env python
"""Process ALL remaining files until done."""
import json
import re
import shutil
import sys
from pathlib import Path
from datetime import datetime

REPO_ROOT = Path(__file__).resolve().parent.parent
TO_PROCESS = REPO_ROOT / "processing_zone" / "01_TO_PROCESS"
IN_PROGRESS = REPO_ROOT / "processing_zone" / "02_IN_PROGRESS"
DONE = REPO_ROOT / "processing_zone" / "03_DONE"
RAW_NOTES = REPO_ROOT / "processing_zone" / "RAW_NOTES"
STATUS_FILE = REPO_ROOT / "processing_zone" / "STATUS.txt"


def extract_symbols(content: str, filename: str):
    """Extract all API symbols from Lua code."""
    examples = []
    lines = content.split('\n')
    seen = set()

    api_namespaces = ['engine', 'entities', 'globals',
                      'callbacks', 'draw', 'input', 'client', 'render', 'utils']

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
        for match in re.finditer(r'\b([A-Z][A-Z0-9_]{2,})\b', line):
            const = match.group(1)
            if '_' in const and const not in ['LUA', 'API', 'HTTP', 'XML', 'HTML', 'SVG']:
                key = f"{const}:{line_num}"
                if key not in seen:
                    seen.add(key)
                    examples.append({
                        "symbol": const,
                        "source_file": filename,
                        "example": stripped,
                        "line_number": line_num
                    })

        # require()
        for match in re.finditer(r'\brequire\s*\(["\']([^"\']+)["\']\)', line):
            symbol = f"require({match.group(1)})"
            key = f"{symbol}:{line_num}"
            if key not in seen:
                seen.add(key)
                examples.append({
                    "symbol": symbol,
                    "source_file": filename,
                    "example": stripped,
                    "line_number": line_num
                })

    return examples


def update_status(processed, total, current_file=""):
    """Update status file."""
    status = f"""Extraction Status
================
Processed: {processed} / {total}
Current: {current_file}
Last Update: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}
"""
    STATUS_FILE.write_text(status)


def main():
    """Process all files."""
    IN_PROGRESS.mkdir(parents=True, exist_ok=True)
    DONE.mkdir(parents=True, exist_ok=True)
    RAW_NOTES.mkdir(parents=True, exist_ok=True)

    # Get all files
    all_files = sorted(TO_PROCESS.glob("*.lua"))
    done_stems = {f.stem for f in DONE.glob("*.lua")}
    files_to_process = [f for f in all_files if f.stem not in done_stems]

    total = len(files_to_process)
    processed = 0

    print(f"Processing {total} files...")
    sys.stdout.flush()

    for lua_file in files_to_process:
        try:
            update_status(processed, total, lua_file.name)

            # Move to IN_PROGRESS
            in_progress_file = IN_PROGRESS / lua_file.name
            if lua_file.exists():
                shutil.move(str(lua_file), str(in_progress_file))

            # Read and extract
            content = in_progress_file.read_text(
                encoding='utf-8', errors='ignore')
            examples = extract_symbols(content, lua_file.name)

            # Write JSON
            json_file = RAW_NOTES / f"{lua_file.stem}.json"
            with open(json_file, 'w', encoding='utf-8') as f:
                json.dump(examples, f, indent=2, ensure_ascii=False)

            # Move to DONE
            done_file = DONE / lua_file.name
            if in_progress_file.exists():
                shutil.move(str(in_progress_file), str(done_file))

            processed += 1
            if processed % 10 == 0:
                print(
                    f"Progress: {processed}/{total} ({processed*100//total}%)")
                sys.stdout.flush()

        except Exception as e:
            print(f"ERROR processing {lua_file.name}: {e}", file=sys.stderr)
            sys.stderr.flush()

    update_status(processed, total, "COMPLETE")
    print(f"\nComplete! Processed {processed}/{total} files")
    print(f"JSON files in RAW_NOTES: {len(list(RAW_NOTES.glob('*.json')))}")
    print(f"Files in 03_DONE: {len(list(DONE.glob('*.lua')))}")


if __name__ == "__main__":
    main()
