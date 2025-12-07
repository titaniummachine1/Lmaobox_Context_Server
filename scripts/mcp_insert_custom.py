#!/usr/bin/env python
"""
Insert custom symbols/examples/constants into the SQLite graph with strict validation.

Usage:
  python scripts/mcp_insert_custom.py symbol --kind function --signature "function foo(bar) end" --parent engine --doc "Custom helper"
  python scripts/mcp_insert_custom.py example --symbol engine.foo --example "local x=1"
  python scripts/mcp_insert_custom.py constant --symbol engine.foo --name MASK_SHOT --value "0x600400B" --category TraceLine
"""

import argparse
import json
import sqlite3
import sys
from pathlib import Path
import re

REPO_ROOT = Path(__file__).resolve().parent.parent
DB_PATH = REPO_ROOT / ".cache" / "docs-graph.db"
SMART_CONTEXT_DIR = REPO_ROOT / "data" / "smart_context"

# Import get_types for real signatures
sys.path.insert(0, str(REPO_ROOT))
from src.mcp_server.server import get_types  # noqa: E402


def fail(msg: str):
	print(f"[insert-custom] ERROR: {msg}", file=sys.stderr)
	sys.exit(1)


def validate_symbol_name(name: str):
	if not name or not isinstance(name, str):
		fail("symbol name is required")
	if " " in name or "\t" in name:
		fail("symbol name cannot contain whitespace")


def connect_db():
	if not DB_PATH.exists():
		fail(f"DB not found: {DB_PATH}")
	conn = sqlite3.connect(DB_PATH)
	conn.execute("PRAGMA foreign_keys = ON;")
	return conn


def upsert_symbol(conn, full_name, kind, parent, title, desc):
	conn.execute(
		"""
		INSERT INTO symbols (full_name, kind, parent_full_name, page_url, path, title, description)
		VALUES (?, ?, ?, NULL, NULL, ?, ?)
		ON CONFLICT(full_name) DO UPDATE SET
			kind=excluded.kind,
			parent_full_name=excluded.parent_full_name,
			title=excluded.title,
			description=excluded.description
		""",
		(full_name, kind, parent, title, desc),
	)


def upsert_signature(conn, full_name, signature, returns, params):
	params_json = json.dumps(params) if params else None
	conn.execute(
		"""
		INSERT INTO signatures (symbol_full_name, signature, returns, params_json)
		VALUES (?, ?, ?, ?)
		ON CONFLICT(symbol_full_name) DO UPDATE SET
			signature=excluded.signature,
			returns=excluded.returns,
			params_json=excluded.params_json
		""",
		(full_name, signature, returns, params_json),
	)


def insert_example(conn, symbol, example_text):
	conn.execute(
		"""
		INSERT INTO examples (symbol_full_name, example_text, source_url)
		VALUES (?, ?, NULL)
		""",
		(symbol, example_text),
	)


def insert_constant(conn, symbol, name, value, desc, category):
	conn.execute(
		"""
		INSERT INTO constants (symbol_full_name, name, value, description, category)
		VALUES (?, ?, ?, ?, ?)
		""",
		(symbol, name, value, desc, category),
	)


def upsert_doc(conn, symbol, summary, notes):
	conn.execute(
		"""
		INSERT INTO docs (symbol_full_name, summary, notes)
		VALUES (?, ?, ?)
		ON CONFLICT(symbol_full_name) DO UPDATE SET
			summary=excluded.summary,
			notes=excluded.notes
		""",
		(symbol, summary, notes),
	)


def cmd_symbol(args):
	validate_symbol_name(args.symbol)
	if args.kind not in ("function", "class", "library", "constant", "page", "method", "callback"):
		fail("invalid kind")
	conn = connect_db()
	with conn:
		upsert_symbol(conn, args.symbol, args.kind, args.parent, args.title or args.symbol, args.doc or "")
		if args.signature:
			upsert_signature(conn, args.symbol, args.signature, args.returns, None)
		if args.doc or args.notes:
			upsert_doc(conn, args.symbol, args.doc or "", args.notes or "")
	print("[insert-custom] symbol upserted:", args.symbol)


def cmd_example(args):
	validate_symbol_name(args.symbol)
	if not args.example:
		fail("example text required")
	conn = connect_db()
	with conn:
		insert_example(conn, args.symbol, args.example)
	print("[insert-custom] example added for:", args.symbol)


def cmd_constant(args):
	validate_symbol_name(args.symbol)
	if not args.name:
		fail("constant name required")
	conn = connect_db()
	with conn:
		insert_constant(conn, args.symbol, args.name, args.value or "", args.desc or "", args.category or "")
	print("[insert-custom] constant added for:", args.symbol)


# ---------- MD mode helpers ----------
MD_REQUIRED_SECTIONS = [
	"## Function/Symbol:",
	"> Signature:",
	"### Required Context",
	"### Curated Usage Examples"
]


