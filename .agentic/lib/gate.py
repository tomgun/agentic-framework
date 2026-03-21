"""
gate.py — Policy engine for hook-based enforcement.

Entry point for `ag gate <check>` commands. Called by hook adapters (Claude,
Cursor, Copilot, Gemini) and by `ag verify` for CI.

Returns JSON to stdout:
  {"decision": "allow"}
  {"decision": "deny", "reasons": ["..."]}

Exit codes:
  0 = allow (or advisory warnings only)
  1 = error (gate could not run)
  2 = deny (hook should block the action)

Usage:
  python3 -m gate stop                    # Can session stop?
  python3 -m gate stop --feature F-0001   # Explicit feature
  python3 -m gate pretool --tool Bash --input '{"command":"git commit"}'
  python3 -m gate verify                  # Full verification (all checks)
  python3 -m gate verify --feature F-0001
"""
from __future__ import annotations

import json
import os
import re
import subprocess
import sys
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Setup paths
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(_LIB_DIR))
from paths import get_paths  # noqa: E402
from settings import get_setting  # noqa: E402


# ---------------------------------------------------------------------------
# GateResult — same structure as gates.py, kept here for independence
# ---------------------------------------------------------------------------

@dataclass
class GateResult:
    """Result of a gate check."""
    decision: str  # "allow" or "deny"
    reasons: list[str] = field(default_factory=list)
    warnings: list[str] = field(default_factory=list)

    def to_json(self) -> str:
        d: dict = {"decision": self.decision}
        if self.reasons:
            d["reasons"] = self.reasons
        if self.warnings:
            d["warnings"] = self.warnings
        return json.dumps(d)

    @staticmethod
    def allow(warnings: list[str] | None = None) -> GateResult:
        return GateResult(decision="allow", warnings=warnings or [])

    @staticmethod
    def deny(reasons: list[str], warnings: list[str] | None = None) -> GateResult:
        return GateResult(decision="deny", reasons=reasons, warnings=warnings or [])

    def merge(self, other: GateResult) -> GateResult:
        merged_decision = "deny" if self.decision == "deny" or other.decision == "deny" else "allow"
        return GateResult(
            decision=merged_decision,
            reasons=self.reasons + other.reasons,
            warnings=self.warnings + other.warnings,
        )


# ---------------------------------------------------------------------------
# Active feature resolution
# ---------------------------------------------------------------------------

def resolve_active_feature(project_root: Path) -> Optional[str]:
    """Determine which feature is currently being worked on.

    Resolution order:
    1. AGENTS.json — WIP entry for current session/agent
    2. STATUS.md — current focus line
    3. BACKLOG.json — position 0
    4. None — discovery mode
    """
    paths = get_paths(project_root)

    # 1. AGENTS.json
    feature = _feature_from_agents_json(paths)
    if feature:
        return feature

    # 2. STATUS.md
    feature = _feature_from_status(paths)
    if feature:
        return feature

    # 3. BACKLOG.json
    feature = _feature_from_backlog(paths)
    if feature:
        return feature

    return None


def _feature_from_agents_json(paths) -> Optional[str]:
    """Extract active feature from AGENTS.json."""
    agents_file = paths.agents_json
    if not agents_file.exists():
        return None
    try:
        data = json.loads(agents_file.read_text())
        agents = data if isinstance(data, list) else data.get("agents", [])
        pid = os.getppid()
        # Look for our session's agent entry
        for agent in agents:
            if agent.get("pid") == pid and agent.get("feature"):
                return agent["feature"]
        # Fall back to any active agent with a feature
        for agent in agents:
            if agent.get("status") == "active" and agent.get("feature"):
                return agent["feature"]
    except (json.JSONDecodeError, OSError):
        pass
    return None


def _feature_from_status(paths) -> Optional[str]:
    """Extract feature ID from STATUS.md focus/session-state line."""
    status_file = paths.status_file
    if not status_file.exists():
        return None
    try:
        content = status_file.read_text()
        # Search focus/session-state lines first, then fall back to any F-XXXX
        for line in content.splitlines():
            lower = line.lower()
            if 'focus' in lower or 'session state' in lower or 'current' in lower:
                m = re.search(r'F-\d{4,}', line)
                if m:
                    return m.group(0)
        # Fall back to first F-XXXX anywhere
        m = re.search(r'F-\d{4,}', content)
        if m:
            return m.group(0)
    except OSError:
        pass
    return None


