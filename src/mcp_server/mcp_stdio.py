#!/usr/bin/env python
"""MCP stdio server - speaks JSON-RPC protocol over stdin/stdout."""
import json
import logging
import os
import subprocess
import sys
from pathlib import Path
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
            },
            {
                "name": "bundle",
                "description": "Bundle and deploy Lua to %LOCALAPPDATA%/lua. USAGE: Provide path to folder containing Main.lua. That folder IS the bundle root - all require() calls resolve from there. Works with any workspace, not just this repo.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "projectDir": {
                            "type": "string",
                            "description": "Path to folder containing Main.lua. Can be absolute (C:/my_project) or relative to workspace (my_project/src). This folder becomes the bundle root. MUST contain Main.lua unless entryFile is specified."
                        },
                        "entryFile": {
                            "type": "string",
                            "description": "Entry file name only (not path). Defaults to Main.lua (case-insensitive). If not Main.lua, only that file deploys (no bundling)."
                        },
                        "bundleOutputDir": {
                            "type": "string",
                            "description": "Override for build output. Can be absolute or relative to projectDir. Defaults to projectDir/build."
                        },
                        "deployDir": {
                            "type": "string",
                            "description": "Override deployment target. Can be absolute or relative to projectDir. Defaults to %LOCALAPPDATA%/lua."
                        }
                    },
                    "required": ["projectDir"]
                }
            }
        ]
    }


def _run_bundle(arguments: dict) -> dict:
    """Run the bundle-and-deploy automation and return its output."""
    project_dir = arguments.get("projectDir")
    if not project_dir:
        raise ValueError(
            "projectDir is required. Specify directory containing Lua files (e.g., 'my_project')")

    # Resolve project_dir: if absolute, use as-is; if relative, resolve from CWD
    project_path = Path(project_dir).expanduser()
    if not project_path.is_absolute():
        # Try relative to current working directory (Cursor workspace)
        project_path = Path.cwd() / project_path

    project_path = project_path.resolve()

    if not project_path.exists():
        raise FileNotFoundError(
            f"Project directory not found: {project_path}\n"
            f"Provided: {project_dir}\n"
            f"CWD: {Path.cwd()}"
        )

    # Find bundle script: first check MCP server's repo, then check PATH
    mcp_server_root = Path(__file__).resolve().parents[2]
    script_path = mcp_server_root / "automations" / "bundle-and-deploy.js"

    if not script_path.exists():
        raise FileNotFoundError(
            f"bundle script missing: {script_path}\n"
            f"Ensure automations are installed in the MCP server directory."
        )

    env = os.environ.copy()
    env["PROJECT_DIR"] = str(project_path)

    entry_file = arguments.get("entryFile")
    if entry_file:
        env["ENTRY_FILE"] = str(entry_file)

    bundle_output_dir = arguments.get("bundleOutputDir")
    if bundle_output_dir:
        bundle_output_path = Path(bundle_output_dir).expanduser()
        if not bundle_output_path.is_absolute():
            bundle_output_path = project_path / bundle_output_path
        env["BUNDLE_OUTPUT_DIR"] = str(bundle_output_path.resolve())

    deploy_dir = arguments.get("deployDir")
    if deploy_dir:
        deploy_path = Path(deploy_dir).expanduser()
        if not deploy_path.is_absolute():
            deploy_path = project_path / deploy_dir
        env["DEPLOY_DIR"] = str(deploy_path.resolve())

    # Run bundler from MCP server location (it needs node_modules)
    try:
        process = subprocess.run(
            ["node", str(script_path)],
            cwd=str(mcp_server_root),
            env=env,
            capture_output=True,
            text=True,
            check=False,
            timeout=10.0,
        )
    except subprocess.TimeoutExpired as e:
        raise RuntimeError(
            f"Bundle operation timed out after 10 seconds.\n"
            f"project_dir: {env.get('PROJECT_DIR')}\n"
            f"This usually indicates:\n"
            f"  1. Infinite loop in bundler script\n"
            f"  2. Hanging file I/O operation\n"
            f"  3. Node.js process stuck\n"
            f"Captured output before timeout:\n"
            f"stdout: {e.stdout.decode('utf-8') if e.stdout else '<none>'}\n"
            f"stderr: {e.stderr.decode('utf-8') if e.stderr else '<none>'}"
        )

    result = {
        "project_dir": env.get("PROJECT_DIR"),
        "bundle_output_dir": env.get("BUNDLE_OUTPUT_DIR"),
        "deploy_dir": env.get("DEPLOY_DIR"),
        "stdout": process.stdout.strip(),
        "stderr": process.stderr.strip(),
        "exit_code": process.returncode,
    }

    if process.returncode != 0:
        raise RuntimeError(
            f"Bundle failed (exit {process.returncode}).\n"
            f"project_dir: {result['project_dir']}\n"
            f"bundle_output_dir: {result['bundle_output_dir'] or '<default>'}\n"
            f"deploy_dir: {result['deploy_dir'] or '<default>'}\n"
            f"stdout:\n{result['stdout'] or '<empty>'}\n"
            f"stderr:\n{result['stderr'] or '<empty>'}"
        )

    return result


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
        suggestion_text = f"Did you mean: {did_you_mean}\n\nSuggestions:\n" + "\n".join(
            suggestions) if did_you_mean else "No smart context found. Suggestions:\n" + "\n".join(suggestions)
        return {"content": [{"type": "text", "text": suggestion_text}]}

    elif name == "bundle":
        result = _run_bundle(arguments)
        output_lines = [
            f"project_dir: {result['project_dir']}",
            f"bundle_output_dir: {result['bundle_output_dir'] or '<default>'}",
            f"deploy_dir: {result['deploy_dir'] or '<default LocalAppData/lua>'}",
            f"exit_code: {result['exit_code']}",
            "",
            result["stdout"] or "<no output>",
        ]
        if result["stderr"]:
            output_lines.extend(["", "=== stderr ===", result["stderr"]])
        return {"content": [{"type": "text", "text": "\n".join(output_lines)}]}

    else:
        raise ValueError(f"Unknown tool: {name}")