def parse_md(file_path: Path):
	text = file_path.read_text(encoding="utf-8")
	for marker in MD_REQUIRED_SECTIONS:
		if marker not in text:
			fail(f"MD missing required section: {marker}")

	# Extract symbol
	sym_match = re.search(r"## Function/Symbol:\s*(.+)", text)
	if not sym_match:
		fail("Could not parse Function/Symbol from MD")
	symbol = sym_match.group(1).strip()

	# Extract signature
	sig_match = re.search(r"> Signature:\s*(.+)", text)
	signature = sig_match.group(1).strip() if sig_match else ""

	# Extract required context (constants/types hints)
	ctx_section = re.search(r"### Required Context.*?\n(.*?)\n###", text, re.S)
	required_constants = []
	if ctx_section:
		for line in ctx_section.group(1).splitlines():
			line = line.strip("-* \t")
			if line:
				required_constants.append(line)

	# Extract examples (code fences)
	examples = []
	for match in re.finditer(r"```lua\n([\s\S]*?)\n```", text):
		code = match.group(1).strip()
		if code:
			examples.append(code)

	if not examples:
		fail("No code examples found in MD")

	return symbol, signature, required_constants, examples, text


def md_target_path(symbol: str):
	# Map symbol segments to folders to mimic types structure
	parts = symbol.split(".")
	return SMART_CONTEXT_DIR / Path(*parts).with_suffix(".md")


def ensure_parent_symbol(conn, symbol: str, allow_create: bool):
	parts = symbol.split(".")
	if len(parts) < 2:
		return None
	parent = ".".join(parts[:-1])
	row = conn.execute("SELECT full_name FROM symbols WHERE full_name = ?", (parent,)).fetchone()
	if row:
		return parent
	if allow_create:
		return parent
	fail(f"Parent symbol missing: {parent}. Pass --allow-create to create.")


def cmd_md(args):
	file_path = Path(args.file)
	if not file_path.exists():
		fail(f"MD file not found: {file_path}")

	symbol_md, signature_md, required_constants, examples, raw_md = parse_md(file_path)

	# If user provided symbol, enforce match
	if args.symbol and args.symbol != symbol_md:
		fail(f"Symbol mismatch: MD has '{symbol_md}', arg was '{args.symbol}'")
	symbol = args.symbol or symbol_md
	validate_symbol_name(symbol)

	conn = connect_db()
	parent = ensure_parent_symbol(conn, symbol, args.allow_create)

	# Try to resolve real signature via get_types
	sig_resolved = None
	try:
		res = get_types(symbol)
		if res and res.get("signature"):
			sig_resolved = res["signature"]
	except Exception:
		sig_resolved = None

	final_signature = sig_resolved or signature_md
	if not final_signature:
		fail("No signature resolved (neither get_types nor MD provided).")

	# If get_types could not resolve and symbol is not namespaced, require allow-create to avoid accidental globals
	if not sig_resolved and "." not in symbol and not args.allow_create:
		fail("Symbol not found in types and not namespaced. Pass --allow-create to force.")

	# Upserts
	with conn:
		upsert_symbol(conn, symbol, args.kind or "function", parent, symbol, "")
		if final_signature:
			upsert_signature(conn, symbol, final_signature, None, None)
		if required_constants:
			for rc in required_constants:
				insert_constant(conn, symbol, rc, "", "", "Required Context")
		for ex in examples:
			insert_example(conn, symbol, ex)
		upsert_doc(conn, symbol, f"Smart context notes for {symbol}", "")

	# Write MD to smart_context mirror structure
	target = md_target_path(symbol)
	target.parent.mkdir(parents=True, exist_ok=True)
	target.write_text(raw_md, encoding="utf-8")

	print("[insert-custom] MD inserted for symbol:", symbol)
	print("  MD path:", target)
	print("  Signature:", final_signature)
	print("  Examples:", len(examples))
	print("[insert-custom] Done.")


def main():
	parser = argparse.ArgumentParser(description="Insert custom data into MCP graph (strict validation).")
	sub = parser.add_subparsers(dest="mode", required=True)

	p_sym = sub.add_parser("symbol")
	p_sym.add_argument("--symbol", required=True)
	p_sym.add_argument("--kind", required=True)
	p_sym.add_argument("--parent")
	p_sym.add_argument("--title")
	p_sym.add_argument("--doc")
	p_sym.add_argument("--notes")
	p_sym.add_argument("--signature")
	p_sym.add_argument("--returns")

	p_ex = sub.add_parser("example")
	p_ex.add_argument("--symbol", required=True)
	p_ex.add_argument("--example", required=True)

	p_c = sub.add_parser("constant")
	p_c.add_argument("--symbol", required=True)
	p_c.add_argument("--name", required=True)
	p_c.add_argument("--value")
	p_c.add_argument("--desc")
	p_c.add_argument("--category")

	p_md = sub.add_parser("md")
	p_md.add_argument("--file", required=True)
	p_md.add_argument("--symbol")
	p_md.add_argument("--allow-create", action="store_true", help="Allow creating parent symbol if missing")
	p_md.add_argument("--kind", help="Override kind; default function", default="function")

	args = parser.parse_args()
	if args.mode == "symbol":
		cmd_symbol(args)
	elif args.mode == "example":
		cmd_example(args)
	elif args.mode == "constant":
		cmd_constant(args)
	elif args.mode == "md":
		cmd_md(args)
	else:
		fail("unknown mode")


if __name__ == "__main__":
	main()

