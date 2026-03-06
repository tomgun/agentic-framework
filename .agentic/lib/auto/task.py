"""
task.py -- Autonomous single-feature implementation (F-0162).

Reads acceptance criteria for a feature, spawns fresh Claude instances per AC,
runs tests, commits passing work, creates PR for review.

Usage:
    from auto.task import TaskRunner
    runner = TaskRunner(project_root=Path("."))
    result = runner.run(feature_id="F-0042")
"""
from __future__ import annotations

import json
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402

from auto.engine import AutoEngine, EngineState  # noqa: E402
from auto.verify import VerifyLoop  # noqa: E402


@dataclass
class ACResult:
    """Result of implementing one acceptance criterion."""
    ac_id: str
    ac_text: str
    status: str = "pending"  # pending | passed | failed | skipped
    test_passed: bool = False
    committed: bool = False
    duration_seconds: float = 0.0
    error: str = ""


@dataclass
class TaskResult:
    """Final result of a task run."""
    feature_id: str
    success: bool
    acs_total: int = 0
    acs_passed: int = 0
    acs_failed: int = 0
    acs_skipped: int = 0
    verification_passed: bool = False
    ac_results: list[ACResult] = field(default_factory=list)
    branch_name: str = ""
    pr_url: str = ""

    def to_dict(self) -> dict:
        return {
            "feature_id": self.feature_id,
            "success": self.success,
            "acs_total": self.acs_total,
            "acs_passed": self.acs_passed,
            "acs_failed": self.acs_failed,
            "acs_skipped": self.acs_skipped,
            "verification_passed": self.verification_passed,
            "branch_name": self.branch_name,
            "pr_url": self.pr_url,
            "ac_results": [
                {
                    "ac_id": r.ac_id,
                    "status": r.status,
                    "test_passed": r.test_passed,
                    "committed": r.committed,
                    "duration_seconds": round(r.duration_seconds, 1),
                }
                for r in self.ac_results
            ],
        }


