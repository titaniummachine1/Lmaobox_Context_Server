#!/usr/bin/env python
"""Process a batch of Lua files with visible logging."""
import json
import re
import shutil
from pathlib import Path
from datetime import datetime

REPO_ROOT = Path(__file__).resolve().parent.parent
TO_PROCESS = REPO_ROOT / "processing_zone" / "01_TO_PROCESS"
IN_PROGRESS = REPO_ROOT / "processing_zone" / "02_IN_PROGRESS"
DONE = REPO_ROOT / "processing_zone" / "03_DONE"
RAW_NOTES = REPO_ROOT / "RAW_NOTES"
LOG_FILE = REPO_ROOT / "processing_zone" / "extraction_log.txt"


def log(msg):
    """Write to both console and log file."""
    timestamp = datetime.now().strftime("%H:%M:%S")
    line = f"[{timestamp}] {msg}"
    print(line)
    with open(LOG_FILE, 'a', encoding='utf-8') as f:
        f.write(line + '\n')


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
            if '_' in const and const not in ['LUA', 'API', 'HTTP']:
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


def main():
    """Process files in batches."""
    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    IN_PROGRESS.mkdir(parents=True, exist_ok=True)
    DONE.mkdir(parents=True, exist_ok=True)
    RAW_NOTES.mkdir(parents=True, exist_ok=True)

    log("=" * 60)
    log("Starting batch extraction")

    # Check what's already done
    done_stems = {f.stem for f in DONE.glob("*.lua")}
    log(f"Already processed: {len(done_stems)} files")

    # Get files to process
    all_files = sorted(TO_PROCESS.glob("*.lua"))
    files_to_process = [f for f in all_files if f.stem not in done_stems]

    if not files_to_process:
        log("No files to process!")
        return

    # Process batch of 20
    batch = files_to_process[:20]
    log(f"Processing batch of {len(batch)} files")

    for lua_file in batch:
        try:
            log(f"Processing: {lua_file.name}")

            # Move to IN_PROGRESS
            in_progress_file = IN_PROGRESS / lua_file.name
            shutil.move(str(lua_file), str(in_progress_file))
            log(f"  Moved to 02_IN_PROGRESS")

            # Read and extract
            content = in_progress_file.read_text(
                encoding='utf-8', errors='ignore')
            examples = extract_symbols(content, lua_file.name)
            log(f"  Extracted {len(examples)} symbols")

            # Write JSON
            json_file = RAW_NOTES / f"{lua_file.stem}.json"
            with open(json_file, 'w', encoding='utf-8') as f:
                json.dump(examples, f, indent=2, ensure_ascii=False)
            log(f"  Created {json_file.name}")

            # Move to DONE
            done_file = DONE / lua_file.name
            shutil.move(str(in_progress_file), str(done_file))
            log(f"  Moved to 03_DONE")
            log(f"  ✓ Complete")

        except Exception as e:
            log(f"  ✗ ERROR: {e}")
            import traceback
            traceback.print_exc()

    remaining = len([f for f in TO_PROCESS.glob(
        "*.lua") if f.stem not in done_stems])
    log(f"\nBatch complete. Remaining: {remaining} files")
    log("=" * 60)


if __name__ == "__main__":
    main()

