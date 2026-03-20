# MCP Server - Updated with improved library search prioritization
import json
import logging
import sqlite3
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs
import difflib
import re
from collections import defaultdict

from .config import (
    DB_PATH,
    DEFAULT_ENCODING,
    DEFAULT_HOST,
    DEFAULT_PORT,
    ROOT_DIR,
    SMART_CONTEXT_DIR,
    TYPES_DIR,
)

LOG = logging.getLogger("mcp_server")


def _table_exists(conn: sqlite3.Connection, table_name: str) -> bool:
    row = conn.execute(
        "SELECT name FROM sqlite_master WHERE type='table' AND name = ?",
        (table_name,),
    ).fetchone()
    return row is not None


def _normalize_text(value: str | None) -> str:
    if not value:
        return ""
    return value.strip().lower()


def _make_snippet(text: str, query: str, max_len: int = 220) -> str:
    clean = " ".join((text or "").split())
    if not clean:
        return ""
    if len(clean) <= max_len:
        return clean

    query_norm = _normalize_text(query)
    clean_norm = clean.lower()
    idx = clean_norm.find(query_norm) if query_norm else -1
    if idx < 0:
        return clean[:max_len].rstrip() + "..."

    half = max_len // 2
    start = max(0, idx - half)
    end = min(len(clean), start + max_len)
    if start > 0:
        start += clean[start:].find(" ") + 1 if " " in clean[start:] else 0
    snippet = clean[start:end].strip()
    if start > 0:
        snippet = "..." + snippet
    if end < len(clean):
        snippet = snippet + "..."
    return snippet


def _score_candidate(query: str, candidate: dict) -> float:
    query_norm = _normalize_text(query)
    tokens = [tok for tok in re.split(r"\s+", query_norm) if tok]

    symbol = _normalize_text(candidate.get("symbol"))
    title = _normalize_text(candidate.get("title"))
    description = _normalize_text(candidate.get("description"))
    summary = _normalize_text(candidate.get("summary"))
    signature = _normalize_text(candidate.get("signature"))
    content = _normalize_text(candidate.get("content"))
    kind = _normalize_text(candidate.get("kind"))

    combined = " ".join(
        part
        for part in [symbol, title, description, summary, signature, content]
        if part
    )

    score = 0.0
    if symbol == query_norm:
        score += 120
    if symbol.startswith(query_norm) and query_norm:
        score += 80
    if query_norm and query_norm in symbol:
        score += 60
    if query_norm and query_norm in signature:
        score += 35
    if query_norm and query_norm in title:
        score += 30
    if query_norm and query_norm in description:
        score += 25
    if query_norm and query_norm in summary:
        score += 20
    if query_norm and query_norm in content:
        score += 20

    if query_norm and symbol:
        score += difflib.SequenceMatcher(None, query_norm, symbol).ratio() * 40

    token_hits = 0
    for token in tokens:
        if token in combined:
            token_hits += 1
    if token_hits:
        coverage = token_hits / max(len(tokens), 1)
        score += 20 * coverage

    if kind in ("function", "library", "class"):
        score += 6
    elif kind == "constant":
        score += 3
    elif kind == "example":
        score += 1

    return round(score, 2)


