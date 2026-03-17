"""
integration_verify.py -- Epic integration verification gate.

Implements F-0204 (ADR-001 §6, ADR-002 §8 item 5): verifies that an epic's
children work together before allowing the epic to advance to shipped.

Integration test commands are resolved from:
  1. Epic AC file `## Integration tests` section (per-epic override)
  2. STACK.md `## Integration tests` section (project-level)
  3. Skip (no tests defined → epic ships immediately)

@feature F-0204

Usage:
    # Standalone CLI
    ag auto verify-epic F-XXXX [--json]

    # Programmatic
    from auto.integration_verify import (
        load_integration_commands,
        run_integration_verify,
        get_integration_result,
    )
"""
from __future__ import annotations

import json
import re
import sys
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))
from paths import get_paths  # noqa: E402
from settings import get_setting  # noqa: E402


# ---------------------------------------------------------------------------
# Feature ID validation
# ---------------------------------------------------------------------------

from ids import FEATURE_ID_STRICT_RE as _FEATURE_ID_RE  # noqa: E402


def _validate_feature_id(feature_id: str) -> None:
    if not _FEATURE_ID_RE.match(feature_id):
        raise ValueError(
            f"Invalid feature ID: '{feature_id}'. Must match F-XXXX format."
        )


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------

@dataclass
class IntegrationResult:
    """Result of epic integration verification."""
    epic_id: str
    success: bool
    commands_run: int = 0
    skipped: bool = False       # True if no integration tests defined
    error: str = ""
    duration_seconds: float = 0.0
    tier_results: list[dict] = field(default_factory=list)

    def to_dict(self) -> dict:
        d = {
            "epic_id": self.epic_id,
            "success": self.success,
            "commands_run": self.commands_run,
            "skipped": self.skipped,
            "duration_seconds": round(self.duration_seconds, 1),
        }
        if self.error:
            d["error"] = self.error
        if self.tier_results:
            d["tier_results"] = self.tier_results
        return d


# ---------------------------------------------------------------------------
# Command resolution (AC-003)
# ---------------------------------------------------------------------------

def load_integration_commands(
    project_root: Path, epic_id: str
) -> list[str]:
    """Load integration test commands for an epic.

    Resolution order:
      1. Epic AC file ## Integration tests section
      2. STACK.md ## Integration tests section
      3. Empty list (skip)

    Args:
        project_root: Project root path.
        epic_id: Epic feature ID.

    Returns:
        List of shell commands to run. Empty = no tests defined.
    """
    _validate_feature_id(epic_id)
    paths = get_paths(project_root)

    # 1. Epic AC file override
    ac_file = paths.acceptance_dir / f"{epic_id}.md"
    if ac_file.exists():
        commands = _parse_integration_section(ac_file.read_text())
        if commands:
            return commands

    # 2. STACK.md project-level
    stack_file = paths.stack_file
    if stack_file.exists():
        commands = _parse_integration_section(stack_file.read_text())
        if commands:
            return commands

    # 3. Skip
    return []


def _parse_integration_section(content: str) -> list[str]:
    """Parse `## Integration tests` section for test commands.

    Supports:
      - `command` (backtick-wrapped)
      - plain command (after `- `)

    Format:
        ## Integration tests
        - `pytest tests/integration/`
        - `npm run test:integration`
    """
    # Find the ## Integration tests heading
    match = re.search(
        r"^##\s+Integration\s+tests\b", content, re.MULTILINE | re.IGNORECASE,
    )
    if not match:
        return []

    commands: list[str] = []
    lines = content[match.end():].split("\n")

    for line in lines:
        stripped = line.strip()
        # Stop at next heading
        if stripped.startswith("## ") or stripped.startswith("# "):
            break
        # Skip empty lines and comments
        if not stripped or stripped.startswith("<!--"):
            continue
        # Match `command` or - command
        bt_match = re.match(r"^-\s*`([^`]+)`", stripped)
        if bt_match:
            cmd = bt_match.group(1).strip()
            if cmd and not _is_placeholder(cmd):
                commands.append(cmd)
            continue
        plain_match = re.match(r"^-\s+(.+)$", stripped)
        if plain_match:
            cmd = plain_match.group(1).strip()
            if cmd and not _is_placeholder(cmd):
                commands.append(cmd)

    return commands


def _is_placeholder(cmd: str) -> bool:
    """Check if a command is a placeholder."""
    cmd = cmd.strip()
    return (
        not cmd
        or cmd.startswith("<!--")
        or cmd.lower() in ("n/a", "none", "skip")
        or ("fill" in cmd.lower() and "-->" in cmd)
    )


# ---------------------------------------------------------------------------
# Verification execution (AC-004)
# ---------------------------------------------------------------------------

