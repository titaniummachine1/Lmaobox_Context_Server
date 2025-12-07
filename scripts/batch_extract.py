#!/usr/bin/env python
"""
Batch extraction helper: Processes all Lua files in processing_zone/02_IN_PROGRESS/
and moves them to RAW_NOTES/ after extraction.

Usage:
    python scripts/batch_extract.py [--max-files N] [--dry-run]
"""

import argparse
import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TO_PROCESS = REPO_ROOT / "processing_zone" / "01_TO_PROCESS"
IN_PROGRESS = REPO_ROOT / "processing_zone" / "02_IN_PROGRESS"
DONE = REPO_ROOT / "processing_zone" / "03_DONE"
RAW_NOTES = REPO_ROOT / "RAW_NOTES"

def ensure_dirs():
    """Ensure all required directories exist."""
    for d in [IN_PROGRESS, DONE, RAW_NOTES]:
        d.mkdir(parents=True, exist_ok=True)

def list_lua_files(directory: Path) -> list[Path]:
    """List all .lua files in directory."""
    return sorted(directory.glob("*.lua"))

def move_files(source: Path, dest: Path, max_files: int = None):
    """Move Lua files from source to dest (up to max_files)."""
    files = list_lua_files(source)
    if max_files:
        files = files[:max_files]
    
    moved = []
    for f in files:
        dest_file = dest / f.name
        if not dest_file.exists():
            f.rename(dest_file)
            moved.append(dest_file)
    return moved

def count_extracted():
    """Count how many files have been extracted."""
    return len(list(RAW_NOTES.glob("*.json")))

def main():
    parser = argparse.ArgumentParser(description="Batch extraction helper")
    parser.add_argument("--max-files", type=int, help="Max files to move to IN_PROGRESS")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be done")
    args = parser.parse_args()

    ensure_dirs()

    # Move files from TO_PROCESS to IN_PROGRESS
    if args.dry_run:
        files = list_lua_files(TO_PROCESS)
        if args.max_files:
            files = files[:args.max_files]
        print(f"[DRY RUN] Would move {len(files)} files from 01_TO_PROCESS to 02_IN_PROGRESS")
        for f in files:
            print(f"  - {f.name}")
    else:
        moved = move_files(TO_PROCESS, IN_PROGRESS, args.max_files)
        print(f"Moved {len(moved)} files to 02_IN_PROGRESS/")

    # Status
    to_process_count = len(list_lua_files(TO_PROCESS))
    in_progress_count = len(list_lua_files(IN_PROGRESS))
    done_count = len(list_lua_files(DONE))
    extracted_count = count_extracted()

    print(f"\nStatus:")
    print(f"  To Process: {to_process_count}")
    print(f"  In Progress: {in_progress_count}")
    print(f"  Done: {done_count}")
    print(f"  Extracted (JSON): {extracted_count}")

if __name__ == "__main__":
    main()