def smart_search(query: str, limit: int = 20, search_window: int = 300, include_examples: bool = True):
    if not query or not query.strip():
        raise ValueError("query is required")

    limit = max(1, min(int(limit), 100))
    search_window = max(limit, min(int(search_window), 5000))

    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    candidates: list[dict] = []
    query_like = f"%{query.strip()}%"

    has_symbols = _table_exists(conn, "symbols")
    has_docs = _table_exists(conn, "docs")
    has_signatures = _table_exists(conn, "signatures")
    has_constants = _table_exists(conn, "constants")
    has_examples = _table_exists(conn, "examples")

    if has_symbols:
        if has_docs and has_signatures:
            rows = conn.execute(
                """
                SELECT s.full_name, s.kind, s.path, s.page_url, s.title, s.description,
                       d.summary, d.notes, g.signature, g.params_json, g.returns
                FROM symbols s
                LEFT JOIN docs d ON d.symbol_full_name = s.full_name
                LEFT JOIN signatures g ON g.symbol_full_name = s.full_name
                WHERE s.full_name LIKE ? OR s.title LIKE ? OR s.description LIKE ? OR d.summary LIKE ? OR g.signature LIKE ?
                LIMIT ?
                """,
                (query_like, query_like, query_like, query_like, query_like, search_window),
            ).fetchall()
        elif has_docs:
            rows = conn.execute(
                """
                SELECT s.full_name, s.kind, s.path, s.page_url, s.title, s.description,
                       d.summary, d.notes, '' as signature, '' as params_json, '' as returns
                FROM symbols s
                LEFT JOIN docs d ON d.symbol_full_name = s.full_name
                WHERE s.full_name LIKE ? OR s.title LIKE ? OR s.description LIKE ? OR d.summary LIKE ?
                LIMIT ?
                """,
                (query_like, query_like, query_like, query_like, search_window),
            ).fetchall()
        else:
            rows = conn.execute(
                """
                SELECT s.full_name, s.kind, s.path, s.page_url, s.title, s.description,
                       '' as summary, '' as notes, '' as signature, '' as params_json, '' as returns
                FROM symbols s
                WHERE s.full_name LIKE ? OR s.title LIKE ? OR s.description LIKE ?
                LIMIT ?
                """,
                (query_like, query_like, query_like, search_window),
            ).fetchall()

        for row in rows:
            content_parts = [row["description"], row["summary"], row["notes"], row["signature"], row["params_json"], row["returns"]]
            content = "\n".join(part for part in content_parts if part)
            candidates.append(
                {
                    "symbol": row["full_name"],
                    "kind": row["kind"] or "symbol",
                    "path": row["path"],
                    "source_url": row["page_url"],
                    "title": row["title"],
                    "description": row["description"],
                    "summary": row["summary"],
                    "signature": row["signature"],
                    "content": content,
                    "section": "symbol",
                }
            )

        # Typo-tolerant fallback: when LIKE misses, scan symbol names with fuzzy ratio.
        if len(candidates) < max(limit, 20):
            fuzzy_rows = conn.execute(
                """
                SELECT full_name, kind, path, page_url, title, description
                FROM symbols
                LIMIT ?
                """,
                (search_window,),
            ).fetchall()
            query_norm = _normalize_text(query)
            for row in fuzzy_rows:
                full_name = row["full_name"] or ""
                ratio = difflib.SequenceMatcher(None, query_norm, _normalize_text(full_name)).ratio()
                if ratio < 0.45:
                    continue
                candidates.append(
                    {
                        "symbol": full_name,
                        "kind": row["kind"] or "symbol",
                        "path": row["path"],
                        "source_url": row["page_url"],
                        "title": row["title"],
                        "description": row["description"],
                        "summary": None,
                        "signature": None,
                        "content": row["description"] or "",
                        "section": "symbol",
                    }
                )

    if has_constants:
        rows = conn.execute(
            """
            SELECT symbol_full_name, name, value, description, category
            FROM constants
            WHERE name LIKE ? OR description LIKE ? OR value LIKE ?
            LIMIT ?
            """,
            (query_like, query_like, query_like, search_window),
        ).fetchall()
        for row in rows:
            candidates.append(
                {
                    "symbol": row["symbol_full_name"] or row["name"],
                    "kind": "constant",
                    "path": None,
                    "source_url": None,
                    "title": row["name"],
                    "description": row["description"],
                    "summary": row["category"],
                    "signature": None,
                    "content": f"value={row['value'] or ''}",
                    "section": "constants",
                }
            )

    if include_examples and has_examples:
        rows = conn.execute(
            """
            SELECT symbol_full_name, example_text, source_url
            FROM examples
            WHERE example_text LIKE ? OR symbol_full_name LIKE ?
            LIMIT ?
            """,
            (query_like, query_like, search_window),
        ).fetchall()
        for row in rows:
            candidates.append(
                {
                    "symbol": row["symbol_full_name"],
                    "kind": "example",
                    "path": None,
                    "source_url": row["source_url"],
                    "title": row["symbol_full_name"],
                    "description": None,
                    "summary": None,
                    "signature": None,
                    "content": row["example_text"],
                    "section": "examples",
                }
            )

    conn.close()

    if not candidates:
        return {
            "query": query,
            "total_candidates": 0,
            "returned": 0,
            "limit": limit,
            "search_window": search_window,
            "results": [],
            "hint": "No matches found. Try a broader query, alternate spelling, or increase search_window.",
        }

    best_by_symbol: dict[str, dict] = {}
    for candidate in candidates:
        key = f"{candidate.get('section')}::{candidate.get('symbol') or candidate.get('title') or '<unknown>'}"
        candidate["score"] = _score_candidate(query, candidate)
        existing = best_by_symbol.get(key)
        if not existing:
            candidate["occurrences"] = 1
            best_by_symbol[key] = candidate
            continue

        existing["occurrences"] = int(existing.get("occurrences", 1)) + 1
        if candidate["score"] > existing["score"]:
            candidate["occurrences"] = existing["occurrences"]
            best_by_symbol[key] = candidate

    ranked = sorted(best_by_symbol.values(), key=lambda item: item["score"], reverse=True)
    top = ranked[:limit]

    section_counts: dict[str, int] = defaultdict(int)
    for row in top:
        section_counts[row.get("section") or "other"] += 1

    results = []
    for row in top:
        snippet_source = row.get("content") or row.get("description") or row.get("summary") or row.get("title") or ""
        results.append(
            {
                "symbol": row.get("symbol"),
                "kind": row.get("kind"),
                "section": row.get("section"),
                "score": row.get("score"),
                "title": row.get("title"),
                "description": row.get("description"),
                "signature": row.get("signature"),
                "snippet": _make_snippet(str(snippet_source), query),
                "occurrences": int(row.get("occurrences", 1)),
                "path": row.get("path"),
                "source_url": row.get("source_url"),
            }
        )

    return {
        "query": query,
        "total_candidates": len(ranked),
        "returned": len(results),
        "limit": limit,
        "search_window": search_window,
        "section_counts": dict(section_counts),
        "results": results,
        "hint": "Increase limit/search_window for broader recall. Reduce include_examples for tighter results.",
    }


