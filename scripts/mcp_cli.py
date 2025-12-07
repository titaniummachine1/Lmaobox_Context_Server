#!/usr/bin/env python
"""
Minimal CLI to call MCP tools without extra noise.
Usage:
  python scripts/mcp_cli.py get_types engine.TraceLine
  python scripts/mcp_cli.py get_smart_context custom.normalize_vector
"""

import json
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(REPO_ROOT))

from src.mcp_server.server import get_smart_context, get_types  # noqa: E402


def main() -> None:
	if len(sys.argv) < 3:
		print("Usage: python scripts/mcp_cli.py <get_types|get_smart_context> <symbol>")
		sys.exit(1)

	tool = sys.argv[1].strip()
	symbol = sys.argv[2].strip()

	if tool == "get_types":
		result = get_types(symbol)
		print(json.dumps(result, indent=2))
	elif tool == "get_smart_context":
		result = get_smart_context(symbol)
		if result is None:
			print(json.dumps({"error": "not found", "symbol": symbol}, indent=2))
		else:
			print(json.dumps(result, indent=2))
	else:
		print(f"Unknown tool: {tool}")
		sys.exit(1)


if __name__ == "__main__":
	main()

