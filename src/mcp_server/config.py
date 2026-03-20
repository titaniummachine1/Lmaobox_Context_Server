import os
from pathlib import Path

# Project roots
ROOT_DIR = Path(__file__).resolve().parents[2]
DATA_DIR = ROOT_DIR / "data"
PREFERRED_SMART_CONTEXT_DIR = ROOT_DIR / "smart_context"
LEGACY_SMART_CONTEXT_DIR = DATA_DIR / "smart_context"
SMART_CONTEXT_DIR = PREFERRED_SMART_CONTEXT_DIR if (PREFERRED_SMART_CONTEXT_DIR / "lmaobox_lua_api").exists() else LEGACY_SMART_CONTEXT_DIR
TYPES_DIR = ROOT_DIR / "types"

# Runtime configuration
# Align with crawler output so MCP reads the same graph DB by default.
DB_PATH = Path(os.getenv("MCP_DB_PATH", ROOT_DIR / ".cache" / "docs-graph.db"))
DOCS_INDEX_PATH = TYPES_DIR / "docs-index.json"
DEFAULT_HOST = os.getenv("MCP_HOST", "127.0.0.1")
DEFAULT_PORT = int(os.getenv("MCP_PORT", "8765"))
DEFAULT_ENCODING = "utf-8"