def _ensure_db(conn: sqlite3.Connection) -> None:
    """Create metadata table if it does not exist."""
    conn.execute(
        """
		CREATE TABLE IF NOT EXISTS symbol_metadata (
			symbol TEXT PRIMARY KEY,
			signature TEXT,
			required_constants TEXT,
			source TEXT,
			updated_at INTEGER DEFAULT (strftime('%s','now'))
		)
		"""
    )
    conn.commit()


def _load_symbol_from_db(conn: sqlite3.Connection, symbol: str):
    _ensure_db(conn)
    cur = conn.execute(
        "SELECT symbol, signature, required_constants, source FROM symbol_metadata WHERE symbol = ?",
        (symbol,)
    )
    row = cur.fetchone()
    if not row:
        return None
    required = []
    if row[2]:
        try:
            required = json.loads(row[2])
        except Exception:
            required = []
    return {
        "symbol": row[0],
        "signature": row[1],
        "required_constants": required,
        "source": row[3] or "sqlite"
    }


def _extract_signature_line(text: str, symbol: str, short_symbol: str) -> str | None:
    """Extract signature, prioritizing function definitions over comments."""
    lines = text.splitlines()

    # For symbols with dots (like engine.TraceLine), require function keyword
    has_namespace = "." in symbol
    pattern_full = re.compile(rf"\b{re.escape(symbol)}\b")
    pattern_short = re.compile(rf"\b{re.escape(short_symbol)}\b")

    # First pass: look for function definitions (highest priority)
    for raw in lines:
        trimmed = raw.strip()
        if trimmed.startswith("---") or trimmed.startswith("--"):
            continue  # Skip all comments
        if "function" in trimmed:
            # Check if this line contains our symbol
            if (has_namespace and pattern_full.search(trimmed)) or (not has_namespace and pattern_short.search(trimmed)):
                return trimmed

    # Second pass: only for symbols without namespace (globals)
    if not has_namespace:
        for raw in lines:
            trimmed = raw.strip()
            if trimmed.startswith("---") or trimmed.startswith("--"):
                continue
            if pattern_short.search(trimmed):
                return trimmed

    return None


def _fuzzy_constants_for_symbol(symbol: str):
    """Heuristic: if symbol includes 'mask' or is TraceLine/TraceHull, suggest trace masks."""
    name = symbol.lower()
    candidates = []
    if "trace" in name or "mask" in name:
        candidates.append("E_TraceLine")
    if "engine.traceline" in symbol.lower() or "tracehul" in name:
        candidates.append("E_TraceLine")
    return candidates


