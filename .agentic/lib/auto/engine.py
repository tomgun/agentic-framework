"""
engine.py -- Autonomous workflow engine for the Agentic Framework.

Manages the execution loop: reads acceptance criteria, spawns fresh Claude
instances per AC, runs tests, tracks progress, and handles control commands
via a Unix domain socket.

Usage:
    from auto.engine import AutoEngine
    engine = AutoEngine(project_root=Path("."))
    engine.start(feature_id="F-0042", mode="task")
"""
from __future__ import annotations

import atexit
import json
import os
import re
import signal
import socket
import sys
import threading
import time
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Resolve paths.py from the lib/ directory (our parent)
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402
from auto import spawn_claude  # noqa: E402


# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SOCKET_FILENAME = "auto.sock"
PID_FILENAME = "auto.pid"
STATE_FILENAME = "auto-state.json"

# Complexity thresholds
CONTEXT_EXHAUSTION_THRESHOLD = 0.80  # 80% of context window


class EngineState:
    """Thread-safe engine state container."""

    def __init__(self) -> None:
        self._lock = threading.Lock()
        self._state = "idle"  # idle | running | paused | stopping | stopped
        self._current_ac: Optional[str] = None
        self._progress: dict[str, str] = {}  # ac_id -> status
        self._feedback: list[dict] = []
        self._feature_id: Optional[str] = None
        self._mode: Optional[str] = None
        self._decomposed: dict[str, list[dict]] = {}  # ac_id -> sub-tasks

    @property
    def state(self) -> str:
        with self._lock:
            return self._state

    @state.setter
    def state(self, value: str) -> None:
        with self._lock:
            self._state = value

    @property
    def current_ac(self) -> Optional[str]:
        with self._lock:
            return self._current_ac

    @current_ac.setter
    def current_ac(self, value: Optional[str]) -> None:
        with self._lock:
            self._current_ac = value

    def set_ac_status(self, ac_id: str, status: str) -> None:
        with self._lock:
            self._progress[ac_id] = status

    def add_feedback(self, ac_id: str, text: str) -> None:
        with self._lock:
            self._feedback.append({"ac": ac_id, "text": text, "ts": time.time()})

    def get_pending_feedback(self, ac_id: str) -> list[dict]:
        with self._lock:
            matching = [f for f in self._feedback if f["ac"] == ac_id]
            self._feedback = [f for f in self._feedback if f["ac"] != ac_id]
            return matching

    def record_decomposition(
        self, ac_id: str, sub_tasks: list[dict]
    ) -> None:
        """Record that an AC was decomposed into sub-tasks."""
        with self._lock:
            self._decomposed[ac_id] = sub_tasks

    def set_subtask_status(
        self, ac_id: str, subtask_index: int, status: str
    ) -> None:
        """Update status of a specific sub-task within a decomposed AC."""
        with self._lock:
            if ac_id in self._decomposed and subtask_index < len(
                self._decomposed[ac_id]
            ):
                self._decomposed[ac_id][subtask_index]["status"] = status

    def to_dict(self) -> dict:
        with self._lock:
            return {
                "state": self._state,
                "feature_id": self._feature_id,
                "mode": self._mode,
                "current_ac": self._current_ac,
                "progress": dict(self._progress),
                "decomposed": {
                    k: list(v) for k, v in self._decomposed.items()
                },
                "feedback_queue_size": len(self._feedback),
            }


