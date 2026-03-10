"""
coord_server.py -- HTTP JSON-RPC Coordination Server (F-0185).

Provides network-accessible coordination for parallel agents, remote review,
and mobile status monitoring. Delegates all mutations to file-based tools.

Usage:
    python3 coord_server.py start --project-root /path/to/project
    python3 coord_server.py stop  --project-root /path/to/project
    python3 coord_server.py status --project-root /path/to/project

Transport: HTTP JSON-RPC 2.0 on TCP (default 127.0.0.1:4185).
Auth: Bearer token (generated on start, written to .agentic/session/coord.token).
"""
from __future__ import annotations

import argparse
import hmac
import json
import os
import re
import secrets
import signal
import subprocess
import sys
import threading
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
DEFAULT_PORT = 4185
DEFAULT_BIND = "127.0.0.1"
PID_FILENAME = "coord.pid"
TOKEN_FILENAME = "coord.token"

# JSON-RPC 2.0 error codes
PARSE_ERROR = -32700
INVALID_REQUEST = -32600
METHOD_NOT_FOUND = -32601
INVALID_PARAMS = -32602
INTERNAL_ERROR = -32603
AUTH_ERROR = -32000  # Application-defined


# ---------------------------------------------------------------------------
# Request Handler
# ---------------------------------------------------------------------------
class CoordRequestHandler(BaseHTTPRequestHandler):
    """HTTP handler for JSON-RPC 2.0 coordination requests."""

    # Suppress default access logging to stderr
    def log_message(self, format, *args):
        pass

    def do_GET(self):
        """Handle GET requests (only /health)."""
        if self.path == "/health":
            self._send_json(200, {"status": "ok", "pid": os.getpid()})
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        """Handle POST /rpc — JSON-RPC 2.0 dispatch."""
        if self.path != "/rpc":
            self._send_json(404, {"error": "not found"})
            return

        # Auth check (constant-time comparison to prevent timing attacks)
        auth = self.headers.get("Authorization", "")
        expected = f"Bearer {self.server.token}"
        if not hmac.compare_digest(auth, expected):
            self._send_json(401, _jsonrpc_error(
                None, AUTH_ERROR, "unauthorized"))
            return

        # Read body
        content_length = int(self.headers.get("Content-Length", 0))
        if content_length == 0:
            self._send_json(400, _jsonrpc_error(
                None, INVALID_REQUEST, "empty request body"))
            return

        try:
            body = self.rfile.read(content_length)
            request = json.loads(body)
        except (json.JSONDecodeError, ValueError):
            self._send_json(400, _jsonrpc_error(
                None, PARSE_ERROR, "invalid JSON"))
            return

        # Validate JSON-RPC structure
        if not isinstance(request, dict):
            self._send_json(400, _jsonrpc_error(
                None, INVALID_REQUEST, "request must be a JSON object"))
            return

        req_id = request.get("id")
        method = request.get("method", "")
        params = request.get("params", {})

        if not method:
            self._send_json(400, _jsonrpc_error(
                req_id, INVALID_REQUEST, "missing 'method'"))
            return

        # Dispatch with threading lock (intra-process serialization)
        with self.server.dispatch_lock:
            result = self._dispatch(method, params, req_id)

        self._send_json(200, result)

    def _dispatch(self, method: str, params: dict, req_id) -> dict:
        """Dispatch a JSON-RPC method to the appropriate tool handler."""
        from auto.coord_tools import TOOLS

        if method not in TOOLS:
            return _jsonrpc_error(req_id, METHOD_NOT_FOUND,
                                  f"unknown method: {method}")

        if not isinstance(params, dict):
            return _jsonrpc_error(req_id, INVALID_PARAMS,
                                  "params must be a JSON object")

        try:
            result = TOOLS[method](self.server.project_root, params)
            return _jsonrpc_success(req_id, result)
        except Exception as e:
            return _jsonrpc_error(req_id, INTERNAL_ERROR, str(e))

    def _send_json(self, status_code: int, data: dict):
        self.send_response(status_code)
        self.send_header("Content-Type", "application/json")
        body = json.dumps(data).encode("utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


# ---------------------------------------------------------------------------
# JSON-RPC helpers
# ---------------------------------------------------------------------------
def _jsonrpc_success(req_id, result: dict) -> dict:
    return {"jsonrpc": "2.0", "result": result, "id": req_id}


def _jsonrpc_error(req_id, code: int, message: str, data=None) -> dict:
    err: dict = {"code": code, "message": message}
    if data is not None:
        err["data"] = data
    return {"jsonrpc": "2.0", "error": err, "id": req_id}


# ---------------------------------------------------------------------------
# Threaded HTTP Server with coordination context
# ---------------------------------------------------------------------------
class CoordHTTPServer(HTTPServer):
    """HTTPServer subclass that carries coordination context."""

    allow_reuse_address = True

    def __init__(self, server_address, handler_class,
                 project_root: Path, token: str):
        super().__init__(server_address, handler_class)
        self.project_root = project_root
        self.token = token
        self.dispatch_lock = threading.Lock()


# ---------------------------------------------------------------------------
# Process lifecycle
# ---------------------------------------------------------------------------
def _resolve_project_root() -> Path:
    """Resolve project root from env var or git."""
    env_root = os.environ.get("AG_PROJECT_ROOT")
    if env_root:
        return Path(env_root).resolve()
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            capture_output=True, text=True, timeout=5,
        )
        if result.returncode == 0:
            return Path(result.stdout.strip()).resolve()
    except (FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return Path.cwd().resolve()


def _read_settings(project_root: Path) -> dict:
    """Read coord settings from STACK.md."""
    stack_file = project_root / "STACK.md"
    if not stack_file.exists():
        stack_file = project_root / ".agentic" / "STACK.md"
    settings = {
        "coord_enabled": "no",
        "coord_port": str(DEFAULT_PORT),
        "coord_bind": DEFAULT_BIND,
    }
    if not stack_file.exists():
        return settings
    try:
        content = stack_file.read_text()
        for line in content.splitlines():
            for key in settings:
                m = re.match(rf'^-\s+{key}:\s+(.+?)(?:\s+#.*)?$', line)
                if m:
                    settings[key] = m.group(1).strip()
    except OSError:
        pass
    return settings


def cmd_start(project_root: Path, port: int = 0, bind: str = "") -> int:
    """Start the coordination server (foreground)."""
    paths = get_paths(project_root)
    session_dir = paths.session_dir
    session_dir.mkdir(parents=True, exist_ok=True)

    pid_path = session_dir / PID_FILENAME
    token_path = session_dir / TOKEN_FILENAME

    # Check for existing server
    if pid_path.exists():
        try:
            old_pid = int(pid_path.read_text().strip())
            os.kill(old_pid, 0)
            print(f"Coordination server already running (PID {old_pid})")
            return 1
        except (ProcessLookupError, OSError, ValueError):
            # Stale PID file
            pid_path.unlink(missing_ok=True)
            token_path.unlink(missing_ok=True)

    # Read settings if port/bind not overridden
    settings = _read_settings(project_root)
    if port == 0:
        port = int(settings.get("coord_port", DEFAULT_PORT))
    if not bind:
        bind = settings.get("coord_bind", DEFAULT_BIND)

    # Generate token
    token = secrets.token_hex(32)
    token_path.write_text(token + "\n")
    os.chmod(str(token_path), 0o600)

    # Write PID
    pid_path.write_text(str(os.getpid()) + "\n")

    # Create server
    server = CoordHTTPServer((bind, port), CoordRequestHandler,
                             project_root, token)

    # Cleanup with idempotency guard (prevents double cleanup from
    # atexit + finally, or signal + finally)
    _cleaned_up = False

    def _cleanup(*_args):
        nonlocal _cleaned_up
        if _cleaned_up:
            return
        _cleaned_up = True
        server.shutdown()
        pid_path.unlink(missing_ok=True)
        token_path.unlink(missing_ok=True)

    # SIGTERM: set flag to break serve_forever loop (no sys.exit in signal
    # handler — that can deadlock if the handler runs while a lock is held)
    def _sigterm_handler(signum, frame):
        server._BaseServer__shutdown_request = True

    signal.signal(signal.SIGTERM, _sigterm_handler)

    print(f"Coordination server started on {bind}:{port} (PID {os.getpid()})")
    print(f"Token written to {token_path}")

    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        _cleanup()

    return 0


def cmd_stop(project_root: Path) -> int:
    """Stop a running coordination server."""
    paths = get_paths(project_root)
    session_dir = paths.session_dir
    pid_path = session_dir / PID_FILENAME
    token_path = session_dir / TOKEN_FILENAME

    if not pid_path.exists():
        print("No coordination server running (no PID file)")
        return 1

    try:
        pid = int(pid_path.read_text().strip())
    except (ValueError, OSError):
        print("Invalid PID file")
        pid_path.unlink(missing_ok=True)
        return 1

    try:
        os.kill(pid, signal.SIGTERM)
        print(f"Stopped coordination server (PID {pid})")
    except ProcessLookupError:
        print(f"Server not running (stale PID {pid})")
    except OSError as e:
        print(f"Error stopping server: {e}")
        return 1

    pid_path.unlink(missing_ok=True)
    token_path.unlink(missing_ok=True)
    return 0


def cmd_status(project_root: Path) -> int:
    """Check coordination server status."""
    paths = get_paths(project_root)
    session_dir = paths.session_dir
    pid_path = session_dir / PID_FILENAME
    token_path = session_dir / TOKEN_FILENAME

    if not pid_path.exists():
        print("Coordination server: not running")
        return 1

    try:
        pid = int(pid_path.read_text().strip())
    except (ValueError, OSError):
        print("Coordination server: invalid PID file")
        return 1

    try:
        os.kill(pid, 0)
    except (ProcessLookupError, OSError):
        print(f"Coordination server: stale (PID {pid} not alive)")
        pid_path.unlink(missing_ok=True)
        token_path.unlink(missing_ok=True)
        return 1

    # Try health check
    settings = _read_settings(project_root)
    port = int(settings.get("coord_port", DEFAULT_PORT))
    bind = settings.get("coord_bind", DEFAULT_BIND)
    host = "127.0.0.1" if bind == "0.0.0.0" else bind

    try:
        import urllib.request
        url = f"http://{host}:{port}/health"
        req = urllib.request.Request(url, method="GET")
        with urllib.request.urlopen(req, timeout=3) as resp:
            data = json.loads(resp.read())
            print(f"Coordination server: running (PID {pid}, port {port})")
            return 0
    except Exception:
        print(f"Coordination server: PID alive ({pid}) but not responding on port {port}")
        return 1


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def main() -> int:
    parser = argparse.ArgumentParser(
        description="Coordination Server (F-0185)")
    parser.add_argument("command", choices=["start", "stop", "status"],
                        help="Server command")
    parser.add_argument("--project-root", type=Path, default=None,
                        help="Project root directory")
    parser.add_argument("--port", type=int, default=0,
                        help="Port to bind (default: from STACK.md or 4185)")
    parser.add_argument("--bind", type=str, default="",
                        help="Address to bind (default: from STACK.md or 127.0.0.1)")
    args = parser.parse_args()

    project_root = args.project_root or _resolve_project_root()
    project_root = project_root.resolve()

    if args.command == "start":
        return cmd_start(project_root, args.port, args.bind)
    elif args.command == "stop":
        return cmd_stop(project_root)
    elif args.command == "status":
        return cmd_status(project_root)
    return 1


if __name__ == "__main__":
    sys.exit(main())