class TaskRunner:
    """Single-feature autonomous implementation engine.

    1. Load ACs for the feature
    2. Create feature branch
    3. Per AC: spawn fresh Claude → run tests → commit if pass
    4. After all ACs: run full verify loop
    5. Create PR for human review
    """

    def __init__(
        self,
        project_root: Path,
        claude_command: str = "claude",
        on_ac_done: Optional[callable] = None,
    ) -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.claude_command = claude_command
        self.on_ac_done = on_ac_done
        self.engine = AutoEngine(project_root)

    def run(
        self,
        feature_id: str,
        max_retries_per_ac: int = 3,
        timeout_per_ac: int = 300,
        skip_branch: bool = False,
        skip_pr: bool = False,
    ) -> TaskResult:
        """Run single-feature implementation.

        Args:
            feature_id: Feature ID (e.g., "F-0042").
            max_retries_per_ac: Max retries per AC before marking failed.
            timeout_per_ac: Seconds per Claude invocation.
            skip_branch: Skip branch creation (use current branch).
            skip_pr: Skip PR creation at end.

        Returns:
            TaskResult with per-AC status and PR URL.
        """
        result = TaskResult(feature_id=feature_id, success=False)

        # Load acceptance criteria
        criteria = self.engine._load_acceptance_criteria(feature_id)
        if not criteria:
            result.acs_total = 0
            return result
        result.acs_total = len(criteria)

        # Create feature branch
        branch = f"feat/auto-{feature_id.lower()}"
        if not skip_branch:
            branch = self._create_branch(feature_id)
        result.branch_name = branch

        # Process each AC
        for ac_id, ac_text in criteria:
            if self.engine.engine_state.state == "stopping":
                break

            start = time.time()
            ac_result = ACResult(ac_id=ac_id, ac_text=ac_text)

            # Check for user feedback
            feedback = self.engine.engine_state.get_pending_feedback(ac_id)
            feedback_text = ""
            if feedback:
                feedback_text = "\n\nUser feedback:\n" + "\n".join(
                    f"- {f['text']}" for f in feedback
                )

            # Spawn Claude to implement AC
            success = False
            for attempt in range(1, max_retries_per_ac + 1):
                impl_output = self._spawn_claude_implement(
                    feature_id, ac_id, ac_text, feedback_text, timeout_per_ac
                )
                if "error:" in impl_output[:50].lower():
                    ac_result.error = impl_output
                    continue

                # Run test suite
                test_passed = self._run_tests()
                if test_passed:
                    success = True
                    break

            ac_result.duration_seconds = time.time() - start

            if success:
                ac_result.status = "passed"
                ac_result.test_passed = True
                # Commit passing AC
                committed = self._commit_ac(feature_id, ac_id, ac_text)
                ac_result.committed = committed
                result.acs_passed += 1
            else:
                ac_result.status = "failed"
                result.acs_failed += 1

            result.ac_results.append(ac_result)
            if self.on_ac_done:
                self.on_ac_done(ac_result)

        # After all ACs: run full verify loop
        verify_loop = VerifyLoop(
            project_root=self.project_root,
            claude_command=self.claude_command,
        )
        verify_result = verify_loop.run(max_iterations=5)
        result.verification_passed = verify_result.success

        # Create PR
        if not skip_pr and result.acs_passed > 0:
            pr_url = self._create_pr(feature_id, result)
            result.pr_url = pr_url

        result.success = (
            result.acs_passed == result.acs_total
            and result.verification_passed
        )
        return result

    def _create_branch(self, feature_id: str) -> str:
        """Create and checkout a feature branch."""
        branch = f"feat/auto-{feature_id.lower()}"
        try:
            subprocess.run(
                ["git", "checkout", "-b", branch],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                check=True,
            )
        except subprocess.CalledProcessError:
            # Branch may already exist
            subprocess.run(
                ["git", "checkout", branch],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                check=False,
            )
        return branch

    def _spawn_claude_implement(
        self,
        feature_id: str,
        ac_id: str,
        ac_text: str,
        feedback_text: str,
        timeout: int,
    ) -> str:
        """Spawn fresh Claude to implement an acceptance criterion."""
        prompt = (
            f"Implement acceptance criterion {ac_id} for feature {feature_id}.\n\n"
            f"Criterion: {ac_text}\n\n"
            f"Instructions:\n"
            f"- Read the existing code to understand the codebase\n"
            f"- Implement the minimum code needed to satisfy this criterion\n"
            f"- Ensure tests pass after your changes\n"
            f"- Do NOT modify unrelated code\n"
            f"{feedback_text}"
        )

        try:
            proc = subprocess.run(
                [self.claude_command, "--print", "--dangerously-skip-permissions", prompt],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            return proc.stdout + proc.stderr
        except FileNotFoundError:
            return "error: claude command not found"
        except subprocess.TimeoutExpired:
            return f"error: Claude timed out after {timeout}s"
        except Exception as e:
            return f"error: {e}"

    def _run_tests(self) -> bool:
        """Run the test suite and return True if all pass."""
        verify = VerifyLoop(
            project_root=self.project_root,
            claude_command=self.claude_command,
        )
        _, exit_code = verify._run_tests(command=verify.test_command, timeout=120)
        return exit_code == 0

    def _commit_ac(
        self, feature_id: str, ac_id: str, ac_text: str
    ) -> bool:
        """Commit current changes for a passing AC."""
        try:
            subprocess.run(
                ["git", "add", "-A"],
                cwd=str(self.project_root),
                capture_output=True,
                check=True,
            )
            message = f"feat({feature_id}): implement {ac_id} — {ac_text[:60]}"
            subprocess.run(
                ["git", "commit", "-m", message, "--no-verify"],
                cwd=str(self.project_root),
                capture_output=True,
                check=True,
            )
            return True
        except subprocess.CalledProcessError:
            return False

    def _create_pr(self, feature_id: str, result: TaskResult) -> str:
        """Create a pull request with implementation summary."""
        passed = [r for r in result.ac_results if r.status == "passed"]
        failed = [r for r in result.ac_results if r.status == "failed"]

        body_lines = [
            f"## Auto-implemented: {feature_id}",
            "",
            f"**ACs passed**: {len(passed)}/{result.acs_total}",
            f"**Verification**: {'passed' if result.verification_passed else 'failed'}",
            "",
            "### Acceptance Criteria",
        ]
        for r in result.ac_results:
            mark = "x" if r.status == "passed" else " "
            body_lines.append(f"- [{mark}] {r.ac_id}: {r.ac_text[:80]}")
        if failed:
            body_lines.extend(["", "### Needs Human Review"])
            for r in failed:
                body_lines.append(f"- {r.ac_id}: {r.error[:100] if r.error else 'tests failing'}")

        body = "\n".join(body_lines)
        title = f"feat: auto-implement {feature_id}"

        try:
            proc = subprocess.run(
                ["gh", "pr", "create", "--title", title, "--body", body],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=30,
            )
            return proc.stdout.strip()
        except Exception:
            return ""


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def main() -> int:
    """Entry point for `ag auto task F-XXXX`."""
    import argparse

    parser = argparse.ArgumentParser(
        description="Autonomous single-feature implementation"
    )
    parser.add_argument("feature_id", help="Feature ID (e.g., F-0042)")
    parser.add_argument(
        "--max-retries",
        type=int,
        default=3,
        help="Max retries per AC (default: 3)",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root directory",
    )
    parser.add_argument(
        "--skip-branch",
        action="store_true",
        help="Skip branch creation (use current branch)",
    )
    parser.add_argument(
        "--skip-pr",
        action="store_true",
        help="Skip PR creation",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Output result as JSON",
    )
    args = parser.parse_args()

    def print_ac(ac: ACResult) -> None:
        mark = "PASS" if ac.status == "passed" else "FAIL"
        print(
            f"  [{ac.ac_id}] {mark}: {ac.ac_text[:60]} "
            f"({ac.duration_seconds:.1f}s)"
        )

    runner = TaskRunner(
        project_root=args.project_root,
        on_ac_done=None if args.json else print_ac,
    )

    if not args.json:
        print(f"Feature: {args.feature_id}")
        print()

    result = runner.run(
        feature_id=args.feature_id,
        max_retries_per_ac=args.max_retries,
        skip_branch=args.skip_branch,
        skip_pr=args.skip_pr,
    )

    if args.json:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        print()
        if result.success:
            print(
                f"All {result.acs_passed} ACs passing. "
                f"PR: {result.pr_url or 'skipped'}"
            )
        else:
            print(
                f"{result.acs_passed}/{result.acs_total} ACs passed, "
                f"{result.acs_failed} failed."
            )

    return 0 if result.success else 1


if __name__ == "__main__":
    sys.exit(main())
