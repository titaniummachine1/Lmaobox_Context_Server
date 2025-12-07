#!/usr/bin/env python
"""
Extract API usage examples from Lua files.
Processes files in 02_IN_PROGRESS and creates JSON in RAW_NOTES/.
Comprehensive extraction of all API symbols, methods, constants, and custom functions.
"""

import json
import re
import sys
from pathlib import Path
from typing import List, Dict, Any, Set
from datetime import datetime

REPO_ROOT = Path(__file__).resolve().parent.parent
IN_PROGRESS = REPO_ROOT / "processing_zone" / "02_IN_PROGRESS"
DONE = REPO_ROOT / "processing_zone" / "03_DONE"
RAW_NOTES = REPO_ROOT / "RAW_NOTES"
LOCK_FILE = REPO_ROOT / "processing_zone" / ".extraction_lock"

# Known API namespaces
API_NAMESPACES = [
    'engine', 'entities', 'globals', 'callbacks', 'draw', 'input',
    'client', 'render', 'utils', 'console', 'file', 'http', 'json',
    'steam', 'network', 'cvar', 'material', 'model', 'sound'
]

# Known class types
CLASS_TYPES = ['Entity', 'Vector3', 'Angle',
               'QAngle', 'Color', 'Matrix3x4', 'CUserCmd']


def acquire_lock(agent_id: str = "default") -> bool:
    """Acquire lock to prevent concurrent processing."""
    if LOCK_FILE.exists():
        try:
            lock_data = json.loads(LOCK_FILE.read_text())
            lock_time = datetime.fromisoformat(lock_data['timestamp'])
            # Lock expires after 5 minutes
            if (datetime.now() - lock_time).seconds < 300:
                print(
                    f"Lock held by {lock_data['agent']} since {lock_data['timestamp']}")
                return False
        except:
            pass

    LOCK_FILE.write_text(json.dumps({
        'agent': agent_id,
        'timestamp': datetime.now().isoformat()
    }))
    return True


def release_lock():
    """Release the lock."""
    if LOCK_FILE.exists():
        LOCK_FILE.unlink()


def get_surrounding_context(lines: List[str], line_num: int, context_lines: int = 3) -> str:
    """Get surrounding code context."""
    start = max(0, line_num - context_lines - 1)
    end = min(len(lines), line_num + context_lines)
    return '\n'.join(lines[start:end])


