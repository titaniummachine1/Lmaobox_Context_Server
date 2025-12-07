#!/usr/bin/env python
"""MCP stdio server - speaks JSON-RPC protocol over stdin/stdout."""
import json
import logging
import sys
from typing import Any

from .server import get_smart_context, get_types

LOG = logging.getLogger("mcp_stdio")

# MCP protocol message handlers
def handle_initialize(params: dict) -> dict:
	"""Handle MCP initialize request."""
	return {
		"protocolVersion": "2024-11-05",
		"capabilities": {
			"tools": {}
		},
		"serverInfo": {
			"name": "lmaobox-context",
			"version": "1.0.0"
		}
	}


def handle_tools_list() -> dict:
	"""List available MCP tools."""
	return {
		"tools": [
			{
				"name": "get_types",
				"description": "Get type information for a Lmaobox Lua API symbol",
				"inputSchema": {
					"type": "object",
					"properties": {
						"symbol": {
							"type": "string",
							"description": "Symbol name (e.g., 'Draw', 'render.text')"
						}
					},
					"required": ["symbol"]
				}
			},
			{
				"name": "get_smart_context",
				"description": "Get curated smart context for a symbol",
				"inputSchema": {
					"type": "object",
					"properties": {
						"symbol": {
							"type": "string",
							"description": "Symbol name"
						}
					},
					"required": ["symbol"]
				}
			}
		]
	}


def handle_tools_call(name: str, arguments: dict) -> dict:
	"""Handle tool call."""
	if name == "get_types":
		symbol = arguments.get("symbol", "")
		if not symbol:
			raise ValueError("symbol is required")
		result = get_types(symbol)
		return {"content": [{"type": "text", "text": json.dumps(result, indent=2)}]}

	elif name == "get_smart_context":
		symbol = arguments.get("symbol", "")
		if not symbol:
			raise ValueError("symbol is required")
		result = get_smart_context(symbol)
		# Check if we got content or suggestions
		if result.get("content"):
			return {"content": [{"type": "text", "text": result["content"]}]}
		# Return suggestions if no content found
		suggestions = result.get("suggestions", [])
		did_you_mean = result.get("did_you_mean")
		suggestion_text = f"Did you mean: {did_you_mean}\n\nSuggestions:\n" + "\n".join(suggestions) if did_you_mean else "No smart context found. Suggestions:\n" + "\n".join(suggestions)
		return {"content": [{"type": "text", "text": suggestion_text}]}

	else:
		raise ValueError(f"Unknown tool: {name}")


def run_stdio_server() -> None:
	"""Run MCP server over stdio."""
	logging.basicConfig(level=logging.WARNING, format="%(message)s", stream=sys.stderr)
	
	while True:
		line = sys.stdin.readline()
		if not line:
			break
		
		line = line.strip()
		if not line:
			continue

		try:
			request = json.loads(line)
			method = request.get("method")
			params = request.get("params", {})
			request_id = request.get("id")
			
			# Skip notifications (requests without id) - don't respond
			if request_id is None:
				continue

			response: dict[str, Any] = {"jsonrpc": "2.0", "id": request_id}

			try:
				if method == "initialize":
					response["result"] = handle_initialize(params)
				elif method == "tools/list":
					response["result"] = handle_tools_list()
				elif method == "tools/call":
					tool_name = params.get("name", "")
					tool_args = params.get("arguments", {})
					response["result"] = handle_tools_call(tool_name, tool_args)
				else:
					response["error"] = {"code": -32601, "message": f"Method not found: {method}"}
			except Exception as exc:
				response["error"] = {"code": -32603, "message": str(exc)}

			sys.stdout.write(json.dumps(response) + "\n")
			sys.stdout.flush()

		except json.JSONDecodeError as exc:
			# Invalid JSON - send error if we have an id
			if 'request' in locals() and request.get("id") is not None:
				response = {
					"jsonrpc": "2.0",
					"id": request.get("id"),
					"error": {"code": -32700, "message": "Parse error"}
				}
				sys.stdout.write(json.dumps(response) + "\n")
				sys.stdout.flush()
		except Exception as exc:
			# Only respond if we have a valid request with id
			if 'request' in locals() and request.get("id") is not None:
				response = {
					"jsonrpc": "2.0",
					"id": request.get("id"),
					"error": {"code": -32603, "message": str(exc)}
				}
				sys.stdout.write(json.dumps(response) + "\n")
				sys.stdout.flush()


if __name__ == "__main__":
	run_stdio_server()

