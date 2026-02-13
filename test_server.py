#!/usr/bin/env python3
"""
MCP Server Diagnostic Tool
Tests all components to identify what's not working.
"""
import json
import sys
import time
import urllib.request
import urllib.error
from urllib.request import Request

MCP_PORT = 8765
RUNNER_PORT = 27182

def test_endpoint(url, method="GET", data=None, timeout=3):
    """Test an endpoint and return (success, response_or_error)."""
    try:
        if data and method == "POST":
            req = Request(url, data=json.dumps(data).encode(),
                         headers={"Content-Type": "application/json"},
                         method="POST")
        else:
            req = Request(url, method=method)

        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return True, resp.read().decode()
    except urllib.error.HTTPError as e:
        return False, f"HTTP {e.code}: {e.reason}"
    except Exception as e:
        return False, str(e)


def run_diagnostics():
    """Run all diagnostic tests."""
    print("=" * 60)
    print("MCP Server Diagnostics")
    print("=" * 60)

    all_passed = True

    # Test 1: MCP Health
    print("\n[1/8] Testing MCP Health Endpoint...")
    ok, resp = test_endpoint(f"http://127.0.0.1:{MCP_PORT}/health")
    if ok and '"status": "ok"' in resp:
        print("   ✓ MCP server is running")
    else:
        print(f"   ✗ FAILED: {resp}")
        all_passed = False

    # Test 2: Lua Runner Server
    print("\n[2/8] Testing Lua Runner Server...")
    ok, resp = test_endpoint(f"http://127.0.0.1:{RUNNER_PORT}/getscript")
    if ok:
        print("   ✓ Lua runner server is running")
    else:
        print(f"   ✗ FAILED: {resp}")
        all_passed = False

    # Test 3: Lua State Endpoint
    print("\n[3/8] Testing /lua/state...")
    ok, resp = test_endpoint(f"http://127.0.0.1:{MCP_PORT}/lua/state")
    if ok:
        try:
            data = json.loads(resp)
            print(f"   ✓ State: {data.get('state', 'unknown')}")
        except:
            print(f"   ✗ Invalid JSON: {resp[:50]}")
            all_passed = False
    else:
        print(f"   ✗ FAILED: {resp}")
        all_passed = False

    # Test 4: Script Execution (POST)
    print("\n[4/8] Testing Script Execution...")
    ok, resp = test_endpoint(
        f"http://127.0.0.1:{MCP_PORT}/lua/execute",
        method="POST",
        data={"script": "print('test')"}
    )
    if ok:
        try:
            data = json.loads(resp)
            if data.get("success"):
                print(f"   ✓ Script queued: {data.get('execution_id')}")
            else:
                print(f"   ✗ Queue failed: {data}")
                all_passed = False
        except:
            print(f"   ✗ Invalid JSON: {resp[:50]}")
            all_passed = False
    else:
        print(f"   ✗ FAILED: {resp}")
        all_passed = False

    # Test 5: Script Fetch from Runner
    print("\n[5/8] Testing Script Fetch...")
    ok, resp = test_endpoint(f"http://127.0.0.1:{RUNNER_PORT}/getscript")
    if ok and "print('test')" in resp:
        print("   ✓ Script available for execution")
    elif ok:
        print(f"   ⚠ Script not yet available (normal if just queued)")
    else:
        print(f"   ✗ FAILED: {resp}")
        all_passed = False

    # Test 6: Debug Session Start
    print("\n[6/8] Testing Debug Session...")
    ok, resp = test_endpoint(
        f"http://127.0.0.1:{MCP_PORT}/lua/debug",
        method="POST",
        data={"duration_seconds": 5}
    )
    if ok:
        try:
            data = json.loads(resp)
            if data.get("success"):
                print(f"   ✓ Debug session: {data.get('session_id')}")
            else:
                print(f"   ✗ Debug start failed: {data}")
                all_passed = False
        except:
            print(f"   ✗ Invalid JSON: {resp[:50]}")
            all_passed = False
    else:
        print(f"   ✗ FAILED: {resp}")
        all_passed = False

    # Test 7: Debug Status
    print("\n[7/8] Testing Debug Status...")
    ok, resp = test_endpoint(f"http://127.0.0.1:{MCP_PORT}/lua/debug_status")
    if ok:
        try:
            data = json.loads(resp)
            print(f"   ✓ Debug active: {data.get('active', False)}")
        except:
            print(f"   ✗ Invalid JSON: {resp[:50]}")
            all_passed = False
    else:
        print(f"   ✗ FAILED: {resp}")
        all_passed = False

    # Test 8: Stop Debug
    print("\n[8/8] Testing Debug Stop...")
    ok, resp = test_endpoint(
        f"http://127.0.0.1:{MCP_PORT}/lua/debug_stop",
        method="POST"
    )
    if ok:
        print("   ✓ Debug session stopped")
    else:
        print(f"   ✗ FAILED: {resp}")
        all_passed = False

    # Summary
    print("\n" + "=" * 60)
    if all_passed:
        print("✓ All tests passed! Server is working correctly.")
        print("\nTo use:")
        print("  1. Load lua_runner_helper.lua in Lmaobox")
        print("  2. Run: python lua_runner_cli.py execute -c \"print(123)\"")
        return 0
    else:
        print("✗ Some tests failed. Check output above.")
        print("\nTroubleshooting:")
        print("  - Ensure no other process uses ports 8765 or 27182")
        print("  - Check that python -m src.mcp_server.server is running")
        print("  - Verify firewall allows localhost connections")
        return 1


if __name__ == "__main__":
    sys.exit(run_diagnostics())
