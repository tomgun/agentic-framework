"""
verify.py -- Autonomous test-fix loop with tiered execution (F-0161, F-0164).

Runs the project's test tiers (unit, integration, e2e, etc.) in order,
captures failures, spawns fresh Claude instances to fix them, re-runs tests,
repeats until green or max iterations per tier.

Supports multiple named test tiers parsed from STACK.md's `Test commands:`
section, with per-tier fix loops and configurable failure behavior.

Usage:
    from auto.verify import VerifyLoop
    loop = VerifyLoop(project_root=Path("."))
    result = loop.run(max_iterations=10)

    # Single tier:
    result = loop.run(tier_filter="unit")

    # Backward compatible — explicit test_command creates a single tier:
    loop = VerifyLoop(project_root=Path("."), test_command="npm test")
"""
from __future__ import annotations

import json
import re
import shutil
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402
from auto import spawn_claude  # noqa: E402

# Test runner detection patterns: (file_indicator, command)
TEST_RUNNER_PATTERNS = [
    # Python
    ("pytest.ini", "python -m pytest"),
    ("pyproject.toml", "python -m pytest"),
    ("setup.py", "python -m pytest"),
    # Node.js
    ("package.json", "npm test"),
    # Rust
    ("Cargo.toml", "cargo test"),
    # Go
    ("go.mod", "go test ./..."),
    # Shell
    ("tests/run_tests.sh", "bash tests/run_tests.sh"),
]

# STACK.md field patterns (old format, backward compat)
STACK_TEST_PATTERNS = [
    (r"Test runner:\s*(.+)", None),
    (r"Test command:\s*(.+)", None),
]

# Tier name patterns for fix prompt selection
_UNIT_TIER_RE = re.compile(r"unit|integration", re.IGNORECASE)
_E2E_TIER_RE = re.compile(r"e2e|ui|visual|dsp|playwright|cypress", re.IGNORECASE)


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class TestTier:
    """A named test tier with its own command and fix-loop settings."""
    name: str
    command: str
    timeout: int = 120
    max_fix_iterations: int = 5
    continue_on_failure: bool = False
    screenshot_dir: str = ""


@dataclass
class IterationResult:
    """Result of one test-fix iteration."""
    iteration: int
    tests_run: int = 0
    tests_passed: int = 0
    tests_failed: int = 0
    test_output: str = ""
    fix_applied: bool = False
    claude_output: str = ""
    duration_seconds: float = 0.0


@dataclass
class TierResult:
    """Result of running one test tier through its fix loop."""
    tier_name: str
    success: bool
    iterations_used: int
    tests_passed: int = 0
    tests_failed: int = 0
    iterations: list[IterationResult] = field(default_factory=list)
    final_test_output: str = ""
    screenshots: list[str] = field(default_factory=list)

    def to_dict(self) -> dict:
        d = {
            "tier_name": self.tier_name,
            "success": self.success,
            "iterations_used": self.iterations_used,
            "tests_passed": self.tests_passed,
            "tests_failed": self.tests_failed,
        }
        if self.screenshots:
            d["screenshots"] = self.screenshots
        return d


@dataclass
class VisualReviewResult:
    """Result of an AI-powered visual review of screenshots."""
    performed: bool = False
    screenshots_reviewed: int = 0
    concerns: list[str] = field(default_factory=list)
    summary: str = ""
    error: str = ""

    def to_dict(self) -> dict:
        d: dict = {"performed": self.performed}
        if self.performed:
            d["screenshots_reviewed"] = self.screenshots_reviewed
            d["summary"] = self.summary
            if self.concerns:
                d["concerns"] = self.concerns
        if self.error:
            d["error"] = self.error
        return d


