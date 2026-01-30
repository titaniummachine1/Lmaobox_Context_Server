#!/usr/bin/env python
"""MCP stdio server - speaks JSON-RPC protocol over stdin/stdout."""
import json
import logging
import os
import subprocess
import sys
import tempfile
import threading
import queue
import time
import uuid
from pathlib import Path
from typing import Any, Optional

# Global job tracking for async bundle operations
_bundle_jobs: dict[str, dict] = {}

from .server import get_smart_context, get_types

LOG = logging.getLogger("mcp_stdio")

# Lua compiler detection - REQUIRES Lua 5.4+ (prefers 5.5)
def find_luac() -> tuple[str, str]:
    """Find Lua 5.4+ compiler. Returns (command, version). Rejects older versions. Prioritizes 5.5."""
    mcp_root = Path(__file__).resolve().parents[2]
    bundled_lua_dir = mcp_root / "automations" / "bin" / "lua"
    
    candidates = [
        (str(bundled_lua_dir / "luac55.exe"), "5.5"),
        (str(bundled_lua_dir / "luac5.5.exe"), "5.5"),
        (str(bundled_lua_dir / "luac.exe"), "5.5"),
        ("luac5.5", "5.5"),
        ("luac55", "5.5"),
        (str(bundled_lua_dir / "luac54.exe"), "5.4"),
        (str(bundled_lua_dir / "luac5.4.exe"), "5.4"),
        ("luac5.4", "5.4"),
        ("luac54", "5.4"),
    ]
    
    for cmd, version in candidates:
        try:
            if Path(cmd).is_absolute():
                if not Path(cmd).exists():
                    continue
            
            subprocess.run(
                [cmd, "-v"],
                capture_output=True,
                timeout=1.0,
                check=False
            )
            return (cmd, version)
        except (FileNotFoundError, subprocess.TimeoutExpired):
            continue
    
    _auto_setup_lua()
    
    for cmd, version in candidates[:3]:
        try:
            if Path(cmd).exists():
                return (cmd, version)
        except:
            continue
    
    raise FileNotFoundError(
        "Lua 5.4+ required but not found.\n"
        "Install Lua 5.5+ from: https://luabinaries.sourceforge.net/\n"
        "Lmaobox runtime uses Lua 5.4+ features (bitwise operators: &, |, ~, <<).\n"
        "Older Lua versions are NOT supported."
    )

def _auto_setup_lua():
    """Auto-install Lua 5.4+ if not found (prefers 5.5)."""
    try:
        mcp_root = Path(__file__).resolve().parents[2]
        install_script = mcp_root / "automations" / "install_lua.py"
        
        if not install_script.exists():
            LOG.warning("[Lua Setup] Auto-installer script not found, skipping")
            return
        
        LOG.info("[Lua Setup] Auto-installing Lua 5.4+ for frictionless usage...")
        result = subprocess.run(
            [sys.executable, str(install_script)],
            capture_output=True,
            text=True,
            timeout=120,
            check=False
        )
        
        if result.returncode == 0:
            LOG.info("[Lua Setup] Auto-install completed successfully")
        else:
            LOG.warning(f"[Lua Setup] Auto-install had issues: {result.stderr}")
    except Exception as e:
        LOG.warning(f"[Lua Setup] Auto-install failed: {e}")

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
                "description": "Bundle and deploy Lua to %LOCALAPPDATA%/lua. ASYNC: Returns job_id immediately - use check_bundle_status(jobId) to poll for completion. USAGE: Provide path to folder containing Main.lua. That folder IS the bundle root - all require() calls resolve from there. Relative paths resolve from MCP server launch directory (Path.cwd()). Requires MCP server installation with automations/bundle-and-deploy.js and node_modules.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "projectDir": {
                            "type": "string",
                            "description": "Path to folder containing Main.lua. ABSOLUTE paths recommended (C:/my_project). Relative paths resolve from MCP server launch CWD, NOT active workspace. This folder becomes the bundle root. MUST contain Main.lua unless entryFile is specified."
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
            },
            {
                "name": "check_bundle_status",
                "description": "Check status of an async bundle job. Returns job state (running/completed/failed/timeout) and output.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "jobId": {
                            "type": "string",
                            "description": "Job ID returned by bundle tool"
                        }
                    },
                    "required": ["jobId"]
                }
            },
            {
                "name": "luacheck",
                "description": "Validate Lua file syntax and optionally test bundling. Fast syntax check using Lua 5.4+ compiler (supports modern syntax like & operator) OR test if file bundles correctly without deploying. Automatically detects best available Lua compiler (luac5.4, luac54, luac5.5, luac55, or fallback luac). Use this instead of terminal commands to quickly validate Lua code. Returns syntax errors or bundling issues.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "filePath": {
                            "type": "string",
                            "description": "Absolute path to .lua file to check. Can be a single file or Main.lua for bundle validation."
                        },
                        "checkBundle": {
                            "type": "boolean",
                            "description": "If true, test if file/project bundles correctly (dry-run without deploy). If false (default), only run syntax check with luac. Set true for files that use require() or are part of a bundle."
                        }
                    },
                    "required": ["filePath"]
                }
            },
            {
                "name": "trace_bundle_error",
                "description": "Trace bundled Lua error back to source file and line. Parses bundled file structure to find which source module contains the error line.",
                "inputSchema": {
                    "type": "object",
                    "properties": {
                        "bundledFilePath": {
                            "type": "string",
                            "description": "Path to bundled Lua file (e.g., C:/Users/.../AppData/Local/lua/Main.lua)"
                        },
                        "errorLine": {
                            "type": "number",
                            "description": "Line number from error message"
                        }
                    },
                    "required": ["bundledFilePath", "errorLine"]
                }
            }
        ]
    }


