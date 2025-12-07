#!/usr/bin/env python
"""Check extraction status."""
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
TO_PROCESS = REPO_ROOT / "processing_zone" / "01_TO_PROCESS"
IN_PROGRESS = REPO_ROOT / "processing_zone" / "02_IN_PROGRESS"
DONE = REPO_ROOT / "processing_zone" / "03_DONE"
RAW_NOTES = REPO_ROOT / "RAW_NOTES"

to_count = len(list(TO_PROCESS.glob("*.lua")))
in_count = len(list(IN_PROGRESS.glob("*.lua")))
done_count = len(list(DONE.glob("*.lua")))
json_count = len(list(RAW_NOTES.glob("*.json")))

print(f"Status:")
print(f"  01_TO_PROCESS: {to_count} files")
print(f"  02_IN_PROGRESS: {in_count} files")
print(f"  03_DONE: {done_count} files")
print(f"  RAW_NOTES: {json_count} JSON files")
print(f"\nProgress: {done_count} / {to_count + done_count} processed")