@dataclass
class VerifyResult:
    """Final result of the verify loop."""
    success: bool
    iterations_used: int
    max_iterations: int
    test_command: str
    iterations: list[IterationResult] = field(default_factory=list)
    final_test_output: str = ""
    final_tests_passed: int = 0
    final_tests_failed: int = 0
    tier_results: list[TierResult] = field(default_factory=list)
    visual_review: Optional[VisualReviewResult] = None

    def to_dict(self) -> dict:
        d = {
            "success": self.success,
            "iterations_used": self.iterations_used,
            "max_iterations": self.max_iterations,
            "test_command": self.test_command,
            "final_tests_passed": self.final_tests_passed,
            "final_tests_failed": self.final_tests_failed,
            "iterations": [
                {
                    "iteration": it.iteration,
                    "tests_run": it.tests_run,
                    "tests_passed": it.tests_passed,
                    "tests_failed": it.tests_failed,
                    "fix_applied": it.fix_applied,
                    "duration_seconds": round(it.duration_seconds, 1),
                }
                for it in self.iterations
            ],
        }
        if self.tier_results:
            d["tier_results"] = [tr.to_dict() for tr in self.tier_results]
        if self.visual_review:
            d["visual_review"] = self.visual_review.to_dict()
        return d


def write_verification_artifact(
    project_root: Path, feature_id: str, result: VerifyResult,
) -> bool:
    """No-op: v2 work item dirs removed (hooks-first simplification F-0244).

    Verification results stay in test output and FEATURES.md state.
    Returns False always (no v2 work item directory to write to).
    """
    return False


