#!/usr/bin/env python3
"""Diagnose MCP server issues."""
import sys
import traceback
from pathlib import Path

print("="*70)
print("MCP Server Diagnosis")
print("="*70)

# Check paths
print("\n[1] Checking paths...")
try:
    from src.mcp_server.config import DB_PATH, SMART_CONTEXT_DIR, TYPES_DIR, ROOT_DIR
    print(f"  ROOT_DIR: {ROOT_DIR}")
    print(f"  DB_PATH: {DB_PATH}")
    print(f"  DB parent exists: {DB_PATH.parent.exists()}")
    print(f"  SMART_CONTEXT_DIR: {SMART_CONTEXT_DIR}")
    print(f"  SMART_CONTEXT_DIR exists: {SMART_CONTEXT_DIR.exists()}")
    print(f"  TYPES_DIR: {TYPES_DIR}")
    print(f"  TYPES_DIR exists: {TYPES_DIR.exists()}")
except Exception as e:
    print(f"  ERROR: {e}")
    traceback.print_exc()
    sys.exit(1)

# Test imports
print("\n[2] Testing imports...")
try:
    from src.mcp_server.server import get_types, get_smart_context
    print("  ✓ Server functions imported")
except Exception as e:
    print(f"  ERROR: {e}")
    traceback.print_exc()
    sys.exit(1)

# Test get_types
print("\n[3] Testing get_types('Draw')...")
try:
    result = get_types("Draw")
    print(f"  ✓ Success! Type: {type(result)}")
    if isinstance(result, dict):
        print(f"    Keys: {list(result.keys())}")
        if 'signature' in result:
            print(f"    Signature: {result['signature']}")
except Exception as e:
    print(f"  ERROR: {e}")
    traceback.print_exc()

# Test get_smart_context
print("\n[4] Testing get_smart_context('custom.normalize_vector')...")
try:
    result = get_smart_context("custom.normalize_vector")
    if isinstance(result, dict) and 'content' in result:
        print(f"  ✓ Found content: {len(result.get('content', ''))} chars")
    else:
        print(f"  Result: {result}")
except Exception as e:
    print(f"  ERROR: {e}")
    traceback.print_exc()

# Test stdio server import
print("\n[5] Testing stdio server import...")
try:
    from src.mcp_server.mcp_stdio import run_stdio_server
    print("  ✓ Stdio server imported")
except Exception as e:
    print(f"  ERROR: {e}")
    traceback.print_exc()
    sys.exit(1)

print("\n" + "="*70)
print("Diagnosis complete!")
print("="*70)
