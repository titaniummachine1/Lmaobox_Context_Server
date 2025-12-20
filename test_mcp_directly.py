#!/usr/bin/env python
"""Test MCP server timeout directly without Windsurf."""
import sys
import json
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent / "src"))

from mcp_server.mcp_stdio import _run_bundle

print("Testing timeout directly...", file=sys.stderr)

try:
    result = _run_bundle({
        "projectDir": r"c:\Users\Terminatort8000\Desktop\Lmaobox_Context_Server\test_hang"
    })
    print(f"Result: {json.dumps(result, indent=2)}", file=sys.stderr)
except Exception as e:
    print(f"Exception caught: {type(e).__name__}", file=sys.stderr)
    print(f"Message: {e}", file=sys.stderr)
    sys.exit(1)
