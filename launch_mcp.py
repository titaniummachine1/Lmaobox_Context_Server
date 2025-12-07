#!/usr/bin/env python
"""MCP server launcher - placed in repo root to avoid path issues."""
import os
import sys
from pathlib import Path

# This file is in repo root, so parent is repo root
REPO_ROOT = Path(__file__).resolve().parent

# Change to repo root and add to path
os.chdir(REPO_ROOT)
sys.path.insert(0, str(REPO_ROOT))

# Now import and run stdio MCP server
from src.mcp_server.mcp_stdio import run_stdio_server  # noqa: E402

if __name__ == "__main__":
    run_stdio_server()

