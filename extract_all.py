#!/usr/bin/env python3
import json
import re
from pathlib import Path


def extract_from_lua(content, filename):
    """Extract API usage patterns from Lua code."""
    entries = []
    lines = content.split('\n')

    for line_num, line in enumerate(lines, 1):
        # Skip empty lines and comments
        stripped = line.strip()
        if not stripped or stripped.startswith('--'):
            continue

        # Find all identifier patterns that look like API calls
        # Pattern: word.word or word:word or word.word.word etc
        for match in re.finditer(r'\b([a-zA-Z_][a-zA-Z0-9_]*(?:[.:][ a-zA-Z_][a-zA-Z0-9_]*)*)\b', line):
            symbol = match.group(1)
            # Filter out Lua keywords
            if symbol not in ['if', 'then', 'else', 'end', 'local', 'function', 'return', 'for', 'do', 'while', 'in', 'pairs', 'ipairs', 'and', 'or', 'not']:
                if '.' in symbol or ':' in symbol:  # Only save API-like patterns
                    entries.append({
                        'symbol': symbol,
                        'source_file': filename,
                        'example': stripped,
                        'line_number': line_num
                    })

    return entries


def main():
    base = Path('.')
    to_proc = base / 'processing_zone' / '01_TO_PROCESS'

    # List files (without using glob which seems to have issues)
    try:
        files = [f for f in to_proc.iterdir() if f.suffix ==
                 '.lua' and f.name != '.gitkeep']
        files.sort()

        print(f"Found {len(files)} files to process")

        for i, lua_file in enumerate(files, 1):
            try:
                with open(lua_file, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()

                entries = extract_from_lua(content, lua_file.name)

                # Save JSON
                json_path = base / 'processing_zone' / \
                    'RAW_NOTES' / f"{lua_file.stem}.json"
                with open(json_path, 'w') as f:
                    json.dump(entries, f, indent=2)

                # Move to done
                done_path = base / 'processing_zone' / '03_DONE' / lua_file.name
                lua_file.rename(done_path)

                if i % 10 == 0:
                    print(f"Processed {i}/{len(files)}")

            except Exception as e:
                print(f"Error processing {lua_file.name}: {e}")

        print(f"✅ Completed all {len(files)} files")

    except Exception as e:
        print(f"Error: {e}")


if __name__ == '__main__':
    main()
