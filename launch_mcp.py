#!/usr/bin/env python
"""MCP server launcher - placed in repo root to avoid path issues."""
import os
import sys
import subprocess
from pathlib import Path

# This file is in repo root, so parent is repo root
REPO_ROOT = Path(__file__).resolve().parent

# Change to repo root and add to path
os.chdir(REPO_ROOT)
sys.path.insert(0, str(REPO_ROOT))

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

# Now import and run stdio MCP server
from src.mcp_server.mcp_stdio import run_stdio_server  # noqa: E402

if __name__ == "__main__":
    run_stdio_server()