class ControlServer:
    """Unix domain socket server for receiving control commands.

    Protocol: newline-delimited JSON.
    Request:  {"cmd": "pause"|"resume"|"stop"|"feedback"|"status", ...}
    Response: {"ack": true, "state": "...", ...}
    """

    def __init__(self, socket_path: Path, engine_state: EngineState) -> None:
        self.socket_path = socket_path
        self.engine_state = engine_state
        self._server: Optional[socket.socket] = None
        self._thread: Optional[threading.Thread] = None
        self._running = False

    def start(self) -> None:
        """Start the control socket listener in a background thread."""
        self._cleanup_stale_socket()
        self._server = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        self._server.bind(str(self.socket_path))
        self._server.listen(5)
        self._server.settimeout(1.0)  # allow periodic shutdown checks
        self._running = True
        self._thread = threading.Thread(
            target=self._listen_loop, daemon=True, name="control-server"
        )
        self._thread.start()

    def stop(self) -> None:
        """Stop the listener and clean up the socket file."""
        self._running = False
        if self._server:
            try:
                self._server.close()
            except OSError:
                pass
        if self._thread and self._thread.is_alive():
            self._thread.join(timeout=3.0)
        self._remove_socket()

    def _listen_loop(self) -> None:
        while self._running:
            try:
                conn, _ = self._server.accept()
            except socket.timeout:
                continue
            except OSError:
                break
            try:
                self._handle_connection(conn)
            finally:
                conn.close()

    def _handle_connection(self, conn: socket.socket) -> None:
        data = b""
        while True:
            chunk = conn.recv(4096)
            if not chunk:
                break
            data += chunk
            if b"\n" in data:
                break

        for line in data.decode("utf-8").strip().split("\n"):
            if not line:
                continue
            try:
                request = json.loads(line)
            except json.JSONDecodeError:
                response = {"ack": False, "error": "invalid JSON"}
                conn.sendall((json.dumps(response) + "\n").encode())
                continue

            response = self._dispatch(request)
            conn.sendall((json.dumps(response) + "\n").encode())

    def _dispatch(self, request: dict) -> dict:
        cmd = request.get("cmd", "")

        if cmd == "pause":
            self.engine_state.state = "paused"
            return {"ack": True, "state": "paused"}

        elif cmd == "resume":
            if self.engine_state.state == "paused":
                self.engine_state.state = "running"
            return {"ack": True, "state": self.engine_state.state}

        elif cmd == "stop":
            self.engine_state.state = "stopping"
            return {"ack": True, "state": "stopping"}

        elif cmd == "feedback":
            ac = request.get("ac", "")
            text = request.get("text", "")
            if not ac or not text:
                return {"ack": False, "error": "feedback requires 'ac' and 'text'"}
            self.engine_state.add_feedback(ac, text)
            return {"ack": True, "state": self.engine_state.state, "queued": True}

        elif cmd == "status":
            return {"ack": True, **self.engine_state.to_dict()}

        else:
            return {"ack": False, "error": f"unknown command: {cmd}"}

    def _cleanup_stale_socket(self) -> None:
        """Remove a stale socket file if no process is listening on it."""
        if not self.socket_path.exists():
            return
        # Try to connect -- if refused or not a socket, it's stale
        test_sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
        try:
            test_sock.connect(str(self.socket_path))
            # Connection succeeded -- another engine is running
            test_sock.close()
            raise RuntimeError(
                f"Another auto engine is already running (socket: {self.socket_path})"
            )
        except (ConnectionRefusedError, FileNotFoundError, OSError):
            # Stale socket or not a real socket file -- safe to remove
            self._remove_socket()
        finally:
            test_sock.close()

    def _remove_socket(self) -> None:
        try:
            self.socket_path.unlink()
        except FileNotFoundError:
            pass