def _run_luacheck(arguments: dict) -> dict:
    """Check Lua file syntax or test bundling without deploy."""
    file_path = arguments.get("filePath")
    if not file_path:
        raise ValueError("filePath is required")
    
    file_path = Path(file_path).expanduser().resolve()
    if not file_path.exists():
        raise FileNotFoundError(f"File not found: {file_path}")
    
    if not file_path.suffix == ".lua":
        raise ValueError(f"Not a Lua file: {file_path}")
    
    check_bundle = arguments.get("checkBundle", False)
    
    if check_bundle:
        project_dir = file_path.parent if file_path.name.lower() == "main.lua" else file_path.parent
        
        mcp_server_root = Path(__file__).resolve().parents[2]
        script_path = mcp_server_root / "automations" / "bundle-and-deploy.js"
        
        if not script_path.exists():
            raise FileNotFoundError(f"Bundle script missing: {script_path}")
        
        env = os.environ.copy()
        env["PROJECT_DIR"] = str(project_dir)
        env["DRY_RUN"] = "true"
        
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
        except subprocess.TimeoutExpired:
            raise RuntimeError("Bundle check timed out after 10 seconds")
        
        return {
            "file": str(file_path),
            "check_type": "bundle",
            "stdout": process.stdout.strip(),
            "stderr": process.stderr.strip(),
            "exit_code": process.returncode,
            "valid": process.returncode == 0
        }
    else:
        try:
            luac_cmd, lua_version = find_luac()
            LOG.info(f"Using Lua compiler: {luac_cmd} (version {lua_version})")
            
            process = subprocess.run(
                [luac_cmd, "-p", str(file_path)],
                capture_output=True,
                text=True,
                check=False,
                timeout=5.0,
            )
            
        except FileNotFoundError as e:
            raise RuntimeError(str(e))
        except subprocess.TimeoutExpired:
            raise RuntimeError("Syntax check timed out")
        
        return {
            "file": str(file_path),
            "check_type": "syntax",
            "lua_version": lua_version,
            "stdout": process.stdout.strip(),
            "stderr": process.stderr.strip(),
            "exit_code": process.returncode,
            "valid": process.returncode == 0
        }


