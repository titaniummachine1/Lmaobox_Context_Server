#!/usr/bin/env python
"""Check extraction status - see what's done, what's in progress, what needs work."""
import json
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TO_PROCESS = REPO_ROOT / "processing_zone" / "01_TO_PROCESS"
IN_PROGRESS = REPO_ROOT / "processing_zone" / "02_IN_PROGRESS"
DONE = REPO_ROOT / "processing_zone" / "03_DONE"
RAW_NOTES = REPO_ROOT / "RAW_NOTES"


def get_lua_files(directory):
    """Get all .lua files in directory."""
    return sorted(directory.glob("*.lua")) if directory.exists() else []


def get_json_files(directory):
    """Get all .json files in directory."""
    return sorted(directory.glob("*.json")) if directory.exists() else []


def main():
    to_process = get_lua_files(TO_PROCESS)
    in_progress = get_lua_files(IN_PROGRESS)
    done = get_lua_files(DONE)
    extracted = get_json_files(RAW_NOTES)

    # Map extracted JSON to source file names
    extracted_names = {f.stem for f in extracted}

    print(f"=== Extraction Status ===")
    print(f"\nFiles to process: {len(to_process)}")
    print(f"Files in progress: {len(in_progress)}")
    print(f"Files done: {len(done)}")
    print(f"Files extracted (JSON): {len(extracted)}")

    # Find files that need processing
    to_process_names = {f.stem for f in to_process}
    unprocessed = to_process_names - extracted_names

    print(f"\nUnprocessed files (no JSON yet): {len(unprocessed)}")
    if unprocessed:
        print("\nFirst 10 unprocessed:")
        for name in sorted(list(unprocessed))[:10]:
            print(f"  - {name}.lua")

    # Files in progress
    if in_progress:
        print(f"\nFiles currently in 02_IN_PROGRESS:")
        for f in in_progress:
            print(f"  - {f.name}")


if __name__ == "__main__":
    main()

