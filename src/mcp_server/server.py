import json
import logging
import sqlite3
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from urllib.parse import urlparse, parse_qs
import difflib
import re

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
    """Return fuzzy symbol suggestions from the symbols table."""
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

        ranked = difflib.get_close_matches(
            symbol, candidates, n=limit * 4, cutoff=0
        )
        # Deduplicate and prefer callable-like names (with a dot). If we have
        # too few, backfill with remaining ranked items to reach at least 5.
        seen = set()
        with_dot: list[str] = []
        extras: list[str] = []
        for name in ranked:
            if name in seen:
                continue
            seen.add(name)
            if "." in name:
                if len(with_dot) < limit:
                    with_dot.append(name)
            else:
                extras.append(name)
        min_needed = 5
        if len(with_dot) < min_needed:
            for name in extras:
                if len(with_dot) >= min(limit, min_needed):
                    break
                with_dot.append(name)
        return with_dot[:limit]
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

    # Not found: include fuzzy suggestions to help correction
    suggestions = _suggest_symbols(conn, symbol, limit=10)
    return {
        "did_you_mean": suggestions[0] if suggestions else None,
        "suggestions": suggestions
    }


def _smart_context_candidates(symbol: str):
    normalized = symbol.strip().replace("::", ".").replace("/", ".")
    segments = normalized.split(".")
    while segments:
        # Map namespaces to folders: engine.TraceLine -> engine/TraceLine.md
        if len(segments) == 1:
            yield SMART_CONTEXT_DIR / (segments[0] + ".md")
        else:
            yield SMART_CONTEXT_DIR / Path(*segments[:-1]) / (segments[-1] + ".md")
        segments.pop()


def get_smart_context(symbol: str):
    if not symbol:
        raise ValueError("symbol is required")

    for candidate in _smart_context_candidates(symbol):
        if candidate.exists():
            try:
                content = candidate.read_text(encoding=DEFAULT_ENCODING)
                return {
                    "symbol": symbol,
                    "path": str(candidate),
                    "content": content
                }
            except Exception:
                continue  # try next candidate

    normalized = symbol.strip().replace("::", ".").replace("/", ".")
    partial_hits = list(SMART_CONTEXT_DIR.glob(f"*{normalized}*.md"))
    if partial_hits:
        target = partial_hits[0]
        try:
            return {
                "symbol": symbol,
                "path": str(target),
                "content": target.read_text(encoding=DEFAULT_ENCODING)
            }
        except Exception:
            pass  # fall through to suggestions

    # No direct hit: return suggestions from symbols to guide the caller
    try:
        DB_PATH.parent.mkdir(parents=True, exist_ok=True)
        conn = sqlite3.connect(DB_PATH)
        suggestions = _suggest_symbols(conn, symbol, limit=5)
        conn.close()
    except Exception:
        suggestions = []

    return {
        "did_you_mean": suggestions[0] if suggestions else None,
        "suggestions": suggestions
    }


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
