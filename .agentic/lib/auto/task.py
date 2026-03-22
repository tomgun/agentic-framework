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

from settings import get_setting  # noqa: E402

from auto import spawn_claude  # noqa: E402
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
    pr_review_verdict: str = ""   # approved | request_changes | needs_discussion | skipped
    pr_review_summary: str = ""
    pr_fix_attempts: int = 0

    def to_dict(self) -> dict:
        d = {
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
        if self.pr_review_verdict:
            d["pr_review_verdict"] = self.pr_review_verdict
            d["pr_review_summary"] = self.pr_review_summary
            d["pr_fix_attempts"] = self.pr_fix_attempts
        return d


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
        visual: bool = False,
    ) -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.claude_command = claude_command
        self.on_ac_done = on_ac_done
        self.visual = visual
        self.engine = AutoEngine(project_root)
        # F-0300 R5: detect git mode for conditional git operations
        self._git_active = get_setting(project_root, "git_mode", "active") == "active"

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

        # Create feature branch (skipped in deferred-git mode — F-0300 R5)
        branch = f"feat/auto-{feature_id.lower()}"
        if not skip_branch and self._git_active:
            branch = self._create_branch(feature_id)
        elif not self._git_active:
            print(f"  [deferred-git] Skipping branch creation")
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
            visual=self.visual,
        )
        verify_result = verify_loop.run(max_iterations=5)
        result.verification_passed = verify_result.success

        # Write verification artifact to v2 work item dir (if active)
        from auto.verify import write_verification_artifact
        write_verification_artifact(self.project_root, feature_id, verify_result)

        # Doc check: run drift.sh --docs --check if docs_gate is enabled
        self._check_and_update_docs(feature_id)

        # Create PR (skipped in deferred-git mode — F-0300 R5)
        if not skip_pr and result.acs_passed > 0 and self._git_active:
            pr_url = self._create_pr(feature_id, result)
            result.pr_url = pr_url
        elif not self._git_active and result.acs_passed > 0:
            print(f"  [deferred-git] Skipping PR creation")

        result.success = (
            result.acs_passed == result.acs_total
            and result.verification_passed
        )

        # F-0235: Auto-review PR (fires after success is computed —
        # result.success reflects implementation correctness only)
        if result.pr_url and result.success:
            review_result = self._review_pr(feature_id, result.pr_url)
            result.pr_review_verdict = review_result.verdict
            result.pr_review_summary = review_result.summary
            result.pr_fix_attempts = review_result.fix_attempts

        return result

    def _review_pr(self, feature_id: str, pr_url: str):
        """Run auto-review on a PR (F-0235)."""
        from auto.pr_review import PRReviewer, PRReviewResult

        # Extract PR number from URL (e.g., https://github.com/org/repo/pull/42)
        pr_number = 0
        try:
            pr_number = int(pr_url.rstrip("/").split("/")[-1])
        except (ValueError, IndexError):
            return PRReviewResult(
                verdict="skipped",
                summary="Could not parse PR number from URL",
            )

        reviewer = PRReviewer(
            project_root=self.project_root,
            claude_command=self.claude_command,
        )
        return reviewer.review_and_fix(
            pr_number=pr_number,
            feature_id=feature_id,
        )

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
            f"- Read the spec file at .agentic/spec/acceptance/{feature_id}.md for full context\n"
            f"- Read the existing code to understand the codebase\n"
            f"- Implement the minimum code needed to satisfy this criterion\n"
            f"- Ensure tests pass after your changes\n"
            f"- Do NOT modify unrelated code\n"
            f"\n"
            f"IMPORTANT enforcement rules (F-0300 R2):\n"
            f"- You are implementing ONE specific acceptance criterion, not the whole feature\n"
            f"- Verify acceptance criteria exist at .agentic/spec/acceptance/{feature_id}.md\n"
            f"- A plan must exist at .agentic/journal/plans/*{feature_id}-plan.md\n"
            f"- Do NOT write code for features other than {feature_id}\n"
            f"{feedback_text}"
        )

        return spawn_claude(
            self.claude_command,
            self.project_root,
            prompt,
            timeout=timeout,
        )

    def _run_tests(self) -> bool:
        """Run the test suite and return True if all pass."""
        verify = VerifyLoop(
            project_root=self.project_root,
            claude_command=self.claude_command,
        )
        _, exit_code = verify._run_tests(command=verify.test_command, timeout=120)
        return exit_code == 0

    def _check_and_update_docs(self, feature_id: str) -> None:
        """Run doc drift check and spawn Claude to fix if needed."""

        docs_gate = get_setting(self.project_root, "docs_gate", "off")
        if docs_gate == "off":
            return

        drift_script = self.project_root / ".agentic" / "lib" / "tools" / "drift.sh"
        if not drift_script.exists():
            return

        print(f"Checking documentation drift for {feature_id}...")

        try:
            proc = subprocess.run(
                ["bash", str(drift_script), "--docs", "--check",
                 "--manifest", feature_id],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=30,
            )
        except (subprocess.TimeoutExpired, OSError):
            print("  Warning: drift.sh timed out or failed to run")
            return

        if proc.returncode == 0:
            print("  No documentation drift detected")
            return

        # Drift detected — spawn Claude to update docs
        print("  Documentation drift detected — spawning Claude to update docs...")
        drift_output = proc.stdout.strip()
        prompt = (
            f"Documentation drift detected for feature {feature_id}.\n\n"
            f"Drift report:\n{drift_output}\n\n"
            f"Instructions:\n"
            f"- Read the flagged documentation files\n"
            f"- Update them to reflect the current code changes\n"
            f"- Add a CHANGELOG.md entry for {feature_id} if missing\n"
            f"- Do NOT modify code files, only documentation\n"
        )

        spawn_claude(
            self.claude_command,
            self.project_root,
            prompt,
            timeout=120,
        )

        # F-0300 R5: skip git staging/commit in deferred-git mode
        if not self._git_active:
            print(f"  [deferred-git] Doc updates applied (not staged — no git)")
            return

        # Stage doc updates (tracked files only — preserves existing git add -u)
        try:
            subprocess.run(
                ["git", "add", "-u"],
                cwd=str(self.project_root),
                capture_output=True,
                check=True,
            )
        except subprocess.CalledProcessError:
            return  # Nothing to stage

        review_commit = get_setting(self.project_root, "review_commit", "human")
        if review_commit != "critical_agent":
            print(f"  Doc updates staged. Commit skipped (review_commit: human).")
            return

        # critical_agent mode — review doc changes before committing
        from auto.critical_agent import CriticalAgent

        agent = CriticalAgent(self.project_root)
        try:
            review_result = agent.review_commit(feature_id, "docs", "documentation updates")
        except Exception as e:
            print(f"  Critical agent error on docs: {e}. Unstaging.", file=sys.stderr)
            self._unstage_or_warn()
            return

        if review_result.verdict != "approved":
            print(
                f"  Critical agent rejected doc commit: {review_result.summary}",
                file=sys.stderr,
            )
            self._unstage_or_warn()
            return

        try:
            subprocess.run(
                ["git", "commit", "-m",
                 f"docs({feature_id}): update documentation for feature"],
                cwd=str(self.project_root),
                capture_output=True,
                check=True,
            )
            print("  Documentation updates committed")
        except subprocess.CalledProcessError:
            pass  # No changes to commit

    def _commit_ac(
        self, feature_id: str, ac_id: str, ac_text: str
    ) -> bool:
        """Commit current changes for a passing AC (respects review_commit).

        Returns True if changes were committed, False otherwise.
        With review_commit: human, stages only (returns False — expected).
        With review_commit: critical_agent, commits after adversarial review.
        In deferred-git mode: records AC completion without git ops (F-0300 R5).
        """
        # F-0300 R5: in deferred-git mode, skip all git operations
        if not self._git_active:
            print(f"  [deferred-git] AC {ac_id} passed (changes not staged — no git)")
            return False

        review_commit = get_setting(self.project_root, "review_commit", "human")

        # Always stage changes
        try:
            subprocess.run(
                ["git", "add", "-A"],
                cwd=str(self.project_root),
                capture_output=True,
                check=True,
            )
        except subprocess.CalledProcessError:
            return False

        if review_commit != "critical_agent":
            # human (default) — stage only, don't commit
            print(f"  Changes staged for {ac_id}. Commit skipped (review_commit: human).")
            return False

        # critical_agent mode — adversarial review then commit
        from auto.critical_agent import CriticalAgent

        agent = CriticalAgent(self.project_root)
        try:
            review_result = agent.review_commit(feature_id, ac_id, ac_text)
        except Exception as e:
            print(f"  Critical agent error: {e}. Unstaging.", file=sys.stderr)
            self._unstage_or_warn()
            return False

        if review_result.verdict != "approved":
            print(
                f"  Critical agent rejected commit for {ac_id}: {review_result.summary}",
                file=sys.stderr,
            )
            self._unstage_or_warn()
            return False

        # Approved — commit
        message = f"feat({feature_id}): implement {ac_id} — {ac_text[:60]}"
        try:
            subprocess.run(
                ["git", "commit", "-m", message],
                cwd=str(self.project_root),
                capture_output=True,
                check=True,
            )
            return True
        except subprocess.CalledProcessError:
            return False

    def _unstage_or_warn(self) -> None:
        """Unstage all files. Warn if unstaging fails."""
        result = subprocess.run(
            ["git", "reset", "HEAD"],
            cwd=str(self.project_root),
            capture_output=True,
            text=True,
        )
        if result.returncode != 0:
            print(
                f"  WARNING: git reset HEAD failed ({result.returncode}). "
                f"Files may remain staged. Run 'git reset HEAD' manually.",
                file=sys.stderr,
            )

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
    parser.add_argument(
        "--visual",
        action="store_true",
        help="Run AI visual review on collected screenshots",
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
        visual=args.visual,
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