def _extract_docblock(text: str, signature_line: str) -> str | None:
    """Pull contiguous comment block immediately above the signature line."""
    lines = text.splitlines()
    try:
        idx = lines.index(signature_line)
    except ValueError:
        return None
    doc_lines: list[str] = []
    for j in range(idx - 1, -1, -1):
        t = lines[j].strip()
        if t.startswith("---") or t.startswith("--"):
            doc_lines.append(t.lstrip("- ").strip())
            continue
        if t == "" or t.isspace():
            doc_lines.append("")
            continue
        break  # stop when hitting non-comment, non-blank
    if not doc_lines:
        return None
    doc_lines.reverse()
    # trim leading/trailing blanks
    while doc_lines and doc_lines[0] == "":
        doc_lines.pop(0)
    while doc_lines and doc_lines[-1] == "":
        doc_lines.pop()
    return "\n".join(doc_lines) if doc_lines else None


def _parse_docblock(doc: str) -> dict:
    """Parse docblock into human-friendly summary/params/returns."""
    if not doc:
        return {}
    lines = [ln.strip() for ln in doc.splitlines()]
    summary: list[str] = []
    params: list[str] = []
    returns: list[str] = []

    for ln in lines:
        if ln.startswith("@param"):
            # Format: @param name? rest...
            _, *rest = ln.split(maxsplit=2)
            if not rest:
                continue
            name = rest[0]
            optional = name.endswith("?")
            name = name.rstrip("?")
            detail = rest[1] if len(rest) > 1 else ""
            if detail:
                params.append(
                    f"{name} ({'optional' if optional else 'required'}): {detail}")
            else:
                params.append(
                    f"{name} ({'optional' if optional else 'required'})")
            continue
        if ln.startswith("@return"):
            _, *rest = ln.split(maxsplit=1)
            returns.append(rest[0] if rest else "")
            continue
        if ln.startswith("@"):
            continue  # ignore other annotations like @nodiscard
        summary.append(ln)

    # Clean summary
    while summary and not summary[0]:
        summary.pop(0)
    while summary and not summary[-1]:
        summary.pop()

    return {
        "desc": "\n".join(summary) if summary else None,
        "params": params or None,
        "returns": returns or None,
    }


def _load_constants_group(symbol: str):
    """If symbol matches a constants group (e.g., E_TraceLine), return its members."""
    constants_dir = TYPES_DIR / "lmaobox_lua_api" / "constants"
    path = constants_dir / f"{symbol}.d.lua"
    if not path.exists():
        return None

    desc_lines: list[str] = []
    names: list[str] = []
    for line in path.read_text(encoding=DEFAULT_ENCODING, errors="ignore").splitlines():
        stripped = line.strip()
        if stripped.startswith("---"):
            cleaned = stripped.lstrip("- ").strip()
            if cleaned.startswith("@"):
                continue
            desc_lines.append(cleaned)
            continue
        if stripped.startswith("@"):
            continue  # skip annotations
        m = re.match(r"^([A-Z0-9_]+)\s*=", stripped)
        if m:
            names.append(m.group(1))

    # Deduplicate names preserving order
    seen = set()
    constants = []
    for n in names:
        if n in seen:
            continue
        seen.add(n)
        constants.append(n)

    desc = "\n".join(desc_lines).strip() if desc_lines else None
    if not desc:
        desc = f"Constants group {symbol}"
    return {
        "desc": desc,
        "constants": constants,
    }


def _search_library_partial_match(partial_symbol: str):
    """Search for partial matches in Library files (e.g., 'traceline' -> 'engine.TraceLine')."""
    # Updated: Now properly searches all Library files for partial matches
    search_base = TYPES_DIR / "lmaobox_lua_api" / "Lua_Libraries"
    if not search_base.exists():
        return []

    matches = []
    partial_lower = partial_symbol.lower()

    for lib_file in search_base.glob("*.d.lua"):
        try:
            text = lib_file.read_text(
                encoding=DEFAULT_ENCODING, errors="ignore")
            lib_name = lib_file.stem  # e.g., "engine" from "engine.d.lua"

            # Look for function definitions: "function libname.FunctionName"
            pattern = rf"function\s+{re.escape(lib_name)}\.(\w+)"
            for line in text.splitlines():
                if not line.strip().startswith("---"):  # Skip comments
                    match = re.search(pattern, line)
                    if match:
                        func_name = match.group(1)
                        if partial_lower in func_name.lower():
                            full_name = f"{lib_name}.{func_name}"
                            if full_name not in matches:
                                matches.append(full_name)
        except Exception:
            continue

    return matches


