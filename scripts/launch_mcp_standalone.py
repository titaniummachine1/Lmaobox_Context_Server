#!/usr/bin/env python
"""Standalone launcher for MCP server - can be run from any directory."""
import os
import sys
from pathlib import Path

# Get this script's directory and compute repo root
SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parent

# Change to repo root and add to path
os.chdir(REPO_ROOT)
sys.path.insert(0, str(REPO_ROOT))

# Now import and run
from src.mcp_server.server import run_server  # noqa: E402

if __name__ == "__main__":
    host = os.getenv("MCP_HOST", "127.0.0.1")
    port = int(os.getenv("MCP_PORT", "8765"))
    run_server(host=host, port=port)