class VerifyLoop:
    """Test-fix loop engine with tiered execution.

    1. Detect test tiers from STACK.md or project files
    2. Run each tier in order, each with its own fix loop
    3. Per tier: run tests -> if fail, spawn Claude fix -> re-run -> repeat
    4. Fast-fail by default (tier failure stops subsequent tiers)
    5. continue_on_failure per tier overrides fast-fail
    """

    def __init__(
        self,
        project_root: Path,
        test_command: Optional[str] = None,
        claude_command: str = "claude",
        on_iteration: Optional[callable] = None,
        on_tier: Optional[callable] = None,
        visual: bool = False,
    ) -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.claude_command = claude_command
        self.on_iteration = on_iteration  # callback(IterationResult)
        self.on_tier = on_tier  # callback(TierResult)
        self.visual = visual

        # Detect tiers — explicit test_command creates a single tier
        if test_command:
            self.tiers = [TestTier(name="default", command=test_command)]
        else:
            self.tiers = self._detect_test_tiers()

        # Backward compat: expose first tier's command as test_command
        self.test_command = self.tiers[0].command if self.tiers else "echo 'No test runner detected'"

    def run(
        self,
        max_iterations: int = 10,
        timeout_per_test: int = 120,
        timeout_per_fix: int = 300,
        tier_filter: Optional[str] = None,
    ) -> VerifyResult:
        """Run the tiered test-fix loop.

        Args:
            max_iterations: Default max fix attempts per tier (overridden by tier config).
            timeout_per_test: Default seconds for test run (overridden by tier config).
            timeout_per_fix: Seconds to allow for Claude fix attempt.
            tier_filter: If set, only run tiers whose name starts with this (case-insensitive).

        Returns:
            VerifyResult with full iteration history and per-tier results.
        """
        tiers = self._filter_tiers(tier_filter) if tier_filter else self.tiers

        # Single-tier fast path preserves original behavior exactly
        if len(tiers) == 1 and tiers[0].name == "default":
            return self._run_single_tier_compat(
                tiers[0], max_iterations, timeout_per_test, timeout_per_fix
            )

        result = VerifyResult(
            success=False,
            iterations_used=0,
            max_iterations=max_iterations,
            test_command=self.test_command,
        )

        all_passed = True
        for tier in tiers:
            tier_timeout = tier.timeout if tier.timeout != 120 else timeout_per_test
            tier_max_iter = tier.max_fix_iterations if tier.max_fix_iterations != 5 else max_iterations

            tier_result = self._run_tier(tier, tier_max_iter, tier_timeout, timeout_per_fix)
            result.tier_results.append(tier_result)
            result.iterations.extend(tier_result.iterations)
            result.iterations_used += tier_result.iterations_used

            if self.on_tier:
                self.on_tier(tier_result)

            if not tier_result.success:
                all_passed = False
                if not tier.continue_on_failure:
                    break

        # Aggregate results
        result.success = all_passed
        total_passed = sum(tr.tests_passed for tr in result.tier_results)
        total_failed = sum(tr.tests_failed for tr in result.tier_results)
        result.final_tests_passed = total_passed
        result.final_tests_failed = total_failed
        if result.tier_results:
            result.final_test_output = result.tier_results[-1].final_test_output

        # Visual review (advisory only)
        if self.visual:
            result.visual_review = self._run_visual_review(result.tier_results)

        return result

    def _run_tier(
        self,
        tier: TestTier,
        max_iterations: int,
        timeout_per_test: int,
        timeout_per_fix: int,
    ) -> TierResult:
        """Run one tier through its fix loop."""
        tier_result = TierResult(
            tier_name=tier.name,
            success=False,
            iterations_used=0,
        )

        for i in range(1, max_iterations + 1):
            start = time.time()
            iter_result = IterationResult(iteration=i)

            test_output, test_exit_code = self._run_tests(
                tier.command, timeout_per_test
            )
            iter_result.test_output = test_output

            passed, failed, total = self._parse_test_output(
                test_output, test_exit_code
            )
            iter_result.tests_run = total
            iter_result.tests_passed = passed
            iter_result.tests_failed = failed

            if test_exit_code == 0 and failed == 0:
                iter_result.duration_seconds = time.time() - start
                tier_result.iterations.append(iter_result)
                tier_result.success = True
                tier_result.iterations_used = i
                tier_result.tests_passed = passed
                tier_result.tests_failed = 0
                tier_result.final_test_output = test_output
                if self.on_iteration:
                    self.on_iteration(iter_result)
                break

            claude_output = self._spawn_claude_fix(
                test_output, failed, timeout_per_fix, tier.name
            )
            iter_result.claude_output = claude_output
            iter_result.fix_applied = bool(
                claude_output and "error" not in claude_output.lower()[:50]
            )
            iter_result.duration_seconds = time.time() - start

            tier_result.iterations.append(iter_result)
            tier_result.iterations_used = i

            if self.on_iteration:
                self.on_iteration(iter_result)
        else:
            # Max iterations exhausted
            final_output, _ = self._run_tests(tier.command, timeout_per_test)
            passed, failed, _ = self._parse_test_output(final_output, 1)
            tier_result.final_test_output = final_output
            tier_result.tests_passed = passed
            tier_result.tests_failed = failed

        # Collect screenshots after tier completes (pass or fail)
        tier_result.screenshots = self._collect_screenshots(tier)

        return tier_result

    def _run_single_tier_compat(
        self,
        tier: TestTier,
        max_iterations: int,
        timeout_per_test: int,
        timeout_per_fix: int,
    ) -> VerifyResult:
        """Run single-tier mode preserving exact original behavior."""
        result = VerifyResult(
            success=False,
            iterations_used=0,
            max_iterations=max_iterations,
            test_command=tier.command,
        )

        for i in range(1, max_iterations + 1):
            start = time.time()
            iter_result = IterationResult(iteration=i)

            test_output, test_exit_code = self._run_tests(
                tier.command, timeout_per_test
            )
            iter_result.test_output = test_output

            passed, failed, total = self._parse_test_output(
                test_output, test_exit_code
            )
            iter_result.tests_run = total
            iter_result.tests_passed = passed
            iter_result.tests_failed = failed

            if test_exit_code == 0 and failed == 0:
                iter_result.duration_seconds = time.time() - start
                result.iterations.append(iter_result)
                result.success = True
                result.iterations_used = i
                result.final_test_output = test_output
                result.final_tests_passed = passed
                result.final_tests_failed = 0
                if self.on_iteration:
                    self.on_iteration(iter_result)
                break

            claude_output = self._spawn_claude_fix(
                test_output, failed, timeout_per_fix, tier.name
            )
            iter_result.claude_output = claude_output
            iter_result.fix_applied = bool(
                claude_output and "error" not in claude_output.lower()[:50]
            )
            iter_result.duration_seconds = time.time() - start

            result.iterations.append(iter_result)
            result.iterations_used = i

            if self.on_iteration:
                self.on_iteration(iter_result)
        else:
            final_output, _ = self._run_tests(tier.command, timeout_per_test)
            passed, failed, _ = self._parse_test_output(final_output, 1)
            result.final_test_output = final_output
            result.final_tests_passed = passed
            result.final_tests_failed = failed

        # Visual review (advisory only)
        if self.visual:
            screenshots = self._collect_screenshots(tier)
            result.visual_review = self._run_visual_review_from_paths(screenshots)

        return result

    def _filter_tiers(self, prefix: str) -> list[TestTier]:
        """Filter tiers by name prefix (case-insensitive)."""
        prefix_lower = prefix.lower()
        matched = [t for t in self.tiers if t.name.lower().startswith(prefix_lower)]
        if not matched:
            # Fallback: substring match
            matched = [t for t in self.tiers if prefix_lower in t.name.lower()]
        return matched or self.tiers  # fall back to all tiers if no match

    # -----------------------------------------------------------------------
    # Tier detection from STACK.md
    # -----------------------------------------------------------------------

    def _detect_test_tiers(self) -> list[TestTier]:
        """Detect test tiers from STACK.md, falling back to single-tier detection."""
        stack_file = self.paths.stack_file
        if stack_file.exists():
            content = stack_file.read_text()

            # 1. Try new multi-tier format: `Test commands:` section
            tiers = self._parse_test_commands_section(content)
            if tiers:
                # Apply screenshot_dir to e2e tiers
                screenshot_dir = self._parse_screenshot_dir(content)
                if screenshot_dir:
                    for tier in tiers:
                        if _E2E_TIER_RE.search(tier.name):
                            tier.screenshot_dir = screenshot_dir
                return tiers

            # 2. Try old single-command format
            for pattern, _ in STACK_TEST_PATTERNS:
                match = re.search(pattern, content, re.IGNORECASE)
                if match:
                    cmd = match.group(1).strip()
                    if cmd and not self._is_placeholder(cmd):
                        return [TestTier(name="unit", command=cmd)]

        # 3. File-based detection
        for indicator, command in TEST_RUNNER_PATTERNS:
            if (self.project_root / indicator).exists():
                return [TestTier(name="unit", command=command)]

        return [TestTier(name="default", command="echo 'No test runner detected'")]

    def _parse_test_commands_section(self, content: str) -> list[TestTier]:
        """Parse the `Test commands:` multi-tier section from STACK.md.

        Format:
            Test commands:
              - Unit: `npm run test`
              - E2E API: `pytest tests/e2e/api/`
              - E2E UI: `npx playwright test`
        """
        # Find the "Test commands:" line
        match = re.search(r"^[- ]*Test commands:\s*$", content, re.MULTILINE | re.IGNORECASE)
        if not match:
            return []

        tiers = []
        # Parse indented entries after "Test commands:"
        lines = content[match.end():].split("\n")
        # Pattern: "  - Name: `command`" or "  - Name: command"
        tier_line_re = re.compile(
            r"^\s+-\s+(?P<name>[^:]+):\s*(?:`(?P<cmd_bt>[^`]+)`|(?P<cmd_plain>[^<\n]+))\s*$"
        )

        for line in lines:
            # Stop at next section or non-indented non-empty line
            stripped = line.strip()
            if stripped and not stripped.startswith("-") and not stripped.startswith("<!--"):
                break

            m = tier_line_re.match(line)
            if m:
                name = m.group("name").strip()
                cmd = (m.group("cmd_bt") or m.group("cmd_plain") or "").strip()
                if cmd and not self._is_placeholder(cmd):
                    tier = TestTier(name=name, command=cmd)
                    # Suggest longer timeout for e2e tiers
                    if _E2E_TIER_RE.search(name):
                        tier.timeout = 300
                    tiers.append(tier)

        return tiers

    @staticmethod
    def _is_placeholder(cmd: str) -> bool:
        """Check if a command is a placeholder/comment."""
        cmd = cmd.strip()
        return (
            not cmd
            or cmd.startswith("<!--")
            or cmd == "N/A"
            or cmd.lower() == "n/a"
            or "fill" in cmd.lower() and "-->" in cmd
        )

    @staticmethod
    def _parse_screenshot_dir(content: str) -> str:
        """Parse `E2E screenshots:` from STACK.md content."""
        match = re.search(
            r"^[- ]*E2E screenshots:\s*(?:`([^`]+)`|([^<\n]+))",
            content,
            re.MULTILINE | re.IGNORECASE,
        )
        if not match:
            return ""
        val = (match.group(1) or match.group(2) or "").strip()
        if VerifyLoop._is_placeholder(val):
            return ""
        return val

    _SCREENSHOT_EXTENSIONS = {".png", ".jpg", ".jpeg", ".gif", ".webp"}
    _MAX_SCREENSHOTS = 20

    def _collect_screenshots(self, tier: TestTier) -> list[str]:
        """Collect screenshots from a tier's screenshot_dir into session dir."""
        if not tier.screenshot_dir:
            return []
        src_dir = self.project_root / tier.screenshot_dir
        if not src_dir.is_dir():
            return []

        images = [
            p for p in src_dir.rglob("*")
            if p.is_file() and p.suffix.lower() in self._SCREENSHOT_EXTENSIONS
        ]
        if not images:
            return []
        images = sorted(images)[:self._MAX_SCREENSHOTS]

        # Copy to session screenshots dir
        tier_slug = re.sub(r"[^a-z0-9]+", "-", tier.name.lower()).strip("-")
        dest_dir = self.paths.session_dir / "screenshots" / tier_slug
        dest_dir.mkdir(parents=True, exist_ok=True)

        paths = []
        seen_names: set[str] = set()
        for img in images:
            name = img.name
            if name in seen_names:
                # Prefix with parent dir to avoid collision
                name = f"{img.parent.name}_{name}"
            seen_names.add(name)
            dest = dest_dir / name
            shutil.copy2(str(img), str(dest))
            paths.append(str(dest))
        return paths

    def _run_visual_review(self, tier_results: list[TierResult]) -> VisualReviewResult:
        """Run visual review on all screenshots from tier results."""
        all_screenshots = []
        for tr in tier_results:
            all_screenshots.extend(tr.screenshots)
        return self._run_visual_review_from_paths(all_screenshots)

    def _run_visual_review_from_paths(self, screenshot_paths: list[str]) -> VisualReviewResult:
        """Run visual review on a list of screenshot paths."""
        if not screenshot_paths:
            return VisualReviewResult(
                performed=False,
                error="No screenshots found for visual review",
            )
        from auto.visual import visual_review
        return visual_review(screenshot_paths)

    # Old API preserved for backward compat
    def _detect_test_command(self) -> str:
        """Detect the test command (backward compat, delegates to _detect_test_tiers)."""
        tiers = self._detect_test_tiers()
        return tiers[0].command if tiers else "echo 'No test runner detected'"

    # -----------------------------------------------------------------------
    # Test execution and parsing
    # -----------------------------------------------------------------------

    def _run_tests(self, command: Optional[str] = None, timeout: int = 120) -> tuple[str, int]:
        """Run a test command and return (output, exit_code).

        Args:
            command: Test command to run. If None, uses self.test_command.
            timeout: Seconds before timeout.
        """
        cmd = command or self.test_command
        try:
            proc = subprocess.run(
                cmd,
                shell=True,
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            output = proc.stdout + proc.stderr
            return output, proc.returncode
        except subprocess.TimeoutExpired:
            return f"Test command timed out after {timeout}s", 124
        except Exception as e:
            return f"Error running tests: {e}", 1

    def _parse_test_output(
        self, output: str, exit_code: int
    ) -> tuple[int, int, int]:
        """Parse test output to extract pass/fail counts.

        Returns (passed, failed, total). Best-effort parsing.
        """
        # Cypress format: "Passing: N" + "Failing: N" (check first, very specific)
        cy_passing = re.search(r"Passing:\s*(\d+)", output)
        cy_failing = re.search(r"Failing:\s*(\d+)", output)
        if cy_passing:
            p = int(cy_passing.group(1))
            f = int(cy_failing.group(1)) if cy_failing else 0
            return p, f, p + f

        # Jest/npm format: "Tests: X passed, Y failed, Z total"
        jest_match = re.search(
            r"Tests:\s+(\d+)\s+passed.*?(\d+)\s+failed.*?(\d+)\s+total",
            output,
        )
        if jest_match:
            return int(jest_match.group(1)), int(jest_match.group(2)), int(jest_match.group(3))

        # pytest format: "X passed, Y failed" (same line, comma-separated)
        pytest_match = re.search(
            r"(\d+) passed(?:,.*?(\d+) failed)?", output
        )
        if pytest_match:
            passed = int(pytest_match.group(1))
            failed = int(pytest_match.group(2) or 0)
            # Verify this isn't a multi-line Playwright output with separate "failed" line
            pw_failed = re.search(r"(\d+) failed", output)
            if failed == 0 and pw_failed:
                # "passed" and "failed" on different lines — use both
                return passed, int(pw_failed.group(1)), passed + int(pw_failed.group(1))
            return passed, failed, passed + failed

        # Go format: "ok" or "FAIL"
        go_ok = len(re.findall(r"^ok\s", output, re.MULTILINE))
        go_fail = len(re.findall(r"^FAIL\s", output, re.MULTILINE))
        if go_ok + go_fail > 0:
            return go_ok, go_fail, go_ok + go_fail

        # Cargo format: "test result: ok. X passed; Y failed"
        cargo_match = re.search(
            r"test result:.*?(\d+) passed.*?(\d+) failed", output
        )
        if cargo_match:
            passed = int(cargo_match.group(1))
            failed = int(cargo_match.group(2))
            return passed, failed, passed + failed

        # Generic: if exit code 0, assume all passed
        if exit_code == 0:
            return 1, 0, 1
        return 0, 1, 1

    # -----------------------------------------------------------------------
    # Claude fix spawning
    # -----------------------------------------------------------------------

    def _build_fix_prompt(
        self, test_output: str, num_failures: int, tier_name: str
    ) -> str:
        """Build a tier-appropriate fix prompt."""
        # Determine context size and prompt flavor based on tier name
        if _E2E_TIER_RE.search(tier_name):
            max_output = 8000
            flavor = (
                f"The {tier_name} tests have {num_failures} failure(s). "
                f"These tests simulate real user behavior / end-to-end scenarios. "
                f"Fix the application behavior so these tests pass. "
                f"Do NOT modify the tests.\n\n"
            )
        elif _UNIT_TIER_RE.search(tier_name):
            max_output = 4000
            flavor = (
                f"The {tier_name} tests have {num_failures} failure(s). "
                f"Fix the code so all tests pass. "
                f"Do NOT modify the tests unless the tests themselves have bugs.\n\n"
            )
        else:
            max_output = 4000
            flavor = (
                f"The test suite has {num_failures} failure(s). "
                f"Fix the code so all tests pass. Do NOT modify the tests unless "
                f"the tests themselves have bugs.\n\n"
            )

        if len(test_output) > max_output:
            test_output = "...(truncated)...\n" + test_output[-max_output:]

        return (
            f"{flavor}"
            f"Test output:\n```\n{test_output}\n```\n\n"
            f"Fix the failing code. Be minimal — change only what's needed."
        )

    def _spawn_claude_fix(
        self,
        test_output: str,
        num_failures: int,
        timeout: int,
        tier_name: str = "default",
    ) -> str:
        """Spawn a fresh Claude instance to fix test failures."""
        prompt = self._build_fix_prompt(test_output, num_failures, tier_name)

        return spawn_claude(
            self.claude_command,
            self.project_root,
            prompt,
            timeout=timeout,
        )


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------
def main() -> int:
    """Entry point for `ag auto verify` / `python -m auto.verify`."""
    import argparse

    parser = argparse.ArgumentParser(description="Autonomous test-fix loop")
    parser.add_argument(
        "--max-iterations",
        type=int,
        default=10,
        help="Maximum fix iterations (default: 10)",
    )
    parser.add_argument(
        "--test-command",
        type=str,
        default=None,
        help="Override test command (auto-detected from STACK.md)",
    )
    parser.add_argument(
        "--project-root",
        type=Path,
        default=Path.cwd(),
        help="Project root directory",
    )
    parser.add_argument(
        "--tier",
        type=str,
        default=None,
        help="Run only tiers matching this prefix (e.g., 'unit', 'e2e')",
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
    parser.add_argument(
        "--feature",
        type=str,
        default=None,
        help="Feature ID (F-XXXX). With --visual, saves evidence to .agentic/journal/evidence/",
    )
    args = parser.parse_args()

    # Warn if --feature without --visual
    if args.feature and not args.visual:
        print(
            "Warning: --feature requires --visual to generate evidence. "
            "No evidence saved.",
            file=sys.stderr,
        )

    def print_iteration(it: IterationResult) -> None:
        status = "PASS" if it.tests_failed == 0 else "FAIL"
        fix = " (fix applied)" if it.fix_applied else ""
        print(
            f"  [{it.iteration}] {status}: "
            f"{it.tests_passed} passed, {it.tests_failed} failed "
            f"({it.duration_seconds:.1f}s){fix}"
        )

    def print_tier(tr: TierResult) -> None:
        status = "PASS" if tr.success else "FAIL"
        print(
            f"\n  Tier '{tr.tier_name}': {status} "
            f"({tr.tests_passed} passed, {tr.tests_failed} failed, "
            f"{tr.iterations_used} iteration(s))"
        )

    loop = VerifyLoop(
        project_root=args.project_root,
        test_command=args.test_command,
        on_iteration=None if args.json else print_iteration,
        on_tier=None if args.json else print_tier,
        visual=args.visual,
    )

    if not args.json:
        if len(loop.tiers) > 1:
            print(f"Test tiers: {', '.join(t.name for t in loop.tiers)}")
        else:
            print(f"Test command: {loop.test_command}")
        print(f"Max iterations: {args.max_iterations}")
        if args.tier:
            print(f"Tier filter: {args.tier}")
        print()

    result = loop.run(
        max_iterations=args.max_iterations,
        tier_filter=args.tier,
    )

    if args.json:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        print()
        if result.success:
            print(
                f"All tests passing after {result.iterations_used} "
                f"iteration(s)."
            )
        else:
            print(
                f"Still {result.final_tests_failed} failure(s) after "
                f"{result.iterations_used} iterations."
            )

        # Print visual review results
        vr = result.visual_review
        if vr and vr.performed:
            print(f"\nVisual review ({vr.screenshots_reviewed} screenshots):")
            if vr.summary:
                print(f"  Summary: {vr.summary}")
            if vr.concerns:
                print("  Concerns (advisory):")
                for c in vr.concerns:
                    print(f"    - {c}")
            else:
                print("  No visual concerns found.")
        elif vr and vr.error:
            print(f"\nVisual review: {vr.error}")

    # Save evidence if --feature and --visual
    if args.feature and args.visual:
        _save_evidence(args.feature, result, loop.paths.evidence_dir)

    return 0 if result.success else 1


def _save_evidence(
    feature_id: str, result: VerifyResult, evidence_dir: Path
) -> None:
    """Save structured smoke test evidence to the evidence directory."""
    from datetime import datetime, timezone

    evidence_dir.mkdir(parents=True, exist_ok=True)

    dest = evidence_dir / f"{feature_id}-smoke.md"

    lines = [
        f"# Smoke Test Evidence: {feature_id}",
        "",
        f"**Generated**: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}",
        f"**Command**: `ag auto verify --visual --feature {feature_id}`",
        f"**Result**: {'PASS' if result.success else 'FAIL'}",
        "",
        "## Test Results",
        "",
        f"- Iterations: {result.iterations_used}/{result.max_iterations}",
        f"- Tests passed: {result.final_tests_passed}",
        f"- Tests failed: {result.final_tests_failed}",
        f"- Test command: `{result.test_command}`",
        "",
    ]

    vr = result.visual_review
    if vr and vr.performed:
        lines.extend([
            "## Visual Review",
            "",
            f"- Screenshots reviewed: {vr.screenshots_reviewed}",
            f"- Summary: {vr.summary}",
            "",
        ])
        if vr.concerns:
            lines.append("### Concerns")
            lines.append("")
            for c in vr.concerns:
                lines.append(f"- {c}")
            lines.append("")
        else:
            lines.append("No visual concerns found.")
            lines.append("")
    elif vr and vr.error:
        lines.extend([
            "## Visual Review",
            "",
            f"Error: {vr.error}",
            "",
        ])

    dest.write_text("\n".join(lines))
    print(f"\nEvidence saved: {dest}")


if __name__ == "__main__":
    sys.exit(main())