def _scan_types_for_symbol(symbol: str):
    """Fallback scanner that looks through generated type files for a quick signature hint."""
    short_symbol = symbol.split(".")[-1]
    parts = symbol.split(".")

    # Prioritize more specific files (e.g., engine.d.lua for engine.TraceLine)
    candidate_files = []
    search_roots = [
        TYPES_DIR / "lmaobox_lua_api",
        TYPES_DIR,
    ]

    # First: look in specific library/class files if symbol has dots (highest priority)
    if len(parts) > 1:
        lib_or_class = parts[0]
        for base in search_roots:
            lib_file = base / "Lua_Libraries" / f"{lib_or_class}.d.lua"
            if lib_file.exists() and lib_file not in candidate_files:
                candidate_files.append(lib_file)  # Add to prioritized list
            class_file = base / "Lua_Classes" / f"{lib_or_class}.d.lua"
            if class_file.exists() and class_file not in candidate_files:
                candidate_files.append(class_file)

    # Then: scan all other files (lower priority)
    for base in search_roots:
        if not base.exists():
            continue
        for path in base.rglob("*.lua"):
            if path not in candidate_files:
                candidate_files.append(path)

    # Search candidate files in priority order
    for path in candidate_files:
        try:
            text = path.read_text(encoding=DEFAULT_ENCODING, errors="ignore")
        except Exception:
            continue
        signature = _extract_signature_line(text, symbol, short_symbol)
        if signature:
            doc = _extract_docblock(text, signature)
            parsed_doc = _parse_docblock(doc) if doc else {}
            constants = list(dict.fromkeys(
                _fuzzy_constants_for_symbol(symbol)))
            return {
                "signature": signature,
                "params": parsed_doc.get("params"),
                "returns": parsed_doc.get("returns"),
                "desc": parsed_doc.get("desc"),
                "required_constants": constants,
                "source": f"types:{path.relative_to(ROOT_DIR)}"
            }
    return None


def _suggest_symbols(conn: sqlite3.Connection, symbol: str, limit: int = 10):
    """Return fuzzy symbol suggestions, prioritizing Libraries over Classes."""
    try:
        # Check if symbols table exists
        cursor = conn.execute(
            "SELECT name FROM sqlite_master WHERE type='table' AND name='symbols'"
        )
        if not cursor.fetchone():
            return []

        rows = conn.execute("SELECT full_name FROM symbols").fetchall()
        candidates = [r[0] for r in rows] if rows else []
        if not candidates:
            return []

        # Separate candidates by category
        library_funcs: list[str] = []
        class_props: list[str] = []
        constants: list[str] = []
        other: list[str] = []

        # All known library namespaces from Lua_Libraries folder
        library_namespaces = {
            "aimbot", "callbacks", "client", "clientstate", "draw", "engine",
            "entities", "filesystem", "gamecoordinator", "gamerules", "globals",
            "gui", "http", "input", "inventory", "itemschema", "materials",
            "models", "party", "physics", "playerlist", "render", "steam",
            "vector", "warp"
        }

        for name in candidates:
            if name.startswith("E_") or name.isupper():
                constants.append(name)
            elif "." in name:
                # Check if it's from a Library or Class by looking at the namespace
                namespace = name.split(".")[0].lower()
                if namespace in library_namespaces:
                    library_funcs.append(name)
                else:
                    # Likely a class property (e.g., Entity.GetPropInt, Trace.plane)
                    class_props.append(name)
            else:
                other.append(name)

        # Fuzzy match within each category
        ranked_libs = difflib.get_close_matches(
            symbol, library_funcs, n=limit * 2, cutoff=0.3)
        ranked_classes = difflib.get_close_matches(
            symbol, class_props, n=limit * 2, cutoff=0.3)
        ranked_constants = difflib.get_close_matches(
            symbol, constants, n=limit, cutoff=0.4)
        ranked_other = difflib.get_close_matches(
            symbol, other, n=limit, cutoff=0.4)

        # Prioritize: Libraries > Classes > Constants > Other
        result = []
        seen = set()

        # Add library functions first (highest priority)
        for name in ranked_libs:
            if name not in seen:
                result.append(name)
                seen.add(name)
                if len(result) >= limit:
                    return result

        # Then add class properties
        for name in ranked_classes:
            if name not in seen:
                result.append(name)
                seen.add(name)
                if len(result) >= limit:
                    return result

        # Then constants
        for name in ranked_constants:
            if name not in seen:
                result.append(name)
                seen.add(name)
                if len(result) >= limit:
                    return result

        # Finally other symbols
        for name in ranked_other:
            if name not in seen:
                result.append(name)
                seen.add(name)
                if len(result) >= limit:
                    return result

        return result
    except Exception:
        return []


