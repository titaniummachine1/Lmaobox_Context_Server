#!/usr/bin/env python
"""MCP server launcher - directly invokes Go binary for guaranteed 15s timeout."""
import os
import sys
import subprocess
from pathlib import Path

# This file is in repo root, so parent is repo root
REPO_ROOT = Path(__file__).resolve().parent

# Change to repo root
os.chdir(REPO_ROOT)

def ensure_dependencies():
    """Ensure all dependencies are set up for frictionless usage."""
    install_script = REPO_ROOT / "automations" / "install_lua.py"
    
    if install_script.exists():
        try:
            subprocess.run(
                [sys.executable, str(install_script)],
                capture_output=True,
                timeout=120,
                check=False
            )
        except:
            pass

# Auto-setup dependencies on startup
ensure_dependencies()

# Run Go MCP server directly - has hard 15s timeout enforcement
if __name__ == "__main__":
    go_binary = REPO_ROOT / "lmaobox-context-server.exe"
    
    if not go_binary.exists():
        print(f"ERROR: Go binary not found at {go_binary}", file=sys.stderr)
        print("Run: go build -o lmaobox-context-server.exe main.go", file=sys.stderr)
        sys.exit(1)
    
    # Execute Go binary directly - it handles all MCP protocol
    # Bundle tool has HARD 15s timeout with 7 enforcement checkpoints
    # Even if code freezes, context timeout will kill it
    try:
        result = subprocess.run(
            [str(go_binary)],
            stdin=sys.stdin,
            stdout=sys.stdout,
            stderr=sys.stderr,
            check=False
        )
        sys.exit(result.returncode)
    except KeyboardInterrupt:
        sys.exit(0)
    except Exception as e:
        print(f"ERROR: Failed to run Go MCP server: {e}", file=sys.stderr)
        sys.exit(1)

