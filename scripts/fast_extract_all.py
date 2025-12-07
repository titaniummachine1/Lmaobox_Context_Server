import json
import re
from pathlib import Path


def extract_file(file_path):
    """Extract symbols from a single Lua file"""
    try:
        content = file_path.read_text(encoding='utf-8', errors='ignore')
        lines = content.split('\n')

        symbols = []
        seen = set()

        for line_num, line in enumerate(lines, 1):
            # Skip comments
            if line.strip().startswith('--'):
                continue

            # API function calls: xxx.function or xxx:method or global.function
            for match in re.finditer(r'([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*(?::[a-zA-Z_][a-zA-Z0-9_]*)?)\s*\(', line):
                symbol = match.group(1)
                if symbol not in seen and len(symbol) > 1:
                    seen.add(symbol)
                    example = line.strip()
                    if len(example) > 200:
                        example = example[:197] + "..."

                    symbols.append({
                        "symbol": symbol,
                        "source_file": file_path.name,
                        "example": example,
                        "line_number": line_num
                    })

            # Constants: E_XXX.YYY or IN_XXX
            for match in re.finditer(r'\b([A-Z_][A-Z0-9_]*(?:\.[A-Z_][A-Z0-9_]*)?)\b', line):
                symbol = match.group(1)
                if (symbol.startswith('E_') or symbol.startswith('IN_')) and symbol not in seen:
                    seen.add(symbol)
                    symbols.append({
                        "symbol": symbol,
                        "source_file": file_path.name,
                        "example": line.strip(),
                        "line_number": line_num
                    })

        return symbols
    except Exception as e:
        return []


# Main extraction
repo = Path('.')
to_process = repo / 'processing_zone' / '01_TO_PROCESS'
raw_notes = repo / 'processing_zone' / 'RAW_NOTES'

files = sorted([f for f in to_process.glob('*.lua')])
extracted_count = 0

for file_path in files:
    symbols = extract_file(file_path)
    json_name = file_path.stem

    # Skip if already exists
    json_file = raw_notes / f"{json_name}.json"
    if json_file.exists():
        continue

    # Write JSON
    try:
        json_file.write_text(json.dumps(symbols, indent=2))
        extracted_count += 1
        if extracted_count % 25 == 0:
            print(f"Extracted: {extracted_count} files")
    except Exception as e:
        print(f"Error writing {json_name}: {e}")

print(f"Total extracted: {extracted_count}")
