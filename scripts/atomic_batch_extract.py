#!/usr/bin/env python3
"""
Atomic batch extraction script for Lua files.
Follows the strict atomic workflow: Marker → Extract → Finalize
"""

import json
import re
from pathlib import Path
from typing import List, Dict, Any
import subprocess
import sys


class AtomicExtractor:
    def __init__(self, repo_root: str):
        self.repo_root = Path(repo_root)
        self.to_process = self.repo_root / "processing_zone" / "01_TO_PROCESS"
        self.in_progress = self.repo_root / "processing_zone" / "02_IN_PROGRESS"
        self.done = self.repo_root / "processing_zone" / "03_DONE"
        self.raw_notes = self.repo_root / "processing_zone" / "RAW_NOTES"
        self.stats = {"extracted": 0, "moved": 0, "committed": 0}

    def get_files_to_process(self) -> List[Path]:
        """Get sorted list of .lua files to process"""
        return sorted([f for f in self.to_process.glob("*.lua") if f.is_file()])

    def create_marker(self, filename: str) -> Path:
        """Step 1: Create processing marker"""
        marker_path = self.in_progress / f"{filename}.processing"
        marker_content = f"""# PROCESSING MARKER
# File: {filename}
# Status: IN PROGRESS
# Agent: BatchExtractor
"""
        marker_path.write_text(marker_content)
        return marker_path

    def commit_marker(self, filename: str):
        """Commit the marker file"""
        subprocess.run(
            ["git", "add",
                f"processing_zone/02_IN_PROGRESS/{filename}.processing"],
            cwd=self.repo_root,
            capture_output=True
        )
        subprocess.run(
            ["git", "commit", "-m", f"WIP: Extracting {filename}"],
            cwd=self.repo_root,
            capture_output=True
        )

    def extract_symbols(self, file_path: Path) -> List[Dict[str, Any]]:
        """Step 2: Extract all symbols from Lua file"""
        content = file_path.read_text(encoding='utf-8', errors='ignore')
        lines = content.split('\n')

        symbols = []
        seen = set()

        # Pattern for API calls: xxx.Yyy, xxx:Yyy, entities.GetLocalPlayer, etc.
        api_pattern = r'([a-zA-Z_][a-zA-Z0-9_]*(?:\.[a-zA-Z_][a-zA-Z0-9_]*)*(?::[a-zA-Z_][a-zA-Z0-9_]*)?)\s*\('

        for line_num, line in enumerate(lines, 1):
            # Skip comments
            if line.strip().startswith('--'):
                continue

            # Find API calls
            for match in re.finditer(api_pattern, line):
                symbol = match.group(1)
                if symbol not in seen:
                    seen.add(symbol)
                    # Get verbatim code
                    example = line.strip()
                    if len(example) > 150:
                        example = example[:150] + "..."

                    entry = {
                        "symbol": symbol,
                        "source_file": file_path.name,
                        "example": example,
                        "line_number": line_num
                    }
                    symbols.append(entry)

            # Find constants (E_XXX.YYY pattern)
            for match in re.finditer(r'(E_[A-Za-z_][A-Za-z0-9_]*(?:\.[A-Z_][A-Z0-9_]*)?)', line):
                symbol = match.group(1)
                if symbol not in seen:
                    seen.add(symbol)
                    entry = {
                        "symbol": symbol,
                        "source_file": file_path.name,
                        "example": line.strip(),
                        "line_number": line_num
                    }
                    symbols.append(entry)

        return symbols

    def create_json(self, filename: str, symbols: List[Dict[str, Any]]) -> bool:
        """Step 2b: Create and validate JSON"""
        output_path = self.raw_notes / f"{filename.replace('.lua', '')}.json"

        try:
            output_path.write_text(json.dumps(symbols, indent=2))
            # Validate
            json.loads(output_path.read_text())
            return True
        except Exception as e:
            print(f"JSON validation failed for {filename}: {e}")
            return False

    def finalize_extraction(self, filename: str) -> bool:
        """Step 3: Move file to 03_DONE and delete marker"""
        source = self.to_process / filename
        dest = self.done / filename
        marker = self.in_progress / f"{filename}.processing"

        try:
            # Move file
            source.rename(dest)
            # Delete marker
            marker.unlink(missing_ok=True)
            return True
        except Exception as e:
            print(f"Finalization failed for {filename}: {e}")
            return False

    def commit_extraction(self, filename: str, symbol_count: int):
        """Commit the completed extraction"""
        short_name = filename.replace('.lua', '')
        subprocess.run(
            ["git", "add", f"processing_zone/RAW_NOTES/{short_name}.json"],
            cwd=self.repo_root,
            capture_output=True
        )
        subprocess.run(
            ["git", "add", f"processing_zone/03_DONE/{filename}"],
            cwd=self.repo_root,
            capture_output=True
        )
        subprocess.run(
            ["git", "commit", "-m",
                f"Extract: {filename} → RAW_NOTES/{short_name}.json\n\n- Extracted {symbol_count} symbols\n- All examples verbatim\n- File moved to 03_DONE/"],
            cwd=self.repo_root,
            capture_output=True
        )

    def process_file(self, file_path: Path) -> bool:
        """Process a single file atomically"""
        filename = file_path.name

        try:
            # Step 1: Create and commit marker
            self.create_marker(filename)
            self.commit_marker(filename)

            # Step 2: Extract symbols
            symbols = self.extract_symbols(file_path)

            # Step 2b: Create JSON
            if not self.create_json(filename, symbols):
                return False

            # Step 3: Finalize
            if not self.finalize_extraction(filename):
                return False

            # Step 3b: Commit
            self.commit_extraction(filename, len(symbols))

            self.stats["extracted"] += 1
            print(f"✓ {filename} ({len(symbols)} symbols)")
            return True

        except Exception as e:
            print(f"✗ {filename}: {e}")
            return False

    def run_batch(self, max_files: int = None):
        """Process batch of files"""
        files = self.get_files_to_process()

        if max_files:
            files = files[:max_files]

        print(f"Processing {len(files)} files...")
        for i, file_path in enumerate(files, 1):
            self.process_file(file_path)
            if i % 10 == 0:
                print(f"Progress: {i}/{len(files)}")

        print(f"\nBatch complete: {self.stats['extracted']} files extracted")


if __name__ == "__main__":
    extractor = AtomicExtractor(".")
    max_files = int(sys.argv[1]) if len(sys.argv) > 1 else None
    extractor.run_batch(max_files)
