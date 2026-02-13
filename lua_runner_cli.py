#!/usr/bin/env python3
"""
Lua Runner CLI - Command-line interface for Lmaobox Lua execution

Usage:
    python lua_runner_cli.py execute --file script.lua
    python lua_runner_cli.py execute --code "print('hello')"
    python lua_runner_cli.py bundle ./my_project
    python lua_runner_cli.py debug --duration 60
    python lua_runner_cli.py status --id <execution_id>

Prerequisites:
    1. Load lua_runner_helper.lua in Lmaobox
    2. MCP server must be running (or this will start it)
"""
import argparse
import json
import sys
import time
import urllib.request
import urllib.error
from pathlib import Path

MCP_BASE_URL = "http://127.0.0.1:8765"
LUA_RUNNER_URL = "http://127.0.0.1:27182"


def make_request(url, method="GET", data=None, timeout=10):
    """Make HTTP request and return parsed JSON."""
    try:
        if data and method == "POST":
            req = urllib.request.Request(
                url,
                data=json.dumps(data).encode(),
                headers={"Content-Type": "application/json"},
                method="POST"
            )
        else:
            req = urllib.request.Request(url, method=method)

        with urllib.request.urlopen(req, timeout=timeout) as response:
            return json.loads(response.read().decode())
    except urllib.error.HTTPError as e:
        return {"error": f"HTTP {e.code}: {e.reason}", "details": e.read().decode()}
    except Exception as e:
        return {"error": str(e)}


def cmd_execute_file(args):
    """Execute a Lua file."""
    file_path = Path(args.file)
    if not file_path.exists():
        print(f"❌ File not found: {file_path}")
        return 1

    script = file_path.read_text(encoding="utf-8")
    print(f"📄 Executing: {file_path} ({len(script)} chars)")

    result = make_request(
        f"{MCP_BASE_URL}/lua/execute",
        method="POST",
        data={"script": script, "script_id": file_path.stem}
    )

    if "error" in result:
        print(f"❌ Failed: {result['error']}")
        return 1

    exec_id = result.get("execution_id")
    print(f"✅ Queued: {exec_id}")

    if args.wait:
        return wait_for_result(exec_id, args.timeout)
    return 0


def cmd_execute_code(args):
    """Execute Lua code string."""
    print(f"📄 Executing code snippet ({len(args.code)} chars)")

    result = make_request(
        f"{MCP_BASE_URL}/lua/execute",
        method="POST",
        data={"script": args.code, "script_id": "inline"}
    )

    if "error" in result:
        print(f"❌ Failed: {result['error']}")
        return 1

    exec_id = result.get("execution_id")
    print(f"✅ Queued: {exec_id}")

    if args.wait:
        return wait_for_result(exec_id, args.timeout)
    return 0


def cmd_bundle(args):
    """Bundle and execute a project."""
    project_dir = Path(args.project_dir).resolve()
    if not project_dir.exists():
        print(f"❌ Project directory not found: {project_dir}")
        return 1

    entry = args.entry or "Main.lua"
    print(f"📦 Bundling: {project_dir}/{entry}")

    result = make_request(
        f"{MCP_BASE_URL}/lua/execute_bundle",
        method="POST",
        data={"project_dir": str(project_dir), "entry_file": entry}
    )

    if "error" in result:
        print(f"❌ Bundle failed: {result['error']}")
        if "details" in result:
            print(f"Details: {result['details']}")
        return 1

    exec_id = result.get("execution_id")
    size = result.get("bundled_size", 0)
    print(f"✅ Bundled ({size} chars) -> Queued: {exec_id}")

    if args.wait:
        return wait_for_result(exec_id, args.timeout)
    return 0


def cmd_debug(args):
    """Start debug session."""
    duration = args.duration or 60
    print(f"🐛 Starting debug session ({duration}s)")

    result = make_request(
        f"{MCP_BASE_URL}/lua/debug",
        method="POST",
        data={"duration_seconds": duration}
    )

    if "error" in result:
        print(f"❌ Failed: {result['error']}")
        return 1

    session_id = result.get("session_id")
    print(f"✅ Debug session: {session_id}")
    print(f"⏱️  Listening for errors... (Ctrl+C to stop early)")

    try:
        while True:
            time.sleep(2)
            status = make_request(f"{MCP_BASE_URL}/lua/debug_status")

            if status.get("active"):
                elapsed = status.get("elapsed_seconds", 0)
                remaining = status.get("remaining_seconds", 0)
                errors = status.get("errors_count", 0)
                output = status.get("output_lines", 0)
                print(f"⏳ {elapsed:.0f}s elapsed, {remaining:.0f}s remaining | "
                      f"Errors: {errors}, Output: {output} lines", end="\r")
            else:
                break
    except KeyboardInterrupt:
        print("\n🛑 Stopping debug session...")
        result = make_request(f"{MCP_BASE_URL}/lua/debug_stop", method="POST")
        display_debug_summary(result)
        return 0

    print(f"\n✅ Debug session completed")
    final_status = make_request(f"{MCP_BASE_URL}/lua/debug_status")
    display_debug_summary(final_status)
    return 0


