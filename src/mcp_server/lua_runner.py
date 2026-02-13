"""Lua Runner - Integrated execution engine for Lmaobox

Provides hot-reload, error monitoring, and bundle integration.
Uses HTTP communication between external tool and in-game script.
"""
import json
import logging
import queue
import tempfile
import threading
import time
from dataclasses import dataclass, field
from enum import Enum, auto
from http.server import BaseHTTPRequestHandler, HTTPServer
from pathlib import Path
from typing import Callable, Optional
from urllib.parse import parse_qs, urlparse, unquote

LOG = logging.getLogger("lua_runner")


class ExecutionState(Enum):
    IDLE = auto()
    PENDING = auto()
    EXECUTING = auto()
    DEBUGGING = auto()
    ERROR = auto()
    COMPLETED = auto()


@dataclass
class ExecutionResult:
    script_id: str
    success: bool
    output: list[str] = field(default_factory=list)
    errors: list[dict] = field(default_factory=list)
    duration_ms: float = 0.0
    callbacks_registered: list[dict] = field(default_factory=list)


@dataclass
class DebugSession:
    script_id: str
    duration_seconds: int
    start_time: float = field(default_factory=time.time)
    errors_caught: list[dict] = field(default_factory=list)
    output_buffer: list[str] = field(default_factory=list)
    active: bool = True