def _trace_bundle_error(arguments: dict) -> dict:
    """Trace bundled error back to source file using Go binary."""
    bundled_file_path = arguments.get("bundledFilePath")
    error_line = arguments.get("errorLine")
    
    if not bundled_file_path:
        raise ValueError("bundledFilePath is required")
    if error_line is None:
        raise ValueError("errorLine is required")
    
    bundled_path = Path(bundled_file_path).expanduser().resolve()
    if not bundled_path.exists():
        raise FileNotFoundError(f"Bundled file not found: {bundled_path}")
    
    # Use Go binary for trace_bundle_error
    mcp_server_root = Path(__file__).resolve().parents[2]
    go_binary = mcp_server_root / "lmaobox-context-server.exe"
    
    if not go_binary.exists():
        raise FileNotFoundError(f"Go binary not found: {go_binary}")
    
    # Create MCP request for trace_bundle_error
    request = {
        "jsonrpc": "2.0",
        "id": 1,
        "method": "tools/call",
        "params": {
            "name": "trace_bundle_error",
            "arguments": {
                "bundledFilePath": str(bundled_path),
                "errorLine": int(error_line)
            }
        }
    }
    
    try:
        proc = subprocess.run(
            [str(go_binary)],
            input=json.dumps(request),
            capture_output=True,
            text=True,
            timeout=5.0,
            check=False
        )
        
        # Parse response
        for line in proc.stdout.split('\n'):
            if line.strip():
                try:
                    response = json.loads(line)
                    if "result" in response:
                        return {
                            "bundled_file": str(bundled_path),
                            "error_line": int(error_line),
                            "trace": response["result"]["content"][0]["text"]
                        }
                    elif "error" in response:
                        raise RuntimeError(response["error"]["message"])
                except json.JSONDecodeError:
                    continue
        
        raise RuntimeError(f"Failed to parse Go binary response: {proc.stdout}")
        
    except subprocess.TimeoutExpired:
        raise RuntimeError("Trace operation timed out")


def _run_bundle(arguments: dict) -> dict:
    """Run the bundle-and-deploy automation ASYNC - returns job ID immediately."""
    project_dir = arguments.get("projectDir")
    if not project_dir:
        raise ValueError(
            "projectDir is required. Specify directory containing Lua files (e.g., 'my_project')")

    # Resolve project_dir: if absolute, use as-is; if relative, resolve from CWD
    project_path = Path(project_dir).expanduser()
    if not project_path.is_absolute():
        # WARNING: Path.cwd() is where MCP server was launched, not active workspace
        project_path = Path.cwd() / project_path

    project_path = project_path.resolve()

    if not project_path.exists():
        raise FileNotFoundError(
            f"Project directory not found: {project_path}\n"
            f"Provided: {project_dir}\n"
            f"CWD: {Path.cwd()}"
        )

    # Find bundle script
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

    # Generate job ID and create temp files for output
    job_id = str(uuid.uuid4())[:8]
    stdout_file = tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix=f'.{job_id}.stdout')
    stderr_file = tempfile.NamedTemporaryFile(mode='w+', delete=False, suffix=f'.{job_id}.stderr')
    stdout_file.close()
    stderr_file.close()
    
    # Initialize job tracking
    _bundle_jobs[job_id] = {
        "status": "running",
        "project_dir": str(project_path),
        "bundle_output_dir": env.get("BUNDLE_OUTPUT_DIR"),
        "deploy_dir": env.get("DEPLOY_DIR"),
        "stdout_file": stdout_file.name,
        "stderr_file": stderr_file.name,
        "start_time": time.time(),
        "returncode": None,
        "error": None,
    }
    
    def run_bundle_async():
        """Background thread that runs bundle and updates job status."""
        job = _bundle_jobs[job_id]
        try:
            with open(job["stdout_file"], 'w') as out, open(job["stderr_file"], 'w') as err:
                proc = subprocess.run(
                    ["node", str(script_path)],
                    cwd=str(mcp_server_root),
                    env=env,
                    stdout=out,
                    stderr=err,
                    stdin=subprocess.DEVNULL,
                    check=False,
                    timeout=30.0,  # 30s timeout for async
                )
                job["returncode"] = proc.returncode
                job["status"] = "completed" if proc.returncode == 0 else "failed"
        except subprocess.TimeoutExpired:
            job["status"] = "timeout"
            job["error"] = "Bundle timed out after 30 seconds"
        except Exception as e:
            job["status"] = "failed"
            job["error"] = str(e)
    
    # Start background thread (daemon=True so it dies with main process)
    thread = threading.Thread(target=run_bundle_async, daemon=True)
    thread.start()
    
    # Return immediately with job ID
    return {
        "status": "started",
        "job_id": job_id,
        "project_dir": str(project_path),
        "message": f"Bundle started. Poll with check_bundle_status(jobId='{job_id}') to get result.",
    }