def extract_symbols_from_code(content: str, filename: str) -> List[Dict[str, Any]]:
    """Extract all API symbol usages from Lua code."""
    examples = []
    lines = content.split('\n')
    seen_examples: Set[str] = set()  # Track to avoid exact duplicates

    for line_num, line in enumerate(lines, 1):
        original_line = line
        stripped = line.strip()

        # Skip empty lines and pure comments
        if not stripped or stripped.startswith('--'):
            continue

        # 1. Extract API namespace function calls (engine.Function, entities.Function, etc.)
        for namespace in API_NAMESPACES:
            pattern = rf'\b{re.escape(namespace)}\.([A-Za-z_][A-Za-z0-9_]*)'
            for match in re.finditer(pattern, line):
                symbol = match.group(0)
                example_key = f"{symbol}:{line_num}"
                if example_key not in seen_examples:
                    seen_examples.add(example_key)
                    examples.append({
                        "symbol": symbol,
                        "source_file": filename,
                        "example": stripped,
                        "line_number": line_num
                    })

        # 2. Extract method calls on variables (player:Method(), vec:Method(), etc.)
        # Pattern: identifier:MethodName(...)
        method_pattern = r'\b([A-Za-z_][A-Za-z0-9_]*):([A-Za-z_][A-Za-z0-9_]*)'
        for match in re.finditer(method_pattern, line):
            var_name = match.group(1)
            method_name = match.group(2)
            # Skip if it's a known class type (we'll catch those separately)
            if var_name not in CLASS_TYPES:
                symbol = f"{var_name}:{method_name}"
                example_key = f"{symbol}:{line_num}"
                if example_key not in seen_examples:
                    seen_examples.add(example_key)
                    examples.append({
                        "symbol": symbol,
                        "source_file": filename,
                        "example": stripped,
                        "line_number": line_num
                    })

        # 3. Extract class method calls (Entity:Method, Vector3:Method, etc.)
        for class_type in CLASS_TYPES:
            pattern = rf'\b{re.escape(class_type)}:([A-Za-z_][A-Za-z0-9_]*)'
            for match in re.finditer(pattern, line):
                symbol = f"{class_type}:{match.group(1)}"
                example_key = f"{symbol}:{line_num}"
                if example_key not in seen_examples:
                    seen_examples.add(example_key)
                    examples.append({
                        "symbol": symbol,
                        "source_file": filename,
                        "example": stripped,
                        "line_number": line_num
                    })

        # 4. Extract constants (UPPER_CASE with underscores, at least 3 chars)
        const_pattern = r'\b([A-Z][A-Z0-9_]{2,})\b'
        skip_constants = {'LUA', 'API', 'HTTP', 'XML',
                          'HTML', 'SVG', 'JSON', 'URL', 'URI', 'UTF'}
        for match in re.finditer(const_pattern, line):
            const_name = match.group(1)
            if const_name not in skip_constants and '_' in const_name:
                example_key = f"{const_name}:{line_num}"
                if example_key not in seen_examples:
                    seen_examples.add(example_key)
                    examples.append({
                        "symbol": const_name,
                        "source_file": filename,
                        "example": stripped,
                        "line_number": line_num
                    })

        # 5. Extract require() calls
        require_pattern = r'\brequire\s*\(["\']([^"\']+)["\']\)'
        for match in re.finditer(require_pattern, line):
            module_name = match.group(1)
            symbol = f"require({module_name})"
            example_key = f"{symbol}:{line_num}"
            if example_key not in seen_examples:
                seen_examples.add(example_key)
                examples.append({
                    "symbol": symbol,
                    "source_file": filename,
                    "example": stripped,
                    "line_number": line_num
                })

        # 6. Extract callback registrations (callbacks.Register)
        if 'callbacks.Register' in line or 'callbacks.Unregister' in line:
            example_key = f"callbacks:{line_num}"
            if example_key not in seen_examples:
                seen_examples.add(example_key)
                # Extract the callback name
                cb_match = re.search(
                    r'callbacks\.(Register|Unregister)\s*\(["\']([^"\']+)["\']', line)
                if cb_match:
                    cb_type = cb_match.group(2)
                    symbol = f"callbacks.{cb_match.group(1)}"
                    examples.append({
                        "symbol": symbol,
                        "source_file": filename,
                        "example": stripped,
                        "line_number": line_num,
                        "notes": f"Callback type: {cb_type}"
                    })

        # 7. Extract custom function definitions (local function name or function name)
        func_def_pattern = r'\b(?:local\s+)?function\s+([A-Za-z_][A-Za-z0-9_]*(?:\.[A-Za-z_][A-Za-z0-9_]*)*)'
        for match in re.finditer(func_def_pattern, line):
            func_name = match.group(1)
            # Only extract if it's not a standard Lua function
            if func_name not in ['pairs', 'ipairs', 'next', 'type', 'tostring', 'tonumber']:
                symbol = f"custom.{func_name}"
                example_key = f"{symbol}:{line_num}"
                if example_key not in seen_examples:
                    seen_examples.add(example_key)
                    # Get function body context
                    context = get_surrounding_context(lines, line_num, 5)
                    examples.append({
                        "symbol": symbol,
                        "source_file": filename,
                        "example": stripped,
                        "line_number": line_num,
                        "context": context,
                        "notes": "Custom function definition"
                    })

    return examples


