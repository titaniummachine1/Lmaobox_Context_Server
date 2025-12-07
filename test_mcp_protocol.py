#!/usr/bin/env python3
"""Test MCP protocol communication."""
import json
import subprocess
import sys
from pathlib import Path


def test_mcp_server():
    """Test the MCP server via stdio."""
    repo_root = Path(__file__).resolve().parent
    launch_script = repo_root / "launch_mcp.py"

    print("="*70)
    print("Testing MCP Server Protocol")
    print("="*70)

    # Test 1: Initialize
    print("\n[1] Testing initialize...")
    init_request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "initialize",
        "params": {}
    }

    try:
        proc = subprocess.Popen(
            [sys.executable, str(launch_script)],
            stdin=subprocess.PIPE,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(repo_root)
        )

        stdout, stderr = proc.communicate(
            input=json.dumps(init_request) + "\n", timeout=5)

        if stderr:
            print(f"  Stderr: {stderr}")

        if stdout:
            try:
                response = json.loads(stdout.strip())
                if "result" in response:
                    print(f"  ✓ Initialize successful!")
                    print(
                        f"    Server: {response['result'].get('serverInfo', {}).get('name')}")
                    print(
                        f"    Version: {response['result'].get('serverInfo', {}).get('version')}")
                else:
                    print(f"  ✗ Error: {response.get('error')}")
            except json.JSONDecodeError as e:
                print(f"  ✗ Failed to parse response: {e}")
                print(f"    Output: {stdout}")
        else:
            print("  ✗ No response received")

    except subprocess.TimeoutExpired:
        proc.kill()
        print("  ✗ Timeout waiting for response")
    except Exception as e:
        print(f"  ✗ Error: {e}")
        import traceback
        traceback.print_exc()

    print("\n" + "="*70)
    print("Test complete!")
    print("="*70)
    print("\nNote: The server communicates via JSON-RPC over stdio.")
    print("For full testing, configure it in Cursor/Claude Desktop and use the tools directly.")


if __name__ == "__main__":
    test_mcp_server()
