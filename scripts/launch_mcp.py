import os
import sys
from pathlib import Path


def main() -> None:
	# Resolve repo root from this file location
	script_path = Path(__file__).resolve()
	repo_root = script_path.parents[1]

	# Ensure imports work regardless of current working directory
	os.chdir(repo_root)
	sys.path.insert(0, str(repo_root))

	# Defer import until path is set
	from src.mcp_server.server import run_server  # type: ignore

	host = os.getenv("MCP_HOST", "127.0.0.1")
	port = int(os.getenv("MCP_PORT", "8765"))
	run_server(host=host, port=port)


if __name__ == "__main__":
	main()