def get_types(symbol: str):
    if not symbol:
        raise ValueError("symbol is required")

    # Constant group lookup first (e.g., E_TraceLine) - highest priority
    consts = _load_constants_group(symbol)
    if consts:
        return consts

    # Ensure DB directory exists
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)
    conn = sqlite3.connect(DB_PATH)
    conn.row_factory = sqlite3.Row

    from_db = _load_symbol_from_db(conn, symbol)
    if from_db:
        # Re-validate to avoid stale/false-positive cache entries
        recheck = _scan_types_for_symbol(symbol)
        if recheck:
            resp = dict(recheck)
            resp.pop("source", None)
            return resp
        # Cache was stale; drop it
        conn.execute("DELETE FROM symbol_metadata WHERE symbol = ?", (symbol,))
        conn.commit()

    fallback = _scan_types_for_symbol(symbol)
    if fallback:
        _ensure_db(conn)
        conn.execute(
            """
            INSERT OR REPLACE INTO symbol_metadata (symbol, signature, required_constants, source, updated_at)
            VALUES (?, ?, ?, ?, strftime('%s','now'))
            """,
            (symbol, fallback["signature"], json.dumps(
                fallback["required_constants"]), fallback.get("source")),
        )
        conn.commit()
        response = dict(fallback)
        response.pop("source", None)  # not needed for the model
        return response

    # Not found: try partial library search if no dots in symbol
    library_matches = []
    if "." not in symbol:
        library_matches = _search_library_partial_match(symbol)

    # Get fuzzy suggestions from database
    db_suggestions = _suggest_symbols(conn, symbol, limit=10)

    # Combine: library matches first, then db suggestions (avoiding duplicates)
    all_suggestions = library_matches[:]
    seen = set(all_suggestions)
    for sugg in db_suggestions:
        if sugg not in seen:
            all_suggestions.append(sugg)
            seen.add(sugg)

    # Limit to 10 total
    final_suggestions = all_suggestions[:10]

    response = {
        "did_you_mean": final_suggestions[0] if final_suggestions else None,
        "suggestions": final_suggestions
    }

    # Add search hint if no exact match found
    if final_suggestions:
        response["hint"] = "💡 Tip: Search is case-insensitive. For partial name search, try variations. For browsing constants/types, check E_TraceLine, E_TFCOND, etc."

    return response


def _smart_context_candidates(symbol: str):
    normalized = symbol.strip().replace("::", ".").replace("/", ".")
    if not normalized:
        return

    # Preferred layout: mirror types/lmaobox_lua_api/* with additive markdown files.
    mirror_root = SMART_CONTEXT_DIR / "lmaobox_lua_api"
    parts = normalized.split(".")

    if len(parts) > 1:
        namespace = parts[0]
        namespace_lower = namespace.lower()
        nested = parts[1:-1]
        leaf = parts[-1] + ".md"

        yield mirror_root / "Lua_Libraries" / namespace / Path(*nested) / leaf
        yield mirror_root / "Lua_Classes" / namespace / Path(*nested) / leaf
        yield mirror_root / "entity_props" / namespace / Path(*nested) / leaf
        if namespace_lower == "callbacks":
            yield mirror_root / "Lua_Callbacks" / leaf
        if namespace_lower == "constants":
            yield mirror_root / "constants" / leaf
    else:
        leaf = parts[0] + ".md"
        if parts[0].startswith("E_"):
            yield mirror_root / "constants" / leaf

        yield mirror_root / "Lua_Globals" / leaf
        yield mirror_root / "Lua_Callbacks" / leaf
        yield mirror_root / "Lua_Classes" / leaf
        yield mirror_root / "Lua_Libraries" / leaf
        yield mirror_root / "constants" / leaf
        yield mirror_root / "entity_props" / leaf

    yield from _deprecated_smart_context_candidates(normalized)


