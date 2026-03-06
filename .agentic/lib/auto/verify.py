"""
verify.py -- Autonomous test-fix loop (F-0161).

Runs the project's test suite, captures failures, spawns fresh Claude
instances to fix them, re-runs tests, repeats until green or max iterations.

Usage:
    from auto.verify import VerifyLoop
    loop = VerifyLoop(project_root=Path("."))
    result = loop.run(max_iterations=10)
"""
from __future__ import annotations

import json
import re
import subprocess
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402

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

# STACK.md field patterns
STACK_TEST_PATTERNS = [
    (r"Test runner:\s*(.+)", None),
    (r"Test command:\s*(.+)", None),
]


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

    def to_dict(self) -> dict:
        return {
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


class VerifyLoop:
    """Test-fix loop engine.

    1. Detect test runner from STACK.md or project files
    2. Run tests
    3. If failures: spawn fresh Claude to fix them
    4. Re-run tests
    5. Repeat until green or max iterations
    """

    def __init__(
        self,
        project_root: Path,
        test_command: Optional[str] = None,
        claude_command: str = "claude",
        on_iteration: Optional[callable] = None,
    ) -> None:
        self.project_root = project_root.resolve()
        self.paths = get_paths(project_root)
        self.test_command = test_command or self._detect_test_command()
        self.claude_command = claude_command
        self.on_iteration = on_iteration  # callback(IterationResult)

    def run(
        self,
        max_iterations: int = 10,
        timeout_per_test: int = 120,
        timeout_per_fix: int = 300,
    ) -> VerifyResult:
        """Run the test-fix loop.

        Args:
            max_iterations: Max fix attempts before giving up.
            timeout_per_test: Seconds to allow for test run.
            timeout_per_fix: Seconds to allow for Claude fix attempt.

        Returns:
            VerifyResult with full iteration history.
        """
        result = VerifyResult(
            success=False,
            iterations_used=0,
            max_iterations=max_iterations,
            test_command=self.test_command,
        )

        for i in range(1, max_iterations + 1):
            start = time.time()
            iter_result = IterationResult(iteration=i)

            # Run tests
            test_output, test_exit_code = self._run_tests(timeout_per_test)
            iter_result.test_output = test_output

            # Parse test results
            passed, failed, total = self._parse_test_output(
                test_output, test_exit_code
            )
            iter_result.tests_run = total
            iter_result.tests_passed = passed
            iter_result.tests_failed = failed

            if test_exit_code == 0 and failed == 0:
                # All tests pass — done
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

            # Tests failing — spawn Claude to fix
            claude_output = self._spawn_claude_fix(
                test_output, failed, timeout_per_fix
            )
            iter_result.claude_output = claude_output
            iter_result.fix_applied = bool(claude_output and "error" not in claude_output.lower()[:50])
            iter_result.duration_seconds = time.time() - start

            result.iterations.append(iter_result)
            result.iterations_used = i

            if self.on_iteration:
                self.on_iteration(iter_result)
        else:
            # Max iterations exhausted — run final test to capture state
            final_output, _ = self._run_tests(timeout_per_test)
            passed, failed, _ = self._parse_test_output(final_output, 1)
            result.final_test_output = final_output
            result.final_tests_passed = passed
            result.final_tests_failed = failed

        return result

    def _detect_test_command(self) -> str:
        """Detect the test command from STACK.md or project files."""
        # Try STACK.md first
        stack_file = self.paths.stack_file
        if stack_file.exists():
            content = stack_file.read_text()
            for pattern, _ in STACK_TEST_PATTERNS:
                match = re.search(pattern, content, re.IGNORECASE)
                if match:
                    cmd = match.group(1).strip()
                    if cmd and cmd != "<!--" and not cmd.startswith("<!--"):
                        return cmd

        # Fall back to file detection
        for indicator, command in TEST_RUNNER_PATTERNS:
            if (self.project_root / indicator).exists():
                return command

        # Last resort
        return "echo 'No test runner detected'"

    def _run_tests(self, timeout: int) -> tuple[str, int]:
        """Run the test suite and return (output, exit_code)."""
        try:
            proc = subprocess.run(
                self.test_command,
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
        # pytest format: "X passed, Y failed"
        pytest_match = re.search(
            r"(\d+) passed(?:.*?(\d+) failed)?", output
        )
        if pytest_match:
            passed = int(pytest_match.group(1))
            failed = int(pytest_match.group(2) or 0)
            return passed, failed, passed + failed

        # Jest/npm format: "Tests: X passed, Y failed, Z total"
        jest_match = re.search(
            r"Tests:\s+(\d+)\s+passed.*?(\d+)\s+failed.*?(\d+)\s+total",
            output,
        )
        if jest_match:
            return int(jest_match.group(1)), int(jest_match.group(2)), int(jest_match.group(3))

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

    def _spawn_claude_fix(
        self, test_output: str, num_failures: int, timeout: int
    ) -> str:
        """Spawn a fresh Claude instance to fix test failures.

        Uses --print mode for non-interactive, single-shot fixing.
        """
        # Truncate test output if too long (keep last 4000 chars — the failures)
        if len(test_output) > 4000:
            test_output = "...(truncated)...\n" + test_output[-4000:]

        prompt = (
            f"The test suite has {num_failures} failure(s). "
            f"Fix the code so all tests pass. Do NOT modify the tests unless "
            f"the tests themselves have bugs.\n\n"
            f"Test output:\n```\n{test_output}\n```\n\n"
            f"Fix the failing code. Be minimal — change only what's needed."
        )

        try:
            proc = subprocess.run(
                [
                    self.claude_command,
                    "--print",
                    "--dangerously-skip-permissions",
                    prompt,
                ],
                cwd=str(self.project_root),
                capture_output=True,
                text=True,
                timeout=timeout,
            )
            return proc.stdout + proc.stderr
        except FileNotFoundError:
            return "error: claude command not found"
        except subprocess.TimeoutExpired:
            return f"error: Claude fix timed out after {timeout}s"
        except Exception as e:
            return f"error: {e}"


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
        "--json",
        action="store_true",
        help="Output result as JSON",
    )
    args = parser.parse_args()

    def print_iteration(it: IterationResult) -> None:
        status = "PASS" if it.tests_failed == 0 else "FAIL"
        fix = " (fix applied)" if it.fix_applied else ""
        print(
            f"  [{it.iteration}] {status}: "
            f"{it.tests_passed} passed, {it.tests_failed} failed "
            f"({it.duration_seconds:.1f}s){fix}"
        )

    loop = VerifyLoop(
        project_root=args.project_root,
        test_command=args.test_command,
        on_iteration=None if args.json else print_iteration,
    )

    if not args.json:
        print(f"Test command: {loop.test_command}")
        print(f"Max iterations: {args.max_iterations}")
        print()

    result = loop.run(max_iterations=args.max_iterations)

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

    return 0 if result.success else 1


if __name__ == "__main__":
    sys.exit(main())
