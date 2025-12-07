import os
from pathlib import Path

# Project roots
ROOT_DIR = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT_DIR / "data"
SMART_CONTEXT_DIR = DATA_DIR / "smart_context"
TYPES_DIR = ROOT_DIR / "types"

# Runtime configuration
# Align with crawler output so MCP reads the same graph DB by default.
DB_PATH = Path(os.getenv("MCP_DB_PATH", ROOT_DIR / ".cache" / "docs-graph.db"))
DOCS_INDEX_PATH = TYPES_DIR / "docs-index.json"
DEFAULT_HOST = os.getenv("MCP_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.getenv("MCP_PORT", "8765"))
DEFAULT_ENCODING = "utf-8"

