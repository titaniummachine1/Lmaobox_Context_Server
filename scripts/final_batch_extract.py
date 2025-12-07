#!/usr/bin/env python3
"""
Comprehensive batch extraction - creates ALL JSON files in one pass
Then git commit the batch
"""
import json
import re
from pathlib import Path


def extract_file(path):
    """Extract all symbols from a Lua file - comprehensive approach"""
    content = path.read_text(encoding='utf-8', errors='ignore')
    lines = content.split('\n')

    symbols = {}  # Use dict to avoid duplicates

    for line_num, line in enumerate(lines, 1):
        # Skip pure comment lines
        if line.strip().startswith('--') or not line.strip():
            continue

        # Remove trailing comments
        code_part = line.split('--')[0] if '--' in line else line

        # Pattern 1: Function calls - word(...) or module.func(...) or obj:method(...)
        for m in re.finditer(r'\b([a-zA-Z_]\w*(?:[:.]\w+)*)\s*\(', code_part):
            sym = m.group(1)
            if sym not in symbols and len(sym) > 1:
                example = line.strip()
                if len(example) > 200:
                    example = example[:197] + "..."
                symbols[sym] = {
                    "symbol": sym,
                    "source_file": path.name,
                    "example": example,
                    "line_number": line_num
                }

        # Pattern 2: Constants E_XXX or IN_XXX
        for m in re.finditer(r'\b([EI][A-Z_][A-Z0-9_]*)\b', code_part):
            sym = m.group(1)
            if sym not in symbols:
                symbols[sym] = {
                    "symbol": sym,
                    "source_file": path.name,
                    "example": line.strip(),
                    "line_number": line_num
                }

    return list(symbols.values())


# Process ALL files
repo = Path('.')
to_proc = repo / 'processing_zone' / '01_TO_PROCESS'
raw = repo / 'processing_zone' / 'RAW_NOTES'

files = sorted(to_proc.glob('*.lua'))
results = {
    'created': [],
    'skipped': [],
    'errors': []
}

for f in files:
    out_name = f.stem
    out_path = raw / f"{out_name}.json"

    if out_path.exists():
        results['skipped'].append(f.name)
        continue

    try:
        syms = extract_file(f)
        out_path.write_text(json.dumps(syms, indent=2))
        results['created'].append((f.name, len(syms)))
    except Exception as e:
        results['errors'].append((f.name, str(e)))

# Save report
report = {
    'total_extracted': len(results['created']),
    'total_skipped': len(results['skipped']),
    'total_errors': len(results['errors']),
    'files_created': results['created'],
    'details': f"{len(results['created'])} new + {len(results['skipped'])} existing = {len(results['created']) + len(results['skipped'])} total"
}

# Write report to a file we can check
(repo / 'EXTRACTION_REPORT.json').write_text(json.dumps(report, indent=2))

print(json.dumps(report, indent=2))