def _feature_from_backlog(paths) -> Optional[str]:
    """Get position-0 feature from BACKLOG.json."""
    backlog_file = paths.backlog_file
    if not backlog_file.exists():
        return None
    try:
        data = json.loads(backlog_file.read_text())
        items = data if isinstance(data, list) else data.get("items", [])
        if items:
            first = items[0]
            fid = first.get("id") or first.get("feature_id") or ""
            if re.match(r'F-\d{4,}', fid):
                return fid
    except (json.JSONDecodeError, OSError):
        pass
    return None


# ---------------------------------------------------------------------------
# Gate checks
# ---------------------------------------------------------------------------

def check_feature_has_spec(feature_id: str, project_root: Path) -> GateResult:
    """Feature must exist in FEATURES.md with a description."""
    paths = get_paths(project_root)
    features_file = paths.features_file
    if not features_file.exists():
        return GateResult.allow(["No FEATURES.md found — skipping spec check"])

    content = features_file.read_text()
    pattern = rf"## {re.escape(feature_id)}\b"
    if not re.search(pattern, content):
        return GateResult.deny([f"{feature_id} not found in FEATURES.md"])

    return GateResult.allow()


def check_feature_has_ac(feature_id: str, project_root: Path) -> GateResult:
    """Acceptance criteria file must exist with at least one AC line."""
    paths = get_paths(project_root)
    ac_file = paths.acceptance_dir / f"{feature_id}.md"

    if not ac_file.exists():
        return GateResult.deny(
            [f"No acceptance criteria: spec/acceptance/{feature_id}.md"]
        )

    content = ac_file.read_text()
    ac_pattern = re.compile(r"(- \[[ x]\]\s*\*?\*?AC-|### AC-)", re.IGNORECASE)
    if not ac_pattern.search(content):
        return GateResult.deny(
            [f"No AC lines found in spec/acceptance/{feature_id}.md"]
        )

    return GateResult.allow()


def check_feature_has_tests(feature_id: str, project_root: Path) -> GateResult:
    """At least one test file must reference the feature ID."""
    test_dirs = [
        project_root / "tests",
        project_root / "test",
    ]

    fid_lower = feature_id.lower()
    for test_dir in test_dirs:
        if not test_dir.is_dir():
            continue
        for test_file in test_dir.rglob("*"):
            if not test_file.is_file():
                continue
            if test_file.suffix not in (".py", ".js", ".ts", ".sh", ".rb", ".go", ".rs"):
                continue
            try:
                text = test_file.read_text(errors="ignore")
                if fid_lower in text.lower():
                    return GateResult.allow()
            except OSError:
                continue

    return GateResult.deny([f"No test files reference {feature_id}"])


def check_verification_passes(feature_id: str, project_root: Path) -> GateResult:
    """Run verification commands from the AC file directly.

    Reads ## Verification section from spec/acceptance/F-XXXX.md and
    executes any **Automated** commands found there.
    """
    paths = get_paths(project_root)
    ac_file = paths.acceptance_dir / f"{feature_id}.md"

    if not ac_file.exists():
        return GateResult.allow([f"No AC file for {feature_id} — skipping verification"])

    try:
        content = ac_file.read_text()
    except OSError:
        return GateResult.allow([f"Could not read AC file for {feature_id}"])

    # Extract automated verification commands from ## Verification section
    commands = []
    in_verification = False
    for line in content.splitlines():
        if line.startswith("## Verification"):
            in_verification = True
            continue
        if in_verification and line.startswith("## "):
            break
        if in_verification and "**Automated**" in line:
            # Extract command between backticks
            m = re.search(r'`([^`]+)`', line)
            if m:
                commands.append(m.group(1))

    if not commands:
        return GateResult.allow([f"No automated verification commands in {feature_id} AC"])

    failures = []
    for cmd in commands:
        try:
            proc = subprocess.run(
                ["bash", "-c", cmd],
                cwd=str(project_root),
                capture_output=True,
                text=True,
                timeout=120,
            )
            if proc.returncode != 0:
                output = proc.stdout.strip() or proc.stderr.strip()
                summary = output.splitlines()[-3:] if output else ["(no output)"]
                failures.append(f"'{cmd}' failed: {' '.join(summary)}")
        except subprocess.TimeoutExpired:
            failures.append(f"'{cmd}' timed out")
        except OSError as e:
            failures.append(f"'{cmd}' error: {e}")

    if failures:
        return GateResult.deny(failures)
    return GateResult.allow()


