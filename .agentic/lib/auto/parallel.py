"""
parallel.py -- Parallel dispatcher for epic execution with worktrees.

Implements F-0214: Creates N worktrees, spawns N Claude processes via Popen,
monitors them with rolling slot management, and collects results.

Usage:
    from auto.parallel import ParallelDispatcher
    dispatcher = ParallelDispatcher(project_root=Path("."), claude_command="claude")
    result = dispatcher.run(["F-011", "F-0102", "F-0103"])
"""
from __future__ import annotations

import atexit
import os
import signal
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))
from paths import get_paths  # noqa: E402


@dataclass
class AgentProcess:
    """Tracks a single parallel agent process."""
    feature_id: str
    worktree_path: str
    branch_name: str
    process: subprocess.Popen
    start_time: float
    log_path: Path
    log_file: Optional[object] = None  # file handle for log output
    status: str = "running"  # running | completed | failed | timed_out


class ParallelDispatcher:
    """Dispatches parallel Claude processes in separate worktrees.

    Creates worktrees via worktree.sh, spawns Claude with `ag auto task
    F-XXXX --skip-branch` in each, monitors via Popen.poll(), and cleans
    up on completion or signal.
    """

    def __init__(
        self,
        project_root: Path,
        claude_command: str = "claude",
        max_parallel: int = 3,
        timeout: int = 600,
        skip_pr: bool = False,
    ) -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.claude_command = claude_command
        self.max_parallel = max(1, min(max_parallel, 10))
        self.timeout = timeout
        self.skip_pr = skip_pr
        self._stop_flag = False
        self._active: list[AgentProcess] = []
        self._log_dir = self.paths.session_dir / "parallel-logs"

        # Register signal/atexit cleanup
        self._prev_sigterm = signal.getsignal(signal.SIGTERM)
        self._prev_sigint = signal.getsignal(signal.SIGINT)
        signal.signal(signal.SIGTERM, self._signal_handler)
        signal.signal(signal.SIGINT, self._signal_handler)
        atexit.register(self._atexit_cleanup)

    def run(self, feature_ids: list[str]) -> "SchedulerResult":
        """Execute features in parallel worktrees with rolling slots.

        Returns SchedulerResult with same shape as sequential execution.
        """
        from auto.scheduler import SchedulerResult, FeatureWork

        result = SchedulerResult(success=False, features_total=len(feature_ids))
        if not feature_ids:
            result.stopped_reason = "no features to schedule"
            return result

        # Initialize tracking
        work_map: dict[str, FeatureWork] = {}
        for fid in feature_ids:
            fw = FeatureWork(feature_id=fid)
            work_map[fid] = fw
            result.feature_work.append(fw)

        pending = list(feature_ids)
        self._log_dir.mkdir(parents=True, exist_ok=True)

        print(
            f"Parallel dispatcher: {len(feature_ids)} features, "
            f"max {self.max_parallel} concurrent, timeout {self.timeout}s",
            file=sys.stderr,
        )

        try:
            # Fill initial slots
            while pending and len(self._active) < self.max_parallel:
                if self._stop_flag:
                    break
                fid = pending.pop(0)
                agent = self._spawn_feature(fid, work_map)
                if agent:
                    self._active.append(agent)
                    work_map[fid].status = "working"
                else:
                    work_map[fid].status = "failed"
                    work_map[fid].error = "worktree creation or claim failed"
                    result.features_failed += 1

            # Monitor loop
            while self._active and not self._stop_flag:
                time.sleep(2)
                finished = []

                for agent in self._active:
                    ret = agent.process.poll()
                    elapsed = time.time() - agent.start_time

                    if ret is not None:
                        # Process completed
                        finished.append(agent)
                        fw = work_map[agent.feature_id]
                        fw.duration_seconds = elapsed
                        if ret == 0:
                            agent.status = "completed"
                            fw.status = "completed"
                            result.features_completed += 1
                            print(
                                f"  [{agent.feature_id}] DONE ({elapsed:.1f}s)",
                                file=sys.stderr,
                            )
                        else:
                            agent.status = "failed"
                            fw.status = "failed"
                            fw.error = f"exit code {ret}"
                            result.features_failed += 1
                            print(
                                f"  [{agent.feature_id}] FAIL exit={ret} ({elapsed:.1f}s)",
                                file=sys.stderr,
                            )
                        self._release_claim(agent.feature_id)
                        self._cleanup_worktree(agent.feature_id)

                    elif elapsed > self.timeout:
                        # Timeout
                        finished.append(agent)
                        self._terminate_process(agent)
                        agent.status = "timed_out"
                        fw = work_map[agent.feature_id]
                        fw.status = "failed"
                        fw.error = f"timed out after {self.timeout}s"
                        fw.duration_seconds = elapsed
                        result.features_failed += 1
                        print(
                            f"  [{agent.feature_id}] TIMEOUT ({elapsed:.1f}s)",
                            file=sys.stderr,
                        )
                        self._release_claim(agent.feature_id)
                        self._cleanup_worktree(agent.feature_id)

                # Remove finished from active
                for agent in finished:
                    self._active.remove(agent)
                    # Close log file handle if open
                    self._close_log(agent)

                # Fill freed slots
                while pending and len(self._active) < self.max_parallel:
                    if self._stop_flag:
                        break
                    fid = pending.pop(0)
                    agent = self._spawn_feature(fid, work_map)
                    if agent:
                        self._active.append(agent)
                        work_map[fid].status = "working"
                    else:
                        work_map[fid].status = "failed"
                        work_map[fid].error = "worktree creation or claim failed"
                        result.features_failed += 1

        finally:
            # Ensure cleanup on any exit path
            self._cleanup_all()

        # Mark remaining pending as skipped
        for fw in work_map.values():
            if fw.status == "pending":
                fw.status = "skipped"
                result.features_skipped += 1

        result.features_review_blocked = sum(
            1 for fw in work_map.values() if fw.status == "review_blocked"
        )
        result.success = (result.features_completed == result.features_total)
        return result

    # -- Spawning -------------------------------------------------------------

    def _spawn_feature(
        self, feature_id: str, work_map: dict,
    ) -> Optional[AgentProcess]:
        """Create worktree, claim feature, spawn Claude process."""
        # Claim in AGENTS.json first (atomic dedup)
        if not self._claim_feature(feature_id):
            print(
                f"  [{feature_id}] SKIP — already claimed",
                file=sys.stderr,
            )
            return None

        # Create worktree
        worktree_path = self._create_worktree(feature_id)
        if not worktree_path:
            self._release_claim(feature_id)
            return None

        branch_name = f"feature/{feature_id}"
        log_path = self._log_dir / f"{feature_id}.log"

        # Build command
        prompt = self._build_prompt(feature_id)

        from auto import build_claude_cmd
        cmd = build_claude_cmd(
            self.claude_command,
            Path(worktree_path),
            prompt,
            print_mode=True,
        )

        # Spawn
        log_f = None
        try:
            log_f = open(log_path, "w")
            proc = subprocess.Popen(
                cmd,
                cwd=worktree_path,
                stdout=log_f,
                stderr=subprocess.STDOUT,
                text=True,
            )
        except (OSError, subprocess.SubprocessError) as e:
            if log_f:
                log_f.close()
            print(
                f"  [{feature_id}] spawn failed: {e}",
                file=sys.stderr,
            )
            self._release_claim(feature_id)
            self._cleanup_worktree(feature_id)
            return None

        print(
            f"  [{feature_id}] spawned (pid={proc.pid}, worktree={worktree_path})",
            file=sys.stderr,
        )

        # Checkpoint in AGENTS.json
        self._checkpoint(feature_id, "parallel spawn started")

        return AgentProcess(
            feature_id=feature_id,
            worktree_path=worktree_path,
            branch_name=branch_name,
            process=proc,
            start_time=time.time(),
            log_path=log_path,
            log_file=log_f,
        )

    def _build_prompt(self, feature_id: str) -> str:
        """Build the prompt for a parallel agent."""
        parts = [f"ag auto task {feature_id} --skip-branch"]
        if self.skip_pr:
            parts.append("--skip-pr")
        return " ".join(parts)

    # -- Worktree management --------------------------------------------------

    def _create_worktree(self, feature_id: str) -> Optional[str]:
        """Create a worktree via worktree.sh, return path or None."""
        worktree_sh = self.paths.tools_dir / "worktree.sh"
        try:
            proc = subprocess.run(
                ["bash", str(worktree_sh), "create", feature_id,
                 f"{feature_id} parallel execution"],
                capture_output=True, text=True,
                cwd=str(self.project_root),
                timeout=30,
            )
            if proc.returncode != 0:
                print(
                    f"  [{feature_id}] worktree create failed: {proc.stderr.strip()}",
                    file=sys.stderr,
                )
                return None
            # Last line of output is the worktree path
            lines = proc.stdout.strip().splitlines()
            return lines[-1] if lines else None
        except (OSError, subprocess.TimeoutExpired) as e:
            print(
                f"  [{feature_id}] worktree create error: {e}",
                file=sys.stderr,
            )
            return None

    def _cleanup_worktree(self, feature_id: str) -> None:
        """Clean up worktree via worktree.sh auto-remove."""
        worktree_sh = self.paths.tools_dir / "worktree.sh"
        try:
            subprocess.run(
                ["bash", str(worktree_sh), "auto-remove", feature_id],
                capture_output=True, text=True,
                cwd=str(self.project_root),
                timeout=30,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass  # Best-effort cleanup

    # -- AGENTS.json coordination ---------------------------------------------

    def _claim_feature(self, feature_id: str) -> bool:
        """Claim feature in AGENTS.json. Returns True on success."""
        agents_py = self.paths.tools_dir / "agents_helpers.py"
        try:
            proc = subprocess.run(
                ["python3", str(agents_py),
                 "--project-root", str(self.project_root),
                 "claim", feature_id, f"parallel-{os.getpid()}",
                 f"{feature_id} parallel execution",
                 str(os.getpid())],
                capture_output=True, text=True,
                timeout=10,
            )
            return proc.returncode == 0
        except (OSError, subprocess.TimeoutExpired):
            return False

    def _release_claim(self, feature_id: str) -> None:
        """Release feature claim in AGENTS.json."""
        agents_py = self.paths.tools_dir / "agents_helpers.py"
        try:
            subprocess.run(
                ["python3", str(agents_py),
                 "--project-root", str(self.project_root),
                 "release", feature_id, str(os.getpid())],
                capture_output=True, text=True,
                timeout=10,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass

    def _checkpoint(self, feature_id: str, note: str) -> None:
        """Update checkpoint in AGENTS.json."""
        agents_py = self.paths.tools_dir / "agents_helpers.py"
        try:
            subprocess.run(
                ["python3", str(agents_py),
                 "--project-root", str(self.project_root),
                 "checkpoint", feature_id, note],
                capture_output=True, text=True,
                timeout=10,
            )
        except (OSError, subprocess.TimeoutExpired):
            pass

    # -- Process management ---------------------------------------------------

    def _terminate_process(self, agent: AgentProcess) -> None:
        """Terminate agent process with grace period."""
        try:
            agent.process.terminate()
            try:
                agent.process.wait(timeout=10)
            except subprocess.TimeoutExpired:
                agent.process.kill()
                agent.process.wait(timeout=5)
        except (OSError, ProcessLookupError):
            pass

    def _close_log(self, agent: AgentProcess) -> None:
        """Close the log file handle."""
        try:
            if agent.log_file and not agent.log_file.closed:
                agent.log_file.close()
        except (OSError, AttributeError):
            pass

    # -- Signal handling and cleanup ------------------------------------------

    def _signal_handler(self, signum, frame):
        """Handle SIGTERM/SIGINT: set stop flag, cleanup will happen in finally."""
        self._stop_flag = True
        print(
            f"\nSignal {signum} received — stopping parallel execution...",
            file=sys.stderr,
        )

    def _cleanup_all(self) -> None:
        """Kill all active processes and clean up worktrees."""
        for agent in self._active:
            self._terminate_process(agent)
            self._close_log(agent)
            self._release_claim(agent.feature_id)
            self._cleanup_worktree(agent.feature_id)
        self._active.clear()

        # Restore signal handlers
        try:
            signal.signal(signal.SIGTERM, self._prev_sigterm or signal.SIG_DFL)
            signal.signal(signal.SIGINT, self._prev_sigint or signal.SIG_DFL)
        except (OSError, ValueError):
            pass

    def _atexit_cleanup(self) -> None:
        """atexit handler — last resort cleanup."""
        if self._active:
            self._cleanup_all()
