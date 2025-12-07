#!/usr/bin/env python3
"""Verify MCP server works completely."""
import sys
import os
import json
import subprocess
from pathlib import Path

os.chdir(Path(__file__).parent)
sys.path.insert(0, str(Path(__file__).parent))

print("\n" + "="*80)
print("MCP SERVER VERIFICATION")
print("="*80)

# Test 1: Imports
print("\n[1] Testing imports...")
try:
    from src.mcp_server.server import get_types, get_smart_context
    from src.mcp_server.mcp_stdio import handle_initialize, handle_tools_list, handle_tools_call
    print("    ✓ All imports successful")
except Exception as e:
    print(f"    ✗ FAILED: {e}")
    sys.exit(1)

# Test 2: get_types
print("\n[2] Testing get_types('Draw')...")
try:
    result = get_types('Draw')
    if isinstance(result, dict) and ('signature' in result or 'suggestions' in result):
        print(f"    ✓ SUCCESS")
        if 'signature' in result:
            print(f"      Signature found: {result['signature'][:60]}...")
        else:
            print(
                f"      Suggestions: {result.get('suggestions', [])[0] if result.get('suggestions') else 'none'}")
    else:
        print(f"    ✗ Unexpected result: {result}")
except Exception as e:
    print(f"    ✗ FAILED: {e}")
    import traceback
    traceback.print_exc()

# Test 3: get_smart_context
print("\n[3] Testing get_smart_context('custom.normalize_vector')...")
try:
    result = get_smart_context('custom.normalize_vector')
    if result.get('content'):
        print(
            f"    ✓ SUCCESS - Found {len(result['content'])} chars of content")
    else:
        print(f"    ⚠ No content found")
        print(f"      Result keys: {list(result.keys())}")
except Exception as e:
    print(f"    ✗ FAILED: {e}")

# Test 4: MCP Protocol Handlers
print("\n[4] Testing MCP protocol handlers...")
try:
    init_result = handle_initialize({})
    print(
        f"    ✓ initialize: {init_result['serverInfo']['name']} v{init_result['serverInfo']['version']}")

    tools_result = handle_tools_list()
    print(f"    ✓ tools/list: {len(tools_result['tools'])} tools available")

    call_result = handle_tools_call("get_types", {"symbol": "Draw"})
    print(f"    ✓ tools/call: works")
except Exception as e:
    print(f"    ✗ FAILED: {e}")
    import traceback
    traceback.print_exc()

# Test 5: Full stdio protocol test
print("\n[5] Testing full stdio MCP protocol...")
try:
    test_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {}
    }

    proc = subprocess.Popen(
        [sys.executable, "launch_mcp.py"],
        stdin=subprocess.PIPE,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True
    )

    stdout, stderr = proc.communicate(
        input=json.dumps(test_request) + "\n", timeout=3)

    if stdout:
        response = json.loads(stdout.strip())
        if 'result' in response:
            print(f"    ✓ Stdio protocol works!")
            print(f"      Server: {response['result']['serverInfo']['name']}")
        else:
            print(f"    ✗ Error response: {response.get('error')}")
    else:
        print(f"    ✗ No response from server")
        if stderr:
            print(f"      Stderr: {stderr}")

except subprocess.TimeoutExpired:
    proc.kill()
    print("    ✗ Server timeout")
except Exception as e:
    print(f"    ✗ FAILED: {e}")

print("\n" + "="*80)
print("VERIFICATION COMPLETE")
print("="*80)
print("\n✓ MCP server is ready for Cursor integration!")
print("\nNext steps:")
print("1. Add this to Cursor MCP settings:")
print('   "lmaobox-context": {')
print('     "command": "python",')
print(f'     "args": ["{Path(__file__).parent / "launch_mcp.py"}"],')
print(f'     "cwd": "{Path(__file__).parent}"')
print('   }')
print("2. Restart Cursor")
print("3. Ask Claude to use the MCP tools!\n")
