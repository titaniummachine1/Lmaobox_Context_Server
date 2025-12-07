#!/usr/bin/env bash
# Minimal MCP tool caller (bash). Usage:
# ./scripts/mcp_tool.sh get_types engine.TraceLine
# ./scripts/mcp_tool.sh get_smart_context custom.normalize_vector

set -euo pipefail
cd "$(dirname "$0")/.."

tool="${1:-}"
symbol="${2:-}"

if [[ -z "$tool" || -z "$symbol" ]]; then
  echo "Usage: $0 <get_types|get_smart_context> <symbol>"
  exit 1
fi

python scripts/mcp_cli.py "$tool" "$symbol"

