#!/usr/bin/env python3
from src.mcp_server.mcp_stdio import handle_initialize
from src.mcp_server.server import get_types, get_smart_context
import sys
import os
os.chdir(r'c:\Users\Terminatort8000\Desktop\Lmaobox_Context_Server')
sys.path.insert(0, '.')

# Test 1: Basic import

# Test get_types
result = get_types('Draw')
with open('test_output.log', 'w') as f:
    f.write("TEST RESULTS\n")
    f.write("=" * 70 + "\n\n")

    f.write("1. get_types('Draw'):\n")
    f.write(str(result) + "\n\n")

    f.write("2. get_smart_context('custom.normalize_vector'):\n")
    ctx = get_smart_context('custom.normalize_vector')
    f.write(str(ctx) + "\n\n")

    f.write("3. handle_initialize():\n")
    init = handle_initialize({})
    f.write(str(init) + "\n\n")

    f.write("=" * 70 + "\n")
    f.write("✓ All functions executed successfully!\n")

print("Test complete - check test_output.log")
