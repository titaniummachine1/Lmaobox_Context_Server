#!/usr/bin/env python3
"""
Batch extract all Lua files from 01_TO_PROCESS to RAW_NOTES JSON.

This script:
1. Reads each .lua file from 01_TO_PROCESS/
2. Parses and extracts all symbol usages
3. Creates JSON in RAW_NOTES/
4. Moves processed files to 03_DONE/

Run: python scripts/batch_extract_all.py
"""

import os
import json
import re
from pathlib import Path
from typing import List, Dict, Any

REPO_ROOT = Path(__file__).resolve().parent.parent
TO_PROCESS = REPO_ROOT / "processing_zone" / "01_TO_PROCESS"
DONE = REPO_ROOT / "processing_zone" / "03_DONE"
RAW_NOTES = REPO_ROOT / "processing_zone" / "RAW_NOTES"

# Ensure directories exist
RAW_NOTES.mkdir(parents=True, exist_ok=True)
DONE.mkdir(parents=True, exist_ok=True)


def extract_symbols(lua_code: str, filename: str) -> List[Dict[str, Any]]:
    """Extract all symbol usages from Lua code."""
    examples = []
    lines = lua_code.split('\n')

    # Patterns to detect symbols
    patterns = [
        # API calls: module.Function(...) or module:Function(...)
        r'(\w+)(?:\.|\:)(\w+)\s*\(',
        # Callbacks: callbacks.Register/Unregister
        r'callbacks\.(?:Register|Unregister)',
        # Constants: E_ButtonCode.KEY_X, etc.
        r'(E_\w+\.\w+)',
        # Global functions: globals.TickCount(), engine.RandomInt(), etc.
        r'((?:globals|engine|input|draw|client|entities|models|callbacks|aimbot|party|steam|playerlist|clientstate)\.\w+)',
        # Method calls on objects: obj:MethodName()
        r':(\w+)\s*\(',
        # BitBuffer operations
        r'BitBuffer\s*\(',
    ]

    for line_num, line in enumerate(lines, 1):
        stripped = line.strip()

        # Skip comments and empty lines
        if not stripped or stripped.startswith('--'):
            continue

        # Look for various symbol patterns
        if re.search(r'\w+[\.:][\w]+\s*\(', line):
            # Function/method call
            matches = re.finditer(r'(\w+)(?:\.|\:)(\w+)', line)
            for match in matches:
                obj, method = match.groups()
                symbol = f"{obj}.{method}" if '.' in line[match.start(
                ):] else f"{obj}:{method}"

                # Extract the statement containing this call
                example = line.strip()
                if len(example) > 100:
                    example = example[:100] + "..."

                examples.append({
                    "symbol": symbol,
                    "source_file": filename,
                    "example": example,
                    "line_number": line_num
                })

        # Look for constant assignments
        if 'E_' in line and '=' in line:
            matches = re.finditer(r'(E_\w+(?:\.\w+)?)', line)
            for match in matches:
                const = match.group(1)
                examples.append({
                    "symbol": const,
                    "source_file": filename,
                    "example": line.strip()[:100],
                    "line_number": line_num
                })

        # Look for callbacks
        if 'callbacks' in line:
            matches = re.finditer(r'callbacks\.(Register|Unregister)', line)
            for match in matches:
                symbol = f"callbacks.{match.group(1)}"
                examples.append({
                    "symbol": symbol,
                    "source_file": filename,
                    "example": line.strip()[:100],
                    "line_number": line_num
                })

    return examples


def process_file(lua_file: Path) -> bool:
    """Process a single Lua file and create JSON."""
    try:
        # Read the Lua file
        with open(lua_file, 'r', encoding='utf-8', errors='ignore') as f:
            lua_code = f.read()

        # Extract symbols
        examples = extract_symbols(lua_code, lua_file.name)

        if not examples:
            examples = [{
                "symbol": "file_parsed",
                "source_file": lua_file.name,
                "example": f"File processed: {lua_file.name}",
                "line_number": 1,
                "notes": "No standard symbols detected"
            }]

        # Write JSON
        json_file = RAW_NOTES / f"{lua_file.stem}.json"
        with open(json_file, 'w', encoding='utf-8') as f:
            json.dump(examples, f, indent=2)

        # Move processed file to DONE
        done_file = DONE / lua_file.name
        done_file.write_bytes(lua_file.read_bytes())
        lua_file.unlink()

        return True
    except Exception as e:
        print(f"Error processing {lua_file.name}: {e}")
        return False


def main():
    """Process all Lua files."""
    lua_files = sorted(TO_PROCESS.glob("*.lua"))

    print(f"Found {len(lua_files)} Lua files to process")

    success_count = 0
    for idx, lua_file in enumerate(lua_files, 1):
        if process_file(lua_file):
            success_count += 1
            if idx % 50 == 0:
                print(
                    f"Progress: {idx}/{len(lua_files)} ({idx*100//len(lua_files)}%)")

    print(f"\nCompleted: {success_count}/{len(lua_files)} files")
    print(f"JSON files in RAW_NOTES: {len(list(RAW_NOTES.glob('*.json')))}")
    print(f"Files moved to 03_DONE: {len(list(DONE.glob('*.lua')))}")


if __name__ == "__main__":
    main()