def process_file(lua_file: Path) -> bool:
    """Process a single Lua file and create JSON extraction."""
    try:
        content = lua_file.read_text(encoding='utf-8', errors='ignore')
        filename = lua_file.name

        # Extract symbols
        examples = extract_symbols_from_code(content, filename)

        # Create JSON output
        output_file = RAW_NOTES / f"{lua_file.stem}.json"
        RAW_NOTES.mkdir(parents=True, exist_ok=True)

        with open(output_file, 'w', encoding='utf-8') as f:
            json.dump(examples, f, indent=2, ensure_ascii=False)

        # Move to DONE
        DONE.mkdir(parents=True, exist_ok=True)
        dest_file = DONE / lua_file.name
        if lua_file.exists():
            lua_file.rename(dest_file)

        sys.stdout.write(f"✓ {filename}: {len(examples)} examples\n")
        sys.stdout.flush()
        return True
    except Exception as e:
        sys.stderr.write(f"✗ Error processing {lua_file.name}: {e}\n")
        sys.stderr.flush()
        return False


def main():
    """Process all Lua files in 02_IN_PROGRESS, or move from 01_TO_PROCESS if empty."""
    import os
    agent_id = f"agent_{os.getpid()}_{datetime.now().strftime('%H%M%S')}"

    # Try to acquire lock
    if not acquire_lock(agent_id):
        print("Another agent is processing files. Exiting.")
        return 1

    try:
        IN_PROGRESS.mkdir(parents=True, exist_ok=True)
        RAW_NOTES.mkdir(parents=True, exist_ok=True)
        DONE.mkdir(parents=True, exist_ok=True)

        # Check what's already done
        done_files = {f.stem for f in DONE.glob("*.lua")}
        raw_notes_files = {f.stem for f in RAW_NOTES.glob("*.json")}

        lua_files = list(IN_PROGRESS.glob("*.lua"))

        if not lua_files:
            # Try moving from 01_TO_PROCESS
            TO_PROCESS = REPO_ROOT / "processing_zone" / "01_TO_PROCESS"
            source_files = sorted(TO_PROCESS.glob("*.lua"))
            # Skip files that are already done
            source_files = [
                f for f in source_files if f.stem not in done_files]

            moved = 0
            for f in source_files[:20]:  # Process 20 at a time
                try:
                    dest = IN_PROGRESS / f.name
                    if not dest.exists():
                        f.rename(dest)
                        moved += 1
                        sys.stdout.write(f"Moved: {f.name}\n")
                        sys.stdout.flush()
                except Exception as e:
                    sys.stderr.write(
                        f"Warning: Could not move {f.name}: {e}\n")
                    sys.stderr.flush()

            if moved > 0:
                sys.stdout.write(
                    f"Moved {moved} files from 01_TO_PROCESS to 02_IN_PROGRESS\n")
                sys.stdout.flush()

            lua_files = list(IN_PROGRESS.glob("*.lua"))

        if not lua_files:
            print("No Lua files to process.")
            return 0

        # Skip files already processed
        lua_files = [f for f in lua_files if f.stem not in done_files]

        if not lua_files:
            print("All files in 02_IN_PROGRESS are already processed.")
            return 0

        sys.stdout.write(
            f"Agent {agent_id} processing {len(lua_files)} files...\n")
        sys.stdout.flush()

        success_count = 0
        for lua_file in sorted(lua_files):
            if process_file(lua_file):
                success_count += 1

        sys.stdout.write(f"\n{'='*60}\n")
        sys.stdout.write(
            f"Completed: {success_count}/{len(lua_files)} files processed\n")

        # Show remaining files
        remaining = len(
            list((REPO_ROOT / "processing_zone" / "01_TO_PROCESS").glob("*.lua")))
        if remaining > 0:
            sys.stdout.write(
                f"Remaining in 01_TO_PROCESS: {remaining} files\n")

        sys.stdout.flush()
        return 0
    finally:
        release_lock()


if __name__ == "__main__":
    sys.exit(main())