def _check_bundle_status(arguments: dict) -> dict:
    """Check status of an async bundle job."""
    job_id = arguments.get("jobId")
    if not job_id:
        raise ValueError("jobId is required")
    
    if job_id not in _bundle_jobs:
        raise ValueError(f"Unknown job ID: {job_id}. Job may have expired or never existed.")
    
    job = _bundle_jobs[job_id]
    
    # Read current output from temp files
    stdout_text = ""
    stderr_text = ""
    try:
        if os.path.exists(job["stdout_file"]):
            with open(job["stdout_file"], 'r') as f:
                stdout_text = f.read()
        if os.path.exists(job["stderr_file"]):
            with open(job["stderr_file"], 'r') as f:
                stderr_text = f.read()
    except Exception as e:
        LOG.warning(f"Failed to read job output files: {e}")
    
    elapsed = time.time() - job["start_time"]
    
    result = {
        "job_id": job_id,
        "status": job["status"],
        "project_dir": job["project_dir"],
        "bundle_output_dir": job["bundle_output_dir"],
        "deploy_dir": job["deploy_dir"],
        "elapsed_seconds": round(elapsed, 1),
        "stdout": stdout_text.strip(),
        "stderr": stderr_text.strip(),
        "exit_code": job["returncode"],
        "error": job["error"],
    }
    
    # Cleanup completed jobs (keep temp files readable until next check)
    if job["status"] in ("completed", "failed", "timeout"):
        # Schedule cleanup
        def cleanup():
            time.sleep(5)  # Keep files for 5 more seconds
            try:
                os.unlink(job["stdout_file"])
                os.unlink(job["stderr_file"])
            except:
                pass
            if job_id in _bundle_jobs:
                del _bundle_jobs[job_id]
        
        cleanup_thread = threading.Thread(target=cleanup, daemon=True)
        cleanup_thread.start()
    
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
        # Async response - returns job ID immediately
        output_lines = [
            f"⏳ BUNDLE STARTED (async)",
            f"job_id: {result['job_id']}",
            f"project_dir: {result['project_dir']}",
            "",
            result["message"],
        ]
        return {"content": [{"type": "text", "text": "\n".join(output_lines)}]}

    elif name == "check_bundle_status":
        result = _check_bundle_status(arguments)
        status_emoji = {
            "running": "⏳",
            "completed": "✅",
            "failed": "❌",
            "timeout": "⏰",
        }.get(result["status"], "❓")
        
        output_lines = [
            f"{status_emoji} BUNDLE {result['status'].upper()}",
            f"job_id: {result['job_id']}",
            f"elapsed: {result['elapsed_seconds']}s",
            f"project_dir: {result['project_dir']}",
        ]
        
        if result["status"] != "running":
            output_lines.extend([
                f"exit_code: {result['exit_code']}",
                "",
                result["stdout"] or "<no output>",
            ])
            if result["stderr"]:
                output_lines.extend(["", "=== stderr ===", result["stderr"]])
            if result["error"]:
                output_lines.extend(["", "=== error ===", result["error"]])
        else:
            output_lines.extend(["", "Bundle still running... poll again in 1-2 seconds."])
            if result["stdout"]:
                output_lines.extend(["", "=== partial output ===", result["stdout"][-500:]])
        
        return {"content": [{"type": "text", "text": "\n".join(output_lines)}]}

    elif name == "luacheck":
        result = _run_luacheck(arguments)
        status = "✓ VALID" if result["valid"] else "✗ INVALID"
        output_lines = [
            f"{status} | {result['check_type'].upper()} CHECK",
            f"file: {result['file']}",
        ]
        if result.get("lua_version"):
            output_lines.append(f"lua_version: {result['lua_version']}")
        output_lines.extend([
            f"exit_code: {result['exit_code']}",
            "",
        ])
        if result["stdout"]:
            output_lines.append(result["stdout"])
        if result["stderr"]:
            output_lines.extend(["", "=== errors ===", result["stderr"]])
        if result["valid"] and not result["stdout"] and not result["stderr"]:
            output_lines.append("No errors found.")
        return {"content": [{"type": "text", "text": "\n".join(output_lines)}]}

    elif name == "trace_bundle_error":
        result = _trace_bundle_error(arguments)
        return {"content": [{"type": "text", "text": result["trace"]}]}

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
