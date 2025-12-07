#!/usr/bin/env python3
"""Test script to debug MCP server startup."""
import sys
import traceback
from pathlib import Path

print("="*60)
print("MCP Server Test")
print("="*60)

# Check Python version
print(f"Python: {sys.version}")
print(f"CWD: {Path.cwd()}")

try:
    print("\n1. Testing imports...")
    from src.mcp_server.config import DB_PATH, SMART_CONTEXT_DIR, TYPES_DIR, DEFAULT_HOST, DEFAULT_PORT
    print(f"   ✓ Config loaded")
    print(f"     DB_PATH: {DB_PATH}")
    print(f"     SMART_CONTEXT_DIR: {SMART_CONTEXT_DIR}")
    print(f"     TYPES_DIR: {TYPES_DIR}")
    print(f"     Host:Port: {DEFAULT_HOST}:{DEFAULT_PORT}")

    from src.mcp_server.server import get_types, get_smart_context
    print(f"   ✓ Server functions imported")

    print("\n2. Testing get_types('Draw')...")
    result = get_types("Draw")
    print(f"   ✓ Result: {result}")

    print("\n3. Testing get_smart_context('render.text')...")
    result = get_smart_context("render.text")
    print(f"   ✓ Result keys: {result.keys()}")

    print("\n4. Starting server...")
    from src.mcp_server.server import run_server
    print(f"   Starting on {DEFAULT_HOST}:{DEFAULT_PORT}")
    run_server(DEFAULT_HOST, DEFAULT_PORT)

except KeyboardInterrupt:
    print("\n✓ Interrupted")
    sys.exit(0)
except Exception as e:
    print(f"\n✗ Error: {e}")
    traceback.print_exc()
    sys.exit(1)