def _deprecated_smart_context_candidates(normalized: str):
    """Deprecated fallback for pre-mirror smart context paths."""
    yield SMART_CONTEXT_DIR / (normalized + ".md")

    segments = normalized.split(".")
    while segments:
        if len(segments) == 1:
            yield SMART_CONTEXT_DIR / (segments[0] + ".md")
        else:
            yield SMART_CONTEXT_DIR / Path(*segments[:-1]) / (segments[-1] + ".md")
        segments.pop()


def _format_base_context_from_types(symbol: str):
    """Build baseline context from generated types so smart files can stay additive."""
    baseline = get_types(symbol)

    has_core = any(
        key in baseline for key in ("signature", "desc", "params", "returns", "constants")
    )
    if not has_core:
        return None, baseline

    lines = [f"## Base Type Context: {symbol}"]

    signature = baseline.get("signature")
    if signature:
        lines.extend(["", "### Signature", signature])

    desc = baseline.get("desc")
    if desc:
        lines.extend(["", "### Description", desc])

    params = baseline.get("params") or []
    if params:
        lines.extend(["", "### Parameters"])
        for entry in params:
            lines.append(f"- {entry}")

    returns = baseline.get("returns") or []
    if returns:
        lines.extend(["", "### Returns"])
        for entry in returns:
            lines.append(f"- {entry}")

    required_constants = baseline.get("required_constants") or []
    if required_constants:
        lines.extend(["", "### Required Constants"])
        for entry in required_constants:
            lines.append(f"- {entry}")

    constants = baseline.get("constants") or []
    if constants:
        lines.extend(["", "### Constants"]) 
        limit = 40
        for entry in constants[:limit]:
            lines.append(f"- {entry}")
        if len(constants) > limit:
            lines.append(f"- ... and {len(constants) - limit} more")

    return "\n".join(lines), None


def _combine_base_and_additional(base_text: str | None, additional_text: str | None) -> str:
    if base_text and additional_text:
        return "\n\n".join([
            base_text,
            "---",
            "## Additional Smart Context",
            additional_text.strip(),
        ])
    if additional_text:
        return additional_text
    return base_text or ""


def _best_smart_context_match(symbol: str) -> Path | None:
    normalized = symbol.strip().replace("::", ".").replace("/", ".").lower()
    if not normalized:
        return None

    root = SMART_CONTEXT_DIR / "lmaobox_lua_api"
    if not root.exists():
        root = SMART_CONTEXT_DIR

    parts = normalized.split(".")
    leaf = parts[-1]
    joined = "/".join(parts)

    best_score = -1
    best_path: Path | None = None

    for path in root.rglob("*.md"):
        try:
            rel = path.relative_to(root).as_posix().lower()
        except Exception:
            continue

        base = path.stem.lower()
        parent = path.parent.name.lower()

        score = 0

        # Highest confidence: exact symbol index.md (e.g. Lua_Classes/Trace/index.md)
        if base == "index" and parent == leaf:
            score += 120

        # Exact leaf filename (e.g. engine/TraceLine.md)
        if base == leaf:
            score += 100

        # Full path shape match
        if rel == f"{joined}.md" or rel.endswith(f"/{joined}.md"):
            score += 90
        if rel.endswith(f"/{joined}/index.md"):
            score += 90

        # Weak fallback containment
        if leaf in rel:
            score += 15

        if score > best_score:
            best_score = score
            best_path = path

    return best_path if best_score > 0 else None


