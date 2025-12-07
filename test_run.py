#!/usr/bin/env python3
"""Test the MCP server components."""
import sys
import json
from pathlib import Path

# Add repo to path
repo_root = Path(__file__).resolve().parent
sys.path.insert(0, str(repo_root))

print("="*70, file=sys.stderr)
print("MCP Server Component Test", file=sys.stderr)
print("="*70, file=sys.stderr)

# Test 1: Import and config
print("\n[TEST 1] Checking configuration...", file=sys.stderr)
try:
    from src.mcp_server.config import DB_PATH, SMART_CONTEXT_DIR, TYPES_DIR
    print(f"✓ DB_PATH: {DB_PATH}", file=sys.stderr)
    print(f"✓ TYPES_DIR exists: {TYPES_DIR.exists()}", file=sys.stderr)
    print(
        f"✓ SMART_CONTEXT_DIR exists: {SMART_CONTEXT_DIR.exists()}", file=sys.stderr)
except Exception as e:
    print(f"✗ Config error: {e}", file=sys.stderr)
    sys.exit(1)

# Test 2: Test get_types
print("\n[TEST 2] Testing get_types('Draw')...", file=sys.stderr)
try:
    from src.mcp_server.server import get_types
    result = get_types("Draw")
    print(f"✓ Result type: {type(result).__name__}", file=sys.stderr)
    if isinstance(result, dict):
        print(f"✓ Keys: {list(result.keys())}", file=sys.stderr)
        if 'signature' in result:
            print(f"✓ Found signature", file=sys.stderr)
            with open("test_result_types.json", "w") as f:
                json.dump({"test": "get_types", "result": result},
                          f, indent=2, default=str)
        elif 'suggestions' in result:
            print(
                f"⚠ No signature found, got suggestions: {result['suggestions'][:3]}", file=sys.stderr)
except Exception as e:
    print(f"✗ get_types error: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc(file=sys.stderr)

# Test 3: Test get_smart_context
print("\n[TEST 3] Testing get_smart_context('custom.normalize_vector')...", file=sys.stderr)
try:
    from src.mcp_server.server import get_smart_context
    result = get_smart_context("custom.normalize_vector")
    if 'content' in result:
        print(
            f"✓ Found context, {len(result['content'])} chars", file=sys.stderr)
    else:
        print(f"⚠ No content, got: {list(result.keys())}", file=sys.stderr)
    with open("test_result_context.json", "w") as f:
        json.dump({"test": "get_smart_context", "result": result},
                  f, indent=2, default=str)
except Exception as e:
    print(f"✗ get_smart_context error: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc(file=sys.stderr)

# Test 4: Test MCP tools
print("\n[TEST 4] Testing MCP tool handlers...", file=sys.stderr)
try:
    from src.mcp_server.mcp_stdio import handle_initialize, handle_tools_list, handle_tools_call

    init = handle_initialize({})
    print(f"✓ initialize: {init['serverInfo']['name']}", file=sys.stderr)

    tools = handle_tools_list()
    print(f"✓ tools/list: {len(tools['tools'])} tools", file=sys.stderr)

    result = handle_tools_call("get_types", {"symbol": "Draw"})
    print(f"✓ tools/call get_types: {type(result)}", file=sys.stderr)

    result = handle_tools_call("get_smart_context", {
                               "symbol": "engine.TraceLine"})
    print(f"✓ tools/call get_smart_context: {type(result)}", file=sys.stderr)

    with open("test_result_mcp.json", "w") as f:
        json.dump({
            "initialize": init,
            "tools_count": len(tools['tools']),
        }, f, indent=2, default=str)

except Exception as e:
    print(f"✗ MCP tools error: {e}", file=sys.stderr)
    import traceback
    traceback.print_exc(file=sys.stderr)

print("\n" + "="*70, file=sys.stderr)
print("✓ All tests completed!", file=sys.stderr)
print("="*70, file=sys.stderr)