def display_debug_summary(result):
    """Display debug session summary."""
    if not result or "errors" not in result:
        print("No debug data available")
        return

    errors = result.get("errors", [])
    output = result.get("output", [])

    print(f"\n📊 Debug Summary:")
    print(f"   Errors caught: {len(errors)}")
    print(f"   Output lines: {len(output)}")

    if errors:
        print(f"\n❌ Errors:")
        for i, err in enumerate(errors[:10], 1):
            print(f"   {i}. {err.get('message', 'Unknown')[:80]}")
        if len(errors) > 10:
            print(f"   ... and {len(errors) - 10} more")

    if output and len(output) > 0:
        print(f"\n📝 Output (last 20 lines):")
        for line in output[-20:]:
            print(f"   > {line[:100]}")


def cmd_status(args):
    """Get execution status."""
    exec_id = args.id
    result = make_request(f"{MCP_BASE_URL}/lua/status?id={exec_id}")

    if "error" in result:
        print(f"❌ {result['error']}")
        return 1

    print(f"📊 Execution: {exec_id}")
    print(f"   Success: {result.get('success', False)}")
    print(f"   Duration: {result.get('duration_ms', 0):.1f}ms")
    print(f"   Output lines: {len(result.get('output', []))}")
    print(f"   Errors: {len(result.get('errors', []))}")

    if result.get('errors'):
        print(f"\n❌ Errors:")
        for err in result['errors']:
            print(f"   - {err.get('message', 'Unknown')}")
            if err.get('traceback'):
                print(f"     Traceback: {err['traceback'][:100]}")

    if result.get('output') and args.show_output:
        print(f"\n📝 Output:")
        for line in result['output']:
            print(f"   {line}")

    return 0


def cmd_state(args):
    """Get Lua runner state."""
    result = make_request(f"{MCP_BASE_URL}/lua/state")

    if "error" in result:
        print(f"❌ {result['error']}")
        return 1

    print(f"📡 Lua Runner State:")
    print(f"   Server running: {result.get('server_running', False)}")
    print(f"   State: {result.get('state', 'unknown')}")
    print(f"   Current script: {result.get('current_script_id', 'none')}")
    print(f"   Pending results: {result.get('pending_results', 0)}")
    return 0


def wait_for_result(exec_id, timeout=30):
    """Wait for execution to complete and show results."""
    print(f"⏳ Waiting for execution to complete (timeout: {timeout}s)...")
    start = time.time()

    while time.time() - start < timeout:
        result = make_request(f"{MCP_BASE_URL}/lua/status?id={exec_id}")

        if "error" not in result and result.get("duration_ms", 0) > 0:
            print(f"\n✅ Execution completed in {result['duration_ms']:.1f}ms")

            if result.get("output"):
                print(f"\n📝 Output:")
                for line in result["output"]:
                    print(f"   {line}")

            if result.get("errors"):
                print(f"\n❌ Errors ({len(result['errors'])}):")
                for err in result["errors"]:
                    print(f"   - {err.get('message', 'Unknown')}")

            if result.get("callbacks_registered"):
                print(f"\n🔔 Callbacks registered: {len(result['callbacks_registered'])}")

            return 0 if result.get("success") else 1

        time.sleep(0.5)

    print("\n⏱️ Timeout waiting for execution")
    return 1


def main():
    parser = argparse.ArgumentParser(
        description="Lua Runner CLI for Lmaobox",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s execute --file myscript.lua --wait
  %(prog)s execute --code "print(engine.GetMapName())"
  %(prog)s bundle ./my_project --wait
  %(prog)s debug --duration 60
  %(prog)s status --id exec_123456 --show-output
        """
    )

    subparsers = parser.add_subparsers(dest="command", help="Available commands")

    # Execute file
    exec_file = subparsers.add_parser("execute", help="Execute Lua file or code")
    exec_file.add_argument("--file", "-f", help="Path to Lua file")
    exec_file.add_argument("--code", "-c", help="Lua code string")
    exec_file.add_argument("--wait", "-w", action="store_true", help="Wait for execution result")
    exec_file.add_argument("--timeout", "-t", type=int, default=30, help="Wait timeout in seconds")

    # Bundle
    bundle = subparsers.add_parser("bundle", help="Bundle and execute project")
    bundle.add_argument("project_dir", help="Path to project directory")
    bundle.add_argument("--entry", "-e", help="Entry file (default: Main.lua)")
    bundle.add_argument("--wait", "-w", action="store_true", help="Wait for execution result")
    bundle.add_argument("--timeout", "-t", type=int, default=30, help="Wait timeout in seconds")

    # Debug
    debug = subparsers.add_parser("debug", help="Start debug session")
    debug.add_argument("--duration", "-d", type=int, default=60, help="Debug duration in seconds")

    # Status
    status = subparsers.add_parser("status", help="Get execution status")
    status.add_argument("--id", "-i", required=True, help="Execution ID")
    status.add_argument("--show-output", "-o", action="store_true", help="Show full output")

    # State
    subparsers.add_parser("state", help="Get Lua runner state")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    # Route to command handler
    if args.command == "execute":
        if args.file:
            return cmd_execute_file(args)
        elif args.code:
            return cmd_execute_code(args)
        else:
            print("❌ Error: Must specify either --file or --code")
            return 1
    elif args.command == "bundle":
        return cmd_bundle(args)
    elif args.command == "debug":
        return cmd_debug(args)
    elif args.command == "status":
        return cmd_status(args)
    elif args.command == "state":
        return cmd_state(args)

    parser.print_help()
    return 1


if __name__ == "__main__":
    sys.exit(main())