def run_stdio_server() -> None:
    """Run MCP server over stdio."""
    logging.basicConfig(level=logging.WARNING,
                        format="%(message)s", stream=sys.stderr)

    while True:
        try:
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
                        response["result"] = handle_tools_call(
                            tool_name, tool_args)
                    else:
                        response["error"] = {
                            "code": -32601, "message": f"Method not found: {method}"}
                except Exception as exc:
                    LOG.exception("Error handling request")
                    response["error"] = {"code": -32603, "message": str(exc)}

                sys.stdout.write(json.dumps(response) + "\n")
                sys.stdout.flush()

            except json.JSONDecodeError:
                # Invalid JSON - send error if we have an id
                if 'request' in locals() and isinstance(request, dict) and request.get("id") is not None:
                    response = {
                        "jsonrpc": "2.0",
                        "id": request.get("id"),
                        "error": {"code": -32700, "message": "Parse error"}
                    }
                    sys.stdout.write(json.dumps(response) + "\n")
                    sys.stdout.flush()
            except Exception as exc:
                LOG.exception("Unexpected error in request handling")
                # Only respond if we have a valid request with id
                if 'request' in locals() and isinstance(request, dict) and request.get("id") is not None:
                    response = {
                        "jsonrpc": "2.0",
                        "id": request.get("id"),
                        "error": {"code": -32603, "message": str(exc)}
                    }
                    sys.stdout.write(json.dumps(response) + "\n")
                    sys.stdout.flush()
        except KeyboardInterrupt:
            break
        except Exception as exc:
            LOG.exception("Fatal error in stdio loop")
            break


if __name__ == "__main__":
    run_stdio_server()