class AutoEngine:
    """Main autonomous workflow engine.

    Orchestrates: read ACs -> estimate complexity -> spawn Claude per AC ->
    run tests -> track progress -> handle control commands.
    """

    def __init__(self, project_root: Path, claude_command: str = "claude") -> None:
        self.paths = get_paths(project_root)
        self.project_root = project_root.resolve()
        self.claude_command = claude_command
        self.session_dir = self.paths.session_dir
        self.socket_path = self.session_dir / SOCKET_FILENAME
        self.pid_path = self.session_dir / PID_FILENAME
        self.state_path = self.session_dir / STATE_FILENAME
        self.engine_state = EngineState()
        self.control_server = ControlServer(self.socket_path, self.engine_state)

        # Register cleanup handlers
        atexit.register(self._cleanup)
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)

    def start(self, feature_id: str, mode: str = "task") -> dict:
        """Start the engine for a feature.

        Args:
            feature_id: Feature ID (e.g., "F-0042")
            mode: "verify" | "task" | "crunch"

        Returns:
            Final state dict with progress and any oversized ACs.
        """
        self.engine_state._feature_id = feature_id
        self.engine_state._mode = mode
        self.engine_state.state = "running"

        # Write PID file
        self.session_dir.mkdir(parents=True, exist_ok=True)
        self.pid_path.write_text(str(os.getpid()))

        # Start control socket
        self.control_server.start()

        try:
            # Load acceptance criteria
            criteria = self._load_acceptance_criteria(feature_id)
            if not criteria:
                return {"error": f"No acceptance criteria found for {feature_id}"}

            # Process each AC
            for ac_id, ac_text in criteria:
                if self.engine_state.state == "stopping":
                    break

                # Wait while paused
                while self.engine_state.state == "paused":
                    time.sleep(0.5)
                    if self.engine_state.state == "stopping":
                        break

                if self.engine_state.state == "stopping":
                    break

                self.engine_state.current_ac = ac_id
                self.engine_state.set_ac_status(ac_id, "in_progress")
                self._save_state()

                # Pre-flight complexity estimation
                complexity = self._estimate_complexity(ac_id, ac_text)

                if complexity == "LARGE":
                    # Decompose into sub-tasks and implement each
                    result = self._implement_large_ac(ac_id, ac_text)
                else:
                    # Direct implementation attempt
                    result = self._implement_ac(ac_id, ac_text, complexity)

                if result["status"] == "passed":
                    self.engine_state.set_ac_status(ac_id, "passed")
                elif result["status"] == "failed":
                    self.engine_state.set_ac_status(ac_id, "failed")
                else:
                    self.engine_state.set_ac_status(ac_id, result["status"])

                self._save_state()

            self.engine_state.state = "stopped"
            self.engine_state.current_ac = None
            self._save_state()
            return self.engine_state.to_dict()

        finally:
            self._cleanup()

    def _load_acceptance_criteria(self, feature_id: str) -> list[tuple[str, str]]:
        """Load acceptance criteria from contract YAML or legacy markdown.

        Tries contract first (spec/contracts/F-XXXX.yaml), falls back to
        legacy markdown (spec/acceptance/F-XXXX.md).

        Returns list of (ac_id, ac_text) tuples.
        """
        # Try contract YAML first
        contract_file = self.paths.contracts_dir / f"{feature_id}.yaml"
        if contract_file.exists():
            return self._load_criteria_from_contract(contract_file)

        # Fall back to legacy markdown
        ac_file = self.paths.acceptance_dir / f"{feature_id}.md"
        if not ac_file.exists():
            return []

        criteria = []
        content = ac_file.read_text()
        ac_counter = 0
        for line in content.splitlines():
            stripped = line.strip()
            # Match lines like "- [ ] AC-001: ..." or "- [ ] Given ..."
            if stripped.startswith("- [ ]") or stripped.startswith("- [x]"):
                ac_counter += 1
                # Extract AC ID if present, else generate one
                text = stripped.lstrip("- [ ]").lstrip("- [x]").strip()
                if text.startswith("AC-"):
                    parts = text.split(":", 1)
                    ac_id = parts[0].strip()
                    ac_text = parts[1].strip() if len(parts) > 1 else text
                else:
                    ac_id = f"AC-{ac_counter:03d}"
                    ac_text = text
                criteria.append((ac_id, ac_text))
        return criteria

    def _load_criteria_from_contract(self, contract_file) -> list[tuple[str, str]]:
        """Load assertions from a YAML contract file."""
        try:
            from contracts import load_contract
            contract = load_contract(contract_file)
            return [(a.id, a.text) for a in contract.assertions if not a.draft]
        except (ImportError, ValueError, OSError):
            return []

    def _estimate_complexity(
        self, ac_id: str, ac_text: str
    ) -> str:
        """Estimate AC complexity: SMALL, MEDIUM, or LARGE.

        Tries Claude-based estimation first, falls back to keyword heuristic.
        """
        prompt_template = _LIB_DIR / "auto" / "prompts" / "estimate-complexity.md"
        if self.engine_state.state == "running" and prompt_template.exists():
            template = prompt_template.read_text()
            prompt = template.replace("{ac_id}", ac_id).replace(
                "{ac_text}", ac_text
            ).replace("{codebase_summary}", "See project CLAUDE.md for context.")

            output = spawn_claude(
                self.claude_command,
                self.project_root,
                prompt,
                timeout=60,
            )
            # Extract one-word answer
            for word in ("LARGE", "MEDIUM", "SMALL"):
                if word in output.upper():
                    return word

        # Heuristic fallback
        large_keywords = [
            "full system", "complete implementation", "entire", "infrastructure",
            "database schema", "migration", "authentication system",
        ]
        text_lower = ac_text.lower()
        if any(kw in text_lower for kw in large_keywords):
            return "LARGE"
        if len(ac_text) > 200:
            return "MEDIUM"
        return "SMALL"

    def _implement_ac(
        self, ac_id: str, ac_text: str, complexity: str
    ) -> dict:
        """Implement a single acceptance criterion (or sub-task).

        1. Spawns a fresh Claude instance with focused context
        2. Runs the test suite
        3. Returns 'passed', 'failed', or 'needs_decomposition'
        """
        feedback = self.engine_state.get_pending_feedback(ac_id)
        feedback_text = ""
        if feedback:
            feedback_text = "\n\nUser feedback:\n" + "\n".join(
                f"- {f['text']}" for f in feedback
            )

        feature_id = self.engine_state._feature_id or "unknown"
        prompt = (
            f"Implement acceptance criterion {ac_id} for feature {feature_id}.\n\n"
            f"Criterion: {ac_text}\n\n"
            f"Complexity estimate: {complexity}\n\n"
            f"Instructions:\n"
            f"- Read the contract at .agentic/spec/contracts/{feature_id}.yaml for full context\n"
            f"- Read the existing code to understand the codebase\n"
            f"- Implement the minimum code needed to satisfy this criterion\n"
            f"- Ensure tests pass after your changes\n"
            f"- If your changes affect documented behavior (README, CHANGELOG, docs/), update those docs in the same change\n"
            f"- Do NOT modify unrelated code\n"
            f"{feedback_text}"
        )

        timeout = 600 if complexity == "LARGE" else 300
        output = spawn_claude(
            self.claude_command,
            self.project_root,
            prompt,
            timeout=timeout,
        )

        if output.startswith("error:"):
            return {"status": "failed", "ac_id": ac_id, "error": output}

        # Run tests to verify implementation
        test_passed = self._run_tests()
        if test_passed:
            return {"status": "passed", "ac_id": ac_id}

        return {"status": "failed", "ac_id": ac_id}

    def _decompose_ac(self, ac_id: str, ac_text: str) -> list[dict]:
        """Decompose a large AC into smaller sub-tasks.

        Spawns Claude with the decompose-ac.md prompt to break the AC into
        2-5 sequential sub-tasks. Falls back to a single wrapper sub-task.

        Returns list of sub-task dicts: [{"id": "AC-001.1", "text": "...", "status": "pending"}]
        """
        prompt_template = _LIB_DIR / "auto" / "prompts" / "decompose-ac.md"
        if self.engine_state.state == "running" and prompt_template.exists():
            template = prompt_template.read_text()
            prompt = template.replace("{ac_id}", ac_id).replace(
                "{ac_text}", ac_text
            ).replace("{codebase_summary}", "See project CLAUDE.md for context.")

            output = spawn_claude(
                self.claude_command,
                self.project_root,
                prompt,
                timeout=120,
            )

            # Parse JSON array from output
            try:
                json_match = re.search(r"\[.*\]", output, re.DOTALL)
                if json_match:
                    items = json.loads(json_match.group())
                    if isinstance(items, list) and len(items) >= 2:
                        return [
                            {
                                "id": f"{ac_id}.{i+1}",
                                "text": item.get("text", str(item)),
                                "status": "pending",
                            }
                            for i, item in enumerate(items)
                        ]
            except (json.JSONDecodeError, AttributeError):
                pass

        # Fallback: single sub-task wrapping the original AC
        return [
            {
                "id": f"{ac_id}.1",
                "text": ac_text,
                "status": "pending",
            }
        ]

    def _implement_large_ac(self, ac_id: str, ac_text: str) -> dict:
        """Handle a LARGE AC by decomposing into sub-tasks and implementing each.

        Flow:
        1. Decompose AC into 2-5 sub-tasks
        2. Implement each sub-task with a fresh Claude instance
        3. If any sub-task itself exhausts context, decompose further (one level)
        4. All sub-tasks must pass for AC to be marked passed

        Returns dict with 'status': 'passed' | 'failed' | 'partial'
        """
        sub_tasks = self._decompose_ac(ac_id, ac_text)
        self.engine_state.record_decomposition(ac_id, sub_tasks)
        self._save_state()

        all_passed = True
        any_passed = False

        for i, sub_task in enumerate(sub_tasks):
            if self.engine_state.state in ("stopping", "paused"):
                while self.engine_state.state == "paused":
                    time.sleep(0.5)
                if self.engine_state.state == "stopping":
                    break

            self.engine_state.set_subtask_status(ac_id, i, "in_progress")
            self._save_state()

            result = self._implement_ac(
                sub_task["id"], sub_task["text"], "SMALL"
            )

            if result["status"] == "passed":
                self.engine_state.set_subtask_status(ac_id, i, "passed")
                any_passed = True
            elif result["status"] == "needs_decomposition":
                # Sub-task itself too big — one more level of decomposition
                inner_tasks = self._decompose_ac(sub_task["id"], sub_task["text"])
                inner_all_passed = True
                for inner in inner_tasks:
                    inner_result = self._implement_ac(
                        inner["id"], inner["text"], "SMALL"
                    )
                    if inner_result["status"] != "passed":
                        inner_all_passed = False
                if inner_all_passed:
                    self.engine_state.set_subtask_status(ac_id, i, "passed")
                    any_passed = True
                else:
                    self.engine_state.set_subtask_status(ac_id, i, "failed")
                    all_passed = False
            else:
                self.engine_state.set_subtask_status(ac_id, i, "failed")
                all_passed = False

            self._save_state()

        if all_passed:
            return {"status": "passed"}
        elif any_passed:
            return {"status": "partial"}
        else:
            return {"status": "failed"}

    def _run_tests(self) -> bool:
        """Run the project test suite and return True if all pass."""
        from auto.verify import VerifyLoop
        verify = VerifyLoop(
            project_root=self.project_root,
            claude_command=self.claude_command,
        )
        _, exit_code = verify._run_tests(command=verify.test_command, timeout=120)
        return exit_code == 0

    def _save_state(self) -> None:
        """Persist current state to auto-state.json."""
        self.session_dir.mkdir(parents=True, exist_ok=True)
        state = self.engine_state.to_dict()
        state["pid"] = os.getpid()
        state["updated_at"] = time.time()
        tmp = self.state_path.with_suffix(".tmp")
        tmp.write_text(json.dumps(state, indent=2) + "\n")
        tmp.rename(self.state_path)

    def _cleanup(self) -> None:
        """Clean up socket, PID file, control server, and flush feedback."""
        # Flush any remaining in-flight feedback to FEEDBACK_LOG.md
        self._flush_feedback()
        self.control_server.stop()
        try:
            self.pid_path.unlink()
        except FileNotFoundError:
            pass

    def _flush_feedback(self) -> None:
        """Persist in-flight feedback items to FEEDBACK_LOG.md via feedback.sh."""
        with self.engine_state._lock:
            pending = list(self.engine_state._feedback)
        if not pending:
            return
        feedback_sh = self.project_root / ".agentic" / "lib" / "tools" / "feedback.sh"
        if not feedback_sh.exists():
            return
        import subprocess
        for item in pending:
            text = item.get("text", "")
            ac_id = item.get("ac", "")
            if not text:
                continue
            cmd = ["bash", str(feedback_sh), "add", text]
            if ac_id:
                cmd.extend(["--ac", self.engine_state._feature_id or "", ac_id])
            try:
                subprocess.run(cmd, timeout=10, capture_output=True)
            except Exception:
                pass  # best-effort flush

    def _signal_handler(self, signum: int, frame) -> None:
        """Handle SIGTERM/SIGINT gracefully."""
        self.engine_state.state = "stopping"


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def main() -> None:
    """Entry point for `python -m auto.engine`."""
    import argparse

    parser = argparse.ArgumentParser(description="Agentic auto engine")
    parser.add_argument("feature_id", help="Feature ID (e.g., F-0042)")
    parser.add_argument(
        "--mode",
        choices=["verify", "task", "crunch"],
        default="task",
        help="Execution mode",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root directory",
    )
    parser.add_argument(
        "--visual",
        action="store_true",
        help="Enable AI visual review (used at final verification step, not per-AC)",
    )
    args = parser.parse_args()

    if args.visual:
        print("Note: --visual is applied at final verification only, not per-AC iteration.")

    engine = AutoEngine(args.project_root)
    result = engine.start(feature_id=args.feature_id, mode=args.mode)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