def get_smart_context(symbol: str):
    if not symbol:
        raise ValueError("symbol is required")

    base_text, type_suggestions = _format_base_context_from_types(symbol)

    for candidate in _smart_context_candidates(symbol):
        if candidate.exists():
            try:
                additional = candidate.read_text(encoding=DEFAULT_ENCODING)
                merged_content = _combine_base_and_additional(base_text, additional)
                return {
                    "symbol": symbol,
                    "path": str(candidate),
                    "content": merged_content,
                    "base_context_included": bool(base_text)
                }
            except Exception:
                continue  # try next candidate

    target = _best_smart_context_match(symbol)
    if target:
        try:
            additional = target.read_text(encoding=DEFAULT_ENCODING)
            merged_content = _combine_base_and_additional(base_text, additional)
            return {
                "symbol": symbol,
                "path": str(target),
                "content": merged_content,
                "base_context_included": bool(base_text)
            }
        except Exception:
            pass  # fall through to suggestions

    # No additional smart markdown found: return baseline types-derived context.
    if base_text:
        return {
            "symbol": symbol,
            "path": "<types-fallback>",
            "content": base_text,
            "base_context_included": True
        }

    if type_suggestions and type_suggestions.get("suggestions"):
        return {
            "did_you_mean": type_suggestions.get("did_you_mean"),
            "suggestions": type_suggestions.get("suggestions", []),
            "hint": type_suggestions.get("hint") or "No matching symbol found in smart context or types."
        }

    # No direct hit: try partial library search if no dots in symbol
    library_matches = []
    if "." not in symbol:
        library_matches = _search_library_partial_match(symbol)

    # Get fuzzy suggestions from database
    try:
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(DB_PATH)
        db_suggestions = _suggest_symbols(conn, symbol, limit=5)
        conn.close()
    except Exception:
        db_suggestions = []

    # Combine: library matches first, then db suggestions (avoiding duplicates)
    all_suggestions = library_matches[:]
    seen = set(all_suggestions)
    for sugg in db_suggestions:
        if sugg not in seen:
            all_suggestions.append(sugg)
            seen.add(sugg)

    # Limit to 5 for smart context
    final_suggestions = all_suggestions[:5]

    response = {
        "did_you_mean": final_suggestions[0] if final_suggestions else None,
        "suggestions": final_suggestions
    }

    # Add search hint
    if final_suggestions:
        response["hint"] = "💡 Search is case-insensitive. Try exact namespace: 'engine.TraceLine', 'Entity.GetHealth', 'custom.GetEyePos', etc."

    return response


class MCPRequestHandler(BaseHTTPRequestHandler):
    def _json(self, status: int, payload: dict) -> None:
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(json.dumps(payload).encode(DEFAULT_ENCODING))

    def do_GET(self):  # noqa: N802 - http handler naming
        parsed = urlparse(self.path)
        query = parse_qs(parsed.query)
        path = parsed.path

        if path == "/health":
            self._json(200, {"status": "ok"})
            return

        if path == "/get_types":
            symbol = (query.get("symbol") or [""])[0]
            if not symbol:
                self._json(
                    400, {"error": "symbol query parameter is required"})
                return
            try:
                payload = get_types(symbol)
                self._json(200, payload)
            except Exception as exc:  # guard against unexpected errors
                LOG.exception("get_types failed")
                self._json(500, {"error": str(exc)})
            return

        if path == "/smart_context":
            symbol = (query.get("symbol") or [""])[0]
            if not symbol:
                self._json(
                    400, {"error": "symbol query parameter is required"})
                return
            try:
                payload = get_smart_context(symbol)
                if payload:
                    self._json(200, payload)
                else:
                    self._json(404, {"error": "context not found"})
            except Exception as exc:
                LOG.exception("get_smart_context failed")
                self._json(500, {"error": str(exc)})
            return

        if path == "/smart_search":
            query_text = (query.get("query") or [""])[0]
            limit_raw = (query.get("limit") or ["20"])[0]
            window_raw = (query.get("search_window") or ["300"])[0]
            include_examples_raw = (query.get("include_examples") or ["true"])[0]

            if not query_text:
                self._json(400, {"error": "query parameter is required"})
                return
            try:
                payload = smart_search(
                    query=query_text,
                    limit=int(limit_raw),
                    search_window=int(window_raw),
                    include_examples=str(include_examples_raw).lower() != "false",
                )
                self._json(200, payload)
            except Exception as exc:
                LOG.exception("smart_search failed")
                self._json(500, {"error": str(exc)})
            return

        self._json(404, {"error": "not found"})

    def log_message(self, fmt, *args):  # noqa: D401, N802
        LOG.info("%s - %s", self.address_string(), fmt % args)


def run_server(host: str = DEFAULT_HOST, port: int = DEFAULT_PORT) -> None:
    SMART_CONTEXT_DIR.mkdir(parents=True, exist_ok=True)
    DB_PATH.parent.mkdir(parents=True, exist_ok=True)

    server = HTTPServer((host, port), MCPRequestHandler)
    LOG.info("MCP server listening on http://%s:%s", host, port)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        LOG.info("Shutting down MCP server")
    finally:
        server.server_close()


if __name__ == "__main__":
    logging.basicConfig(level=logging.INFO,
                        format="%(asctime)s %(levelname)s %(message)s")
    run_server()
