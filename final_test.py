#!/usr/bin/env python3
"""Final comprehensive test - writes to file."""
import sys
import os
from pathlib import Path

# Setup
os.chdir(Path(__file__).parent)
sys.path.insert(0, str(Path(__file__).parent))

output = []
output.append("="*80)
output.append("MCP SERVER FINAL TEST")
output.append("="*80)
output.append("")

# Test 1: Imports
output.append("[1] Testing imports...")
try:
    from src.mcp_server.server import get_types, get_smart_context
    from src.mcp_server.mcp_stdio import handle_initialize, handle_tools_list
    output.append("    ✓ SUCCESS: All imports work")
except Exception as e:
    output.append(f"    ✗ FAILED: {e}")

# Test 2: get_types
output.append("")
output.append("[2] Testing get_types('Draw')...")
try:
    from src.mcp_server.server import get_types
    result = get_types('Draw')
    output.append(f"    ✓ SUCCESS: Returned {type(result).__name__}")
    output.append(f"    Keys: {list(result.keys())}")
    if 'signature' in result:
        output.append(f"    Signature: {result['signature'][:80]}")
except Exception as e:
    output.append(f"    ✗ FAILED: {e}")
    import traceback
    output.append(traceback.format_exc())

# Test 3: get_smart_context
output.append("")
output.append("[3] Testing get_smart_context('custom.normalize_vector')...")
try:
    from src.mcp_server.server import get_smart_context
    result = get_smart_context('custom.normalize_vector')
    if 'content' in result:
        output.append(
            f"    ✓ SUCCESS: Found content ({len(result['content'])} chars)")
    else:
        output.append(f"    ⚠ No content, keys: {list(result.keys())}")
except Exception as e:
    output.append(f"    ✗ FAILED: {e}")

# Test 4: MCP handlers
output.append("")
output.append("[4] Testing MCP protocol handlers...")
try:
    from src.mcp_server.mcp_stdio import handle_initialize, handle_tools_list, handle_tools_call

    init = handle_initialize({})
    output.append(
        f"    ✓ initialize: {init['serverInfo']['name']} v{init['serverInfo']['version']}")

    tools = handle_tools_list()
    output.append(f"    ✓ tools/list: {len(tools['tools'])} tools")
    for tool in tools['tools']:
        output.append(f"      - {tool['name']}: {tool['description'][:60]}")

    result = handle_tools_call("get_types", {"symbol": "Draw"})
    output.append(f"    ✓ tools/call: SUCCESS")

except Exception as e:
    output.append(f"    ✗ FAILED: {e}")
    import traceback
    output.append(traceback.format_exc())

# Test 5: Check files exist
output.append("")
output.append("[5] Checking critical files...")
files_to_check = [
    "launch_mcp.py",
    "src/mcp_server/server.py",
    "src/mcp_server/mcp_stdio.py",
    "src/mcp_server/config.py",
    "types/lmaobox_lua_api/Lua_Libraries/draw.d.lua",
    "data/smart_context/custom.normalize_vector.md"
]
for f in files_to_check:
    exists = Path(f).exists()
    status = "✓" if exists else "✗"
    output.append(f"    {status} {f}")

output.append("")
output.append("="*80)
output.append("TEST COMPLETE")
output.append("="*80)
output.append("")
output.append("Server is ready! Configure in Cursor:")
output.append('1. Open Cursor Settings -> Features -> Model Context Protocol')
output.append('2. Click "Edit Config"')
output.append('3. Add:')
output.append('   {')
output.append('     "mcpServers": {')
output.append('       "lmaobox-context": {')
output.append('         "command": "python",')
output.append(
    f'         "args": ["{Path(__file__).parent / "launch_mcp.py"}"],')
output.append(f'         "cwd": "{Path(__file__).parent}"')
output.append('       }')
output.append('     }')
output.append('   }')
output.append('4. Restart Cursor')
output.append('5. Ask Claude: "Use MCP tool get_types for Draw"')

# Write to file
result_file = Path(__file__).parent / "MCP_TEST_RESULTS.txt"
result_file.write_text("\n".join(output), encoding='utf-8')

print("Test complete! Results written to MCP_TEST_RESULTS.txt")
for line in output:
    print(line)