def run_integration_verify(
    project_root: Path,
    epic_id: str,
    claude_command: str = "claude",
) -> IntegrationResult:
    """Run integration verification for an epic.

    Loads commands → runs each via VerifyLoop → stores artifact → returns.
    If review_integration is set, runs critical agent review of results.

    Args:
        project_root: Project root path.
        epic_id: Epic feature ID.
        claude_command: Claude CLI command.

    Returns:
        IntegrationResult with pass/fail and per-command details.
    """
    _validate_feature_id(epic_id)
    start = time.time()

    commands = load_integration_commands(project_root, epic_id)
    if not commands:
        result = IntegrationResult(
            epic_id=epic_id,
            success=True,
            skipped=True,
            duration_seconds=time.time() - start,
        )
        _store_artifact(project_root, result)
        return result

    # Run each command via VerifyLoop
    from auto.verify import VerifyLoop

    all_passed = True
    tier_results: list[dict] = []

    for i, cmd in enumerate(commands):
        loop = VerifyLoop(
            project_root=project_root,
            test_command=cmd,
            claude_command=claude_command,
        )
        verify_result = loop.run(max_iterations=3)
        tier_results.append({
            "command": cmd,
            "success": verify_result.success,
            "iterations_used": verify_result.iterations_used,
            "tests_passed": verify_result.final_tests_passed,
            "tests_failed": verify_result.final_tests_failed,
        })
        if not verify_result.success:
            all_passed = False

    result = IntegrationResult(
        epic_id=epic_id,
        success=all_passed,
        commands_run=len(commands),
        tier_results=tier_results,
        duration_seconds=time.time() - start,
    )

    _store_artifact(project_root, result)

    # Optional critical agent review (AC-008)
    if all_passed:
        _run_review_if_configured(project_root, epic_id, result, claude_command)

    return result


# ---------------------------------------------------------------------------
# Artifact storage and retrieval
# ---------------------------------------------------------------------------

def _get_artifact_path(project_root: Path, epic_id: str) -> Path:
    """Get the artifact path for an epic's integration verification."""
    paths = get_paths(project_root)
    return paths.session_dir / "integration-verify" / f"{epic_id}.json"


def _store_artifact(project_root: Path, result: IntegrationResult) -> None:
    """Store integration verification result as JSON artifact."""
    artifact_path = _get_artifact_path(project_root, result.epic_id)
    artifact_path.parent.mkdir(parents=True, exist_ok=True)
    tmp = artifact_path.with_suffix(".tmp")
    tmp.write_text(json.dumps(result.to_dict(), indent=2) + "\n")
    tmp.rename(artifact_path)


def get_integration_result(
    project_root: Path, epic_id: str
) -> Optional[IntegrationResult]:
    """Read stored integration verification artifact.

    Args:
        project_root: Project root path.
        epic_id: Epic feature ID.

    Returns:
        IntegrationResult if artifact exists, None otherwise.
    """
    _validate_feature_id(epic_id)
    artifact_path = _get_artifact_path(project_root, epic_id)
    if not artifact_path.exists():
        return None
    try:
        data = json.loads(artifact_path.read_text())
        return IntegrationResult(
            epic_id=data.get("epic_id", epic_id),
            success=data.get("success", False),
            commands_run=data.get("commands_run", 0),
            skipped=data.get("skipped", False),
            error=data.get("error", ""),
            duration_seconds=data.get("duration_seconds", 0.0),
            tier_results=data.get("tier_results", []),
        )
    except (json.JSONDecodeError, OSError):
        return None


# ---------------------------------------------------------------------------
# Review integration (AC-008)
# ---------------------------------------------------------------------------

def _run_review_if_configured(
    project_root: Path,
    epic_id: str,
    result: IntegrationResult,
    claude_command: str,
) -> None:
    """Run critical agent review if review_integration is set."""
    review_mode = get_setting(project_root, "review_integration", "skip")
    if review_mode == "skip":
        return
    if review_mode == "critical_agent":
        try:
            from auto.critical_agent import CriticalAgent
            agent = CriticalAgent(project_root, claude_command)
            verdict = agent.review(
                epic_id, "implementing", "shipped", "review_integration",
            )
            if verdict.verdict != "approved":
                result.success = False
                result.error = (
                    f"Critical agent review: {verdict.verdict} — "
                    f"{verdict.summary}"
                )
                _store_artifact(project_root, result)
        except Exception as e:
            result.error = f"Review failed: {e}"
            _store_artifact(project_root, result)
    # human mode: don't auto-proceed, result stays as-is for human review


# ---------------------------------------------------------------------------
# CLI entry point (AC-006)
# ---------------------------------------------------------------------------

def main() -> int:
    """CLI: ag auto verify-epic F-XXXX [--json]"""
    import argparse

    parser = argparse.ArgumentParser(
        description="Run integration verification for an epic"
    )
    parser.add_argument(
        "epic_id",
        help="Epic feature ID (e.g., F-0100)",
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

    if not args.json:
        print(f"Integration verification: {args.epic_id}")

    result = run_integration_verify(
        project_root=args.project_root,
        epic_id=args.epic_id,
    )

    if args.json:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        if result.skipped:
            print(f"  No integration tests defined — skipped")
        elif result.success:
            print(
                f"  PASSED: {result.commands_run} command(s) in "
                f"{result.duration_seconds:.1f}s"
            )
        else:
            print(
                f"  FAILED: {result.commands_run} command(s) in "
                f"{result.duration_seconds:.1f}s"
            )
            if result.error:
                print(f"  Error: {result.error}")
            for tr in result.tier_results:
                status = "PASS" if tr.get("success") else "FAIL"
                print(f"    [{status}] {tr.get('command', '?')}")

    return 0 if result.success else 1


if __name__ == "__main__":
    sys.exit(main())
