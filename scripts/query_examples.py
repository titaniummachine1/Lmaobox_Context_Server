#!/usr/bin/env python
"""
Query examples from the database for a given symbol.

Usage:
    python scripts/query_examples.py engine.TraceLine
    python scripts/query_examples.py --all
"""

import argparse
import json
import sqlite3
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = REPO_ROOT / ".cache" / "docs-graph.db"

def get_examples_from_db(symbol: str = None):
    """Get examples from database for a symbol or all symbols."""
    if not DB_PATH.exists():
        print(f"Database not found: {DB_PATH}", file=sys.stderr)
        return []

    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    if symbol:
        rows = conn.execute(
            """
            SELECT symbol_full_name, example_text, source_url
            FROM examples
            WHERE symbol_full_name = ? OR symbol_full_name LIKE ?
            ORDER BY symbol_full_name, example_id
            """,
            (symbol, f"{symbol}.%")
        ).fetchall()
    else:
        rows = conn.execute(
            """
            SELECT symbol_full_name, example_text, source_url
            FROM examples
            ORDER BY symbol_full_name, example_id
            """
        ).fetchall()

    conn.close()
    return [dict(row) for row in rows]

def get_examples_from_html_cache(symbol: str = None):
    """Get examples by reading cached HTML files."""
    cache_dir = REPO_ROOT / ".cache" / "docs"
    if not cache_dir.exists():
        return []

    examples = []
    
    # Map symbol to likely HTML file path
    if symbol:
        parts = symbol.split(".")
        if len(parts) == 2:
            lib_or_class, func_name = parts
            # Try library file
            lib_file = cache_dir / "Lua_Libraries" / f"{lib_or_class}.html"
            if lib_file.exists():
                examples.extend(_extract_from_html(lib_file, symbol))
            # Try class file
            class_file = cache_dir / "Lua_Classes" / f"{lib_or_class}.html"
            if class_file.exists():
                examples.extend(_extract_from_html(class_file, symbol))
    else:
        # Scan all HTML files
        for html_file in cache_dir.rglob("*.html"):
            if html_file.is_file():
                examples.extend(_extract_from_html(html_file))

    return examples

def _extract_from_html(html_path: Path, filter_symbol: str = None):
    """Extract code examples from HTML file."""
    import re
    
    try:
        html = html_path.read_text(encoding="utf-8", errors="ignore")
    except Exception:
        return []

    examples = []
    
    # Extract code blocks
    code_matches = re.findall(
        r'(?:<div[^>]*class="[^"]*highlight[^"]*"[^>]*>)?<pre[^>]*><code[^>]*>([\s\S]*?)</code></pre>',
        html
    )
    
    for code_html in code_matches:
        # Clean HTML tags
        code = re.sub(r'<[^>]+>', '', code_html)
        code = code.replace('&lt;', '<').replace('&gt;', '>')
        code = code.replace('&amp;', '&').replace('&quot;', '"')
        code = code.replace('&nbsp;', ' ').strip()
        
        if code and len(code) > 10:
            # Filter if symbol specified
            if filter_symbol:
                symbol_part = filter_symbol.split(".")[-1]
                if symbol_part.lower() not in code.lower():
                    continue
            
            examples.append({
                "source_file": str(html_path.relative_to(REPO_ROOT)),
                "example": code,
                "source": "html_cache"
            })

    return examples

def main():
    parser = argparse.ArgumentParser(description="Query examples from database and HTML cache")
    parser.add_argument("symbol", nargs="?", help="Symbol to query (e.g., engine.TraceLine)")
    parser.add_argument("--all", action="store_true", help="Get all examples")
    parser.add_argument("--db-only", action="store_true", help="Only query database")
    parser.add_argument("--html-only", action="store_true", help="Only query HTML cache")
    parser.add_argument("--format", choices=["json", "text"], default="text", help="Output format")
    
    args = parser.parse_args()

    all_examples = []

    # Query database
    if not args.html_only:
        db_examples = get_examples_from_db(args.symbol if not args.all else None)
        for ex in db_examples:
            all_examples.append({
                "symbol": ex["symbol_full_name"],
                "example": ex["example_text"],
                "source": ex["source_url"],
                "source_type": "database"
            })

    # Query HTML cache
    if not args.db_only:
        html_examples = get_examples_from_html_cache(args.symbol if not args.all else None)
        all_examples.extend(html_examples)

    if args.format == "json":
        print(json.dumps(all_examples, indent=2))
    else:
        if not all_examples:
            print(f"No examples found for {args.symbol or 'all symbols'}")
            return

        # Group by symbol
        by_symbol = {}
        for ex in all_examples:
            symbol = ex.get("symbol", ex.get("source_file", "unknown"))
            if symbol not in by_symbol:
                by_symbol[symbol] = []
            by_symbol[symbol].append(ex)

        for symbol, examples in sorted(by_symbol.items()):
            print(f"\n{'='*60}")
            print(f"Symbol: {symbol}")
            print(f"{'='*60}")
            for i, ex in enumerate(examples, 1):
                print(f"\nExample {i} (from {ex.get('source_type', ex.get('source', 'unknown'))}):")
                print("-" * 60)
                print(ex["example"])

if __name__ == "__main__":
    main()

