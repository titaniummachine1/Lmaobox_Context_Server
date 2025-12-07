#!/usr/bin/env python3
"""
Batch extraction script - processes all Lua files and creates JSON outputs
"""
import json
import re
from pathlib import Path
from collections import defaultdict


def extract_symbols_from_file(file_path):
    """Extract all symbols from a Lua file"""
    try:
        content = file_path.read_text(encoding='utf-8', errors='ignore')
        lines = content.split('\n')

        symbols = []
        seen = {}

        for line_num, line in enumerate(lines, 1):
            # Skip comment-only lines
            stripped = line.strip()
            if not stripped or stripped.startswith('--'):
                continue

            # Remove inline comments
            if '--' in line:
                line = line[:line.index('--')]

            # Extract function calls: word(...) or word.func(...) or word:method(...)
            matches = re.finditer(r'\b([a-zA-Z_]\w*(?:[:.]\w+)*)\s*\(', line)
            for match in matches:
                symbol = match.group(1)
                if symbol not in seen:
                    example = stripped
                    if len(example) > 180:
                        example = example[:177] + "..."

                    seen[symbol] = {
                        "symbol": symbol,
                        "source_file": file_path.name,
                        "example": example,
                        "line_number": line_num
                    }

            # Extract constants: E_XXX or IN_XXX
            for match in re.finditer(r'\b(E_[A-Z0-9_]+)\b', line):
                const = match.group(1)
                if const not in seen:
                    seen[const] = {
                        "symbol": const,
                        "source_file": file_path.name,
                        "example": stripped,
                        "line_number": line_num
                    }

        return list(seen.values())
    except Exception as e:
        print(f"Error processing {file_path.name}: {e}")
        return []

# Main execution


def main():
    repo = Path('.')
    to_process_dir = repo / 'processing_zone' / '01_TO_PROCESS'
    raw_notes_dir = repo / 'processing_zone' / 'RAW_NOTES'

    # Get all Lua files
    lua_files = sorted(to_process_dir.glob('*.lua'))

    extracted_count = 0
    skipped_count = 0

    for lua_file in lua_files:
        json_name = lua_file.stem
        json_path = raw_notes_dir / f"{json_name}.json"

        # Skip if already exists
        if json_path.exists():
            skipped_count += 1
            continue

        # Extract symbols
        symbols = extract_symbols_from_file(lua_file)

        # Write JSON
        try:
            json_path.write_text(json.dumps(symbols, indent=2))
            extracted_count += 1

            if extracted_count % 25 == 0:
                print(f"[{extracted_count}] {lua_file.name}")
        except Exception as e:
            print(f"Failed to write {json_name}: {e}")

    print(f"\nExtraction complete:")
    print(f"  Extracted: {extracted_count} files")
    print(f"  Skipped:   {skipped_count} files (already exist)")
    print(f"  Total:     {extracted_count + skipped_count} files")

    # Verify output
    json_files = list(raw_notes_dir.glob('*.json'))
    print(f"\nTotal JSON files in RAW_NOTES/: {len(json_files)}")


if __name__ == "__main__":
    main()
