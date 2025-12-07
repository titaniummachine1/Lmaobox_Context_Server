#!/usr/bin/env python
"""
Validate extracted JSON files in RAW_NOTES/ for proper schema.

Usage:
    python scripts/validate_extractions.py [--fix]
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
RAW_NOTES = REPO_ROOT / "RAW_NOTES"

REQUIRED_FIELDS = {"symbol", "source_file", "example"}
OPTIONAL_FIELDS = {"line_number", "context", "notes"}

def validate_json_file(path: Path) -> tuple[bool, list[str]]:
    """Validate a JSON extraction file."""
    errors = []
    
    try:
        with open(path, "r", encoding="utf-8") as f:
            data = json.load(f)
    except json.JSONDecodeError as e:
        return False, [f"Invalid JSON: {e}"]
    except Exception as e:
        return False, [f"Error reading file: {e}"]

    if not isinstance(data, list):
        return False, ["Root must be a JSON array"]

    for i, item in enumerate(data):
        if not isinstance(item, dict):
            errors.append(f"Item {i}: must be an object")
            continue

        # Check required fields
        for field in REQUIRED_FIELDS:
            if field not in item:
                errors.append(f"Item {i}: missing required field '{field}'")

        # Check for unknown fields
        all_fields = REQUIRED_FIELDS | OPTIONAL_FIELDS
        for field in item.keys():
            if field not in all_fields:
                errors.append(f"Item {i}: unknown field '{field}'")

        # Validate field types
        if "symbol" in item and not isinstance(item["symbol"], str):
            errors.append(f"Item {i}: 'symbol' must be a string")
        if "source_file" in item and not isinstance(item["source_file"], str):
            errors.append(f"Item {i}: 'source_file' must be a string")
        if "example" in item and not isinstance(item["example"], str):
            errors.append(f"Item {i}: 'example' must be a string")

    return len(errors) == 0, errors

def main():
    parser = argparse.ArgumentParser(description="Validate extracted JSON files")
    parser.add_argument("--fix", action="store_true", help="Attempt to fix common issues")
    args = parser.parse_args()

    if not RAW_NOTES.exists():
        print(f"RAW_NOTES directory not found: {RAW_NOTES}")
        sys.exit(1)

    json_files = sorted(RAW_NOTES.glob("*.json"))
    if not json_files:
        print("No JSON files found in RAW_NOTES/")
        sys.exit(0)

    print(f"Validating {len(json_files)} JSON files...\n")

    total_errors = 0
    valid_files = 0

    for json_file in json_files:
        is_valid, errors = validate_json_file(json_file)
        
        if is_valid:
            valid_files += 1
            print(f"✓ {json_file.name}")
        else:
            total_errors += len(errors)
            print(f"✗ {json_file.name}")
            for error in errors:
                print(f"    {error}")

    print(f"\nResults: {valid_files}/{len(json_files)} valid files")
    if total_errors > 0:
        print(f"Total errors: {total_errors}")
        sys.exit(1)
    else:
        print("All files valid!")

if __name__ == "__main__":
    main()