class LuaRunnerServer:
    """HTTP server that bridges external editor with in-game Lua execution."""

    PORT = 27182  # Fixed port - matches helper script

    def __init__(self):
        self.script_queue: queue.Queue[str] = queue.Queue()
        self.current_script: Optional[str] = None
        self.current_script_id: str = ""
        self.state = ExecutionState.IDLE
        self.results: dict[str, ExecutionResult] = {}
        self.debug_session: Optional[DebugSession] = None
        self._lock = threading.Lock()
        self._server: Optional[HTTPServer] = None
        self._thread: Optional[threading.Thread] = None

        # Callbacks for UI integration
        self.on_state_change: Optional[Callable[[ExecutionState], None]] = None
        self.on_output: Optional[Callable[[str], None]] = None
        self.on_error: Optional[Callable[[dict], None]] = None

    def start(self) -> bool:
        """Start the HTTP server in a background thread."""
        if self._server:
            return True

        try:
            self._server = HTTPServer(("127.0.0.1", self.PORT), self._make_handler())
            self._thread = threading.Thread(target=self._server.serve_forever, daemon=True)
            self._thread.start()
            LOG.info("LuaRunner server started on port %s", self.PORT)
            return True
        except Exception as exc:
            LOG.error("Failed to start LuaRunner server: %s", exc)
            return False

    def stop(self):
        """Stop the HTTP server."""
        if self._server:
            self._server.shutdown()
            self._server = None
        if self._thread:
            self._thread.join(timeout=2)
            self._thread = None

    def _make_handler(self):
        """Create request handler with reference to self."""
        runner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, fmt, *args):
                LOG.debug(fmt % args)

            def _json_response(self, status: int, data: dict):
                self.send_response(status)
                self.send_header("Content-Type", "application/json")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(json.dumps(data).encode())

            def _text_response(self, status: int, text: str):
                self.send_response(status)
                self.send_header("Content-Type", "text/plain")
                self.send_header("Access-Control-Allow-Origin", "*")
                self.end_headers()
                self.wfile.write(text.encode())

            def do_GET(self):
                parsed = urlparse(self.path)
                path = parsed.path
                query = parse_qs(parsed.query)

                # Primary endpoint: in-game helper polls for scripts
                if path == "/getscript":
                    with runner._lock:
                        if runner.current_script:
                            script = runner.current_script
                            runner.current_script = None
                            runner.state = ExecutionState.EXECUTING
                            self._text_response(200, script)
                            if runner.on_state_change:
                                runner.on_state_change(ExecutionState.EXECUTING)
                        else:
                            self._text_response(200, "")
                    return

                # Get current execution state
                if path == "/state":
                    with runner._lock:
                        data = {
                            "state": runner.state.name,
                            "script_id": runner.current_script_id,
                            "debug_active": runner.debug_session is not None and runner.debug_session.active
                        }
                    self._json_response(200, data)
                    return

                # Get results for a specific execution
                if path == "/results":
                    script_id = query.get("id", [""])[0]
                    with runner._lock:
                        result = runner.results.get(script_id)
                    if result:
                        self._json_response(200, {
                            "script_id": result.script_id,
                            "success": result.success,
                            "output": result.output,
                            "errors": result.errors,
                            "duration_ms": result.duration_ms,
                            "callbacks_registered": result.callbacks_registered
                        })
                    else:
                        self._json_response(404, {"error": "Script ID not found"})
                    return

                self._json_response(404, {"error": "Not found"})

            def do_POST(self):
                parsed = urlparse(self.path)
                path = parsed.path
                content_length = int(self.headers.get("Content-Length", 0))
                body = self.rfile.read(content_length).decode()

                # Receive output from in-game execution
                if path == "/output":
                    try:
                        data = json.loads(body)
                        line = data.get("line", "")
                        with runner._lock:
                            if runner.debug_session and runner.debug_session.active:
                                runner.debug_session.output_buffer.append(line)
                            if runner.current_script_id in runner.results:
                                runner.results[runner.current_script_id].output.append(line)
                        if runner.on_output:
                            runner.on_output(line)
                        self._json_response(200, {"ok": True})
                    except json.JSONDecodeError:
                        self._json_response(400, {"error": "Invalid JSON"})
                    return

                # Receive errors from in-game execution
                if path == "/error":
                    try:
                        data = json.loads(body)
                        error_info = {
                            "message": data.get("message", ""),
                            "traceback": data.get("traceback", ""),
                            "timestamp": time.time()
                        }
                        with runner._lock:
                            if runner.debug_session and runner.debug_session.active:
                                runner.debug_session.errors_caught.append(error_info)
                            if runner.current_script_id in runner.results:
                                runner.results[runner.current_script_id].errors.append(error_info)
                                runner.results[runner.current_script_id].success = False
                        if runner.on_error:
                            runner.on_error(error_info)
                        self._json_response(200, {"ok": True})
                    except json.JSONDecodeError:
                        self._json_response(400, {"error": "Invalid JSON"})
                    return

                # Report callback registrations
                if path == "/callbacks":
                    try:
                        data = json.loads(body)
                        callbacks = data.get("callbacks", [])
                        with runner._lock:
                            if runner.current_script_id in runner.results:
                                runner.results[runner.current_script_id].callbacks_registered = callbacks
                        self._json_response(200, {"ok": True})
                    except json.JSONDecodeError:
                        self._json_response(400, {"error": "Invalid JSON"})
                    return

                # Signal execution completed
                if path == "/completed":
                    with runner._lock:
                        runner.state = ExecutionState.COMPLETED
                        if runner.current_script_id in runner.results:
                            runner.results[runner.current_script_id].success = True
                        if runner.on_state_change:
                            runner.on_state_change(ExecutionState.COMPLETED)
                    self._json_response(200, {"ok": True})
                    return

                self._json_response(404, {"error": "Not found"})

        return Handler

    def execute(self, script: str, script_id: Optional[str] = None) -> str:
        """Queue a script for execution. Returns script ID."""
        script_id = script_id or f"exec_{int(time.time() * 1000)}"

        with self._lock:
            self.current_script = script
            self.current_script_id = script_id
            self.state = ExecutionState.PENDING
            self.results[script_id] = ExecutionResult(
                script_id=script_id,
                success=False,
                output=[],
                errors=[],
                duration_ms=0.0
            )

        if self.on_state_change:
            self.on_state_change(ExecutionState.PENDING)

        LOG.info("Script queued for execution: %s", script_id)
        return script_id

    def start_debug_session(self, duration_seconds: int = 60) -> str:
        """Start a debug session that captures all errors for specified duration."""
        session_id = f"debug_{int(time.time() * 1000)}"

        with self._lock:
            self.debug_session = DebugSession(
                script_id=session_id,
                duration_seconds=duration_seconds,
                start_time=time.time(),
                errors_caught=[],
                output_buffer=[],
                active=True
            )
            self.state = ExecutionState.DEBUGGING

        # Schedule auto-cleanup
        def end_session():
            time.sleep(duration_seconds)
            with self._lock:
                if self.debug_session and self.debug_session.script_id == session_id:
                    self.debug_session.active = False
                    if self.state == ExecutionState.DEBUGGING:
                        self.state = ExecutionState.IDLE
                    LOG.info("Debug session ended: %s", session_id)

        threading.Thread(target=end_session, daemon=True).start()

        if self.on_state_change:
            self.on_state_change(ExecutionState.DEBUGGING)

        LOG.info("Debug session started: %s (%ss)", session_id, duration_seconds)
        return session_id

    def get_debug_summary(self) -> Optional[dict]:
        """Get summary of current/past debug session."""
        with self._lock:
            if not self.debug_session:
                return None

            session = self.debug_session
            elapsed = time.time() - session.start_time
            remaining = max(0, session.duration_seconds - elapsed)

            return {
                "script_id": session.script_id,
                "active": session.active,
                "elapsed_seconds": round(elapsed, 1),
                "remaining_seconds": round(remaining, 1),
                "errors_count": len(session.errors_caught),
                "output_lines": len(session.output_buffer),
                "errors": session.errors_caught if not session.active else None,
                "output": session.output_buffer if not session.active else None
            }

    def stop_debug_session(self) -> Optional[dict]:
        """Stop debug session early and return captured data."""
        with self._lock:
            if not self.debug_session:
                return None

            self.debug_session.active = False
            session = self.debug_session
            self.debug_session = None
            self.state = ExecutionState.IDLE

            return {
                "script_id": session.script_id,
                "errors": session.errors_caught,
                "output": session.output_buffer,
                "duration": time.time() - session.start_time
            }


# Global runner instance
_runner_instance: Optional[LuaRunnerServer] = None


def get_runner() -> LuaRunnerServer:
    """Get or create the global runner instance."""
    global _runner_instance
    if _runner_instance is None:
        _runner_instance = LuaRunnerServer()
    return _runner_instance


def execute_script(script: str) -> str:
    """Execute a Lua script in the game. Returns execution ID."""
    runner = get_runner()
    if not runner._server:
        runner.start()
    return runner.execute(script)


def start_debugging(duration: int = 60) -> str:
    """Start a debug session for specified duration."""
    runner = get_runner()
    if not runner._server:
        runner.start()
    return runner.start_debug_session(duration)


def get_results(exec_id: str) -> Optional[ExecutionResult]:
    """Get results for a specific execution."""
    runner = get_runner()
    return runner.results.get(exec_id)
