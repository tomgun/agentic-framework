"""
control.py -- CLI client for the autonomous workflow engine.

Sends commands to the engine via its Unix domain socket and prints responses.

Usage:
    python -m auto.control pause
    python -m auto.control resume
    python -m auto.control stop
    python -m auto.control status
    python -m auto.control feedback AC-003 "use the existing auth module"
"""
from __future__ import annotations

import json
import os
import socket
import sys
from pathlib import Path

# ---------------------------------------------------------------------------
# Resolve paths.py from the lib/ directory (our parent)
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402

SOCKET_FILENAME = "auto.sock"
PID_FILENAME = "auto.pid"


def send_command(socket_path: Path, command: dict, timeout: float = 5.0) -> dict:
    """Send a JSON command to the engine socket and return the response."""
    if not socket_path.exists():
        return {"error": "Engine not running (no socket file)"}

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.settimeout(timeout)
    try:
        sock.connect(str(socket_path))
        payload = json.dumps(command) + "\n"
        sock.sendall(payload.encode("utf-8"))

        # Read response
        data = b""
        while True:
            chunk = sock.recv(4096)
            if not chunk:
                break
            data += chunk
            if b"\n" in data:
                break

        response_text = data.decode("utf-8").strip()
        if not response_text:
            return {"error": "Empty response from engine"}
        return json.loads(response_text)

    except ConnectionRefusedError:
        return {"error": "Engine not running (connection refused)"}
    except socket.timeout:
        return {"error": "Engine did not respond (timeout)"}
    except json.JSONDecodeError:
        return {"error": f"Invalid response: {data.decode('utf-8', errors='replace')}"}
    finally:
        sock.close()


def check_engine_running(session_dir: Path) -> dict | None:
    """Check if the engine is running. Returns PID info or None."""
    pid_path = session_dir / PID_FILENAME
    if not pid_path.exists():
        return None

    try:
        pid = int(pid_path.read_text().strip())
    except (ValueError, OSError):
        return None

    # Check if process is alive
    try:
        os.kill(pid, 0)
        return {"pid": pid, "alive": True}
    except (OSError, PermissionError):
        return {"pid": pid, "alive": False}


def format_status(status: dict) -> str:
    """Format a status response for terminal display."""
    if "error" in status:
        return f"Error: {status['error']}"

    lines = []
    lines.append(f"State:    {status.get('state', 'unknown')}")
    lines.append(f"Feature:  {status.get('feature_id', 'none')}")
    lines.append(f"Mode:     {status.get('mode', 'none')}")
    lines.append(f"Current:  {status.get('current_ac', 'none')}")

    progress = status.get("progress", {})
    if progress:
        total = len(progress)
        passed = sum(1 for s in progress.values() if s == "passed")
        failed = sum(1 for s in progress.values() if s == "failed")
        partial = sum(1 for s in progress.values() if s == "partial")
        in_prog = sum(1 for s in progress.values() if s == "in_progress")
        lines.append(f"Progress: {passed}/{total} passed, {failed} failed, "
                      f"{partial} partial, {in_prog} in progress")

    decomposed = status.get("decomposed", {})
    if decomposed:
        lines.append("Decomposed ACs:")
        for ac_id, sub_tasks in decomposed.items():
            sub_passed = sum(1 for s in sub_tasks if s.get("status") == "passed")
            lines.append(f"  {ac_id}: {sub_passed}/{len(sub_tasks)} sub-tasks passed")

    fb_size = status.get("feedback_queue_size", 0)
    if fb_size > 0:
        lines.append(f"Feedback queued: {fb_size}")

    return "\n".join(lines)


def main() -> int:
    """CLI entry point."""
    import argparse

    parser = argparse.ArgumentParser(description="Control the auto engine")
    parser.add_argument(
        "command",
        choices=["pause", "resume", "stop", "status", "feedback"],
        help="Command to send",
    )
    parser.add_argument("args", nargs="*", help="Command arguments")
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root directory",
    )
    parsed = parser.parse_args()

    paths = get_paths(parsed.project_root)
    socket_path = paths.session_dir / SOCKET_FILENAME

    if parsed.command == "feedback":
        if len(parsed.args) < 2:
            print("Usage: ag auto feedback <AC-ID> <text>", file=sys.stderr)
            return 1
        ac_id = parsed.args[0]
        text = " ".join(parsed.args[1:])
        request = {"cmd": "feedback", "ac": ac_id, "text": text}
    else:
        request = {"cmd": parsed.command}

    response = send_command(socket_path, request)

    if parsed.command == "status":
        print(format_status(response))
    elif "error" in response:
        print(f"Error: {response['error']}", file=sys.stderr)
        return 1
    else:
        ack = response.get("ack", False)
        state = response.get("state", "unknown")
        if ack:
            print(f"OK: engine is now {state}")
        else:
            print(f"Failed: {response.get('error', 'unknown error')}", file=sys.stderr)
            return 1

    return 0


if __name__ == "__main__":
    sys.exit(main())