def check_uncommitted_changes(project_root: Path) -> GateResult:
    """Check for uncommitted changes (advisory)."""
    warnings = []
    try:
        proc = subprocess.run(
            ["git", "status", "--porcelain"],
            cwd=str(project_root),
            capture_output=True,
            text=True,
            timeout=10,
        )
        count = len([l for l in proc.stdout.strip().splitlines() if l.strip()])
        if count > 0:
            warnings.append(f"{count} uncommitted change(s)")
    except (subprocess.TimeoutExpired, OSError):
        warnings.append("Could not check git status")

    return GateResult.allow(warnings)


def check_journal_updated(project_root: Path) -> GateResult:
    """Check if journal was updated recently (advisory)."""
    paths = get_paths(project_root)
    journal_file = paths.journal_file
    warnings = []

    if journal_file.exists():
        import time
        try:
            age = time.time() - journal_file.stat().st_mtime
            if age > 3600:  # 1 hour
                warnings.append("JOURNAL.md not updated in this session")
        except OSError:
            pass
    return GateResult.allow(warnings)


def check_status_exists(project_root: Path) -> GateResult:
    """Check STATUS.md exists (advisory)."""
    paths = get_paths(project_root)
    if not paths.status_file.exists():
        return GateResult.allow(["No STATUS.md found"])
    return GateResult.allow()


# ---------------------------------------------------------------------------
# Composite gate checks
# ---------------------------------------------------------------------------

def gate_stop(feature_id: Optional[str], project_root: Path) -> GateResult:
    """Can the session stop? Checks verification status.

    For formal/autonomous_formal profiles: blocks if active feature
    hasn't passed verification.
    For discovery: advisory only.
    """
    profile = get_setting(project_root, "profile", "discovery")
    is_formal = profile in ("formal", "autonomous_formal")

    result = GateResult.allow()

    # Advisory checks (all profiles)
    result = result.merge(check_uncommitted_changes(project_root))
    result = result.merge(check_journal_updated(project_root))
    result = result.merge(check_status_exists(project_root))

    # Feature-specific checks
    if feature_id:
        # Check if feature has spec + AC + tests
        spec_result = check_feature_has_spec(feature_id, project_root)
        ac_result = check_feature_has_ac(feature_id, project_root)
        test_result = check_feature_has_tests(feature_id, project_root)

        if is_formal:
            # In formal mode, these are hard blocks
            result = result.merge(spec_result)
            result = result.merge(ac_result)
            result = result.merge(test_result)
            # Note: we do NOT run check_verification_passes() here because
            # the Stop hook has a 5s timeout — verification commands can take
            # minutes. Use `ag verify F-XXXX` or `ag gate verify` for full checks.
        else:
            # In discovery mode, add as warnings
            for r in [spec_result, ac_result, test_result]:
                if r.decision == "deny":
                    result.warnings.extend(r.reasons)

    return result


def gate_pretool(feature_id: Optional[str], project_root: Path,
                  tool: str, tool_input: Optional[str] = None) -> GateResult:
    """PreToolUse gate — block dangerous operations and enforce spec-first.

    Checks:
    1. Block git commit/push without passing verification (formal mode)
    2. Block destructive git ops (reset --hard, checkout --, stash, clean)
    3. Block code edits without spec (formal mode)
    """
    tool = normalize_tool_name(tool)
    profile = get_setting(project_root, "profile", "discovery")
    is_formal = profile in ("formal", "autonomous_formal")

    # Parse tool input JSON
    input_data = {}
    if tool_input:
        try:
            input_data = json.loads(tool_input)
        except json.JSONDecodeError:
            pass

    # --- Bash/Shell tool checks ---
    if tool == "Bash":
        command = input_data.get("command", "")

        # Block destructive git operations
        destructive_patterns = [
            (r'git\s+reset\s+--hard', "git reset --hard destroys uncommitted work"),
            (r'git\s+checkout\s+--\s+', "git checkout -- destroys uncommitted changes"),
            (r'git\s+restore\s+(?!--staged)', "git restore destroys uncommitted changes (use --staged for safe unstaging)"),
            (r'git\s+clean\s+-[fd]', "git clean removes untracked files"),
            (r'git\s+stash\b', "git stash risks data loss in multi-agent contexts"),
            (r'git\s+push\s+.*(-f|--force)\b', "git push --force can destroy remote history"),
        ]
        for pattern, reason in destructive_patterns:
            if re.search(pattern, command):
                return GateResult.deny(
                    [f"Destructive git operation blocked: {reason}"],
                    ["Use worktrees or commit before switching branches"]
                )

        # Block git commit without verification (formal mode)
        if is_formal and re.search(r'git\s+commit\b', command):
            if feature_id:
                spec_check = check_feature_has_spec(feature_id, project_root)
                ac_check = check_feature_has_ac(feature_id, project_root)
                test_check = check_feature_has_tests(feature_id, project_root)
                combined = spec_check.merge(ac_check).merge(test_check)
                if combined.decision == "deny":
                    combined.reasons.insert(0,
                        f"git commit blocked — {feature_id} missing required artifacts")
                    return combined

        # Block git push without verification (formal mode)
        if is_formal and re.search(r'git\s+push\b', command):
            if feature_id:
                spec_check = check_feature_has_spec(feature_id, project_root)
                ac_check = check_feature_has_ac(feature_id, project_root)
                if spec_check.decision == "deny" or ac_check.decision == "deny":
                    return GateResult.deny(
                        [f"git push blocked — {feature_id} missing spec or acceptance criteria"]
                    )

    # --- Write/Edit tool checks (formal mode: code must have spec) ---
    if tool in ("Write", "Edit", "MultiEdit") and is_formal and feature_id:
        file_path = input_data.get("file_path", "")

        # Allow edits to framework/config/state files
        safe_patterns = [
            r'\.agentic/',
            r'tests?/',
            r'docs?/',
            r'\.md$', r'\.json$', r'\.yaml$', r'\.yml$',
            r'\.sh$', r'\.toml$', r'\.cfg$', r'\.ini$',
        ]
        is_safe = any(re.search(p, file_path) for p in safe_patterns)

        if not is_safe:
            # Check that spec + AC exist before allowing code edits
            spec_check = check_feature_has_spec(feature_id, project_root)
            ac_check = check_feature_has_ac(feature_id, project_root)
            combined = spec_check.merge(ac_check)
            if combined.decision == "deny":
                combined.reasons.insert(0,
                    f"Code edit blocked — {feature_id} needs spec and acceptance criteria first")
                return combined

    return GateResult.allow()


def gate_verify(feature_id: Optional[str], project_root: Path) -> GateResult:
    """Full verification — all gate checks. Used by CI and `ag verify`."""
    if not feature_id:
        return GateResult.deny(["No feature ID provided for verification"])

    result = GateResult.allow()
    result = result.merge(check_feature_has_spec(feature_id, project_root))
    result = result.merge(check_feature_has_ac(feature_id, project_root))
    result = result.merge(check_feature_has_tests(feature_id, project_root))

    # Only run verification commands if AC file exists
    if result.decision == "allow":
        result = result.merge(check_verification_passes(feature_id, project_root))

    return result


# ---------------------------------------------------------------------------
# Tool name normalization (for PreToolUse)
# ---------------------------------------------------------------------------

TOOL_ALIASES = {
    "Shell": "Bash",
    "shell": "Bash",
    "terminal": "Bash",
    "Terminal": "Bash",
    "ReadFile": "Read",
    "read_file": "Read",
    "WriteFile": "Write",
    "write_file": "Write",
    "EditFile": "Edit",
    "edit_file": "Edit",
}


def normalize_tool_name(tool: str) -> str:
    """Normalize tool names across different AI platforms."""
    return TOOL_ALIASES.get(tool, tool)


# ---------------------------------------------------------------------------
# CLI entry point
# ---------------------------------------------------------------------------

def main():
    import argparse

    parser = argparse.ArgumentParser(description="ag gate — policy engine")
    parser.add_argument("check", choices=["stop", "pretool", "verify"],
                       help="Which gate check to run")
    parser.add_argument("--feature", "-f", help="Feature ID (auto-resolved if omitted)")
    parser.add_argument("--tool", "-t", help="Tool name (for pretool check)")
    parser.add_argument("--input", "-i", help="Tool input JSON (for pretool check)")
    parser.add_argument("--project-root", "-p", default=".",
                       help="Project root directory")

    args = parser.parse_args()
    project_root = Path(args.project_root).resolve()

    # Resolve feature if not provided
    feature_id = args.feature or resolve_active_feature(project_root)

    try:
        if args.check == "stop":
            result = gate_stop(feature_id, project_root)
        elif args.check == "verify":
            result = gate_verify(feature_id, project_root)
        elif args.check == "pretool":
            tool = normalize_tool_name(args.tool or "unknown")
            result = gate_pretool(feature_id, project_root, tool, args.input)
        else:
            result = GateResult.deny([f"Unknown check: {args.check}"])
    except Exception as e:
        # Fail-closed: any error = deny
        result = GateResult.deny([f"Gate error: {e}"])

    print(result.to_json())
    sys.exit(2 if result.decision == "deny" else 0)


if __name__ == "__main__":
    main()
