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
  python3 -m gate stop --feature F-001   # Explicit feature
  python3 -m gate pretool --tool Bash --input '{"command":"git commit"}'
  python3 -m gate verify                  # Full verification (all checks)
  python3 -m gate verify --feature F-001
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
import btrace  # noqa: E402
from ids import FEATURE_ID_RE, is_valid_feature_id  # noqa: E402


# ---------------------------------------------------------------------------
# GateResult — hooks-first gate policy engine.
# Uses decision="allow"|"deny" for direct JSON serialization to hook responses.
# auto/gates.py (state machine transitions) uses GateResult(allowed=bool).
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
                m = FEATURE_ID_RE.search(line)
                if m:
                    return m.group(0)
        # Fall back to first F-XXXX anywhere
        m = FEATURE_ID_RE.search(content)
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
            if is_valid_feature_id(fid):
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
    """Contract or acceptance criteria file must exist with at least one AC line."""
    paths = get_paths(project_root)
    contract_file = paths.contracts_dir / f"{feature_id}.yaml"
    ac_file = paths.acceptance_dir / f"{feature_id}.md"

    # Check contract YAML first
    if contract_file.exists():
        try:
            from contracts import load_contract
            contract = load_contract(contract_file)
            if contract.assertions:
                return GateResult.allow()
            return GateResult.deny(
                [f"Contract spec/contracts/{feature_id}.yaml has no assertions"]
            )
        except Exception as e:
            return GateResult.deny(
                [f"Failed to load contract spec/contracts/{feature_id}.yaml: {e}"]
            )

    # Fall back to legacy acceptance markdown
    if not ac_file.exists():
        return GateResult.deny(
            [f"No contract or acceptance criteria: spec/contracts/{feature_id}.yaml or spec/acceptance/{feature_id}.md"]
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


def check_any_feature_implementing(project_root: Path) -> bool:
    """Check if at least one feature is in 'implementing' or later state.

    Returns True if any feature has progressed past 'planned'.
    Used by F-0251 to enforce spec lifecycle in formal modes.
    """
    paths = get_paths(project_root)
    features_file = paths.features_file
    if not features_file.exists():
        return True  # No FEATURES.md = no enforcement

    content = features_file.read_text()
    # States that indicate implementation has started
    active_states = {
        "specced", "criteria_set", "tests_written", "implementing",
        "verified", "documented", "committed", "shipped",
    }
    # Find all **Status**: <state> lines
    for match in re.finditer(r"\*\*Status\*\*:\s*(\w+)", content):
        status = match.group(1).lower()
        if status in active_states:
            return True

    return False



def check_verification_passes(feature_id: str, project_root: Path) -> GateResult:
    """Run verification commands from the contract/AC file directly.

    Reads ## Verification section from contract YAML or spec/acceptance/F-XXXX.md
    and executes any **Automated** commands found there.
    """
    paths = get_paths(project_root)
    contract_file = paths.contracts_dir / f"{feature_id}.yaml"
    ac_file = paths.acceptance_dir / f"{feature_id}.md"

    # Determine which file to read verification commands from
    verify_file = None
    if contract_file.exists():
        verify_file = contract_file
    elif ac_file.exists():
        verify_file = ac_file

    if verify_file is None:
        return GateResult.allow([f"No contract/AC file for {feature_id} — skipping verification"])

    try:
        content = verify_file.read_text()
    except OSError:
        return GateResult.allow([f"Could not read contract/AC file for {feature_id}"])

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


def check_pending_plan_review(project_root: Path) -> GateResult:
    """Block if any saved plan file has **Status**: DRAFT (pending dialectical review).

    Applies when plan_review_enabled: yes. DRAFT is injected mechanically by
    on-plan-mode-exit.sh — so DRAFT always means review is pending. Plans must be
    set to APPROVED (by the Critic+Advocate review process) before stopping.
    """
    plan_review_enabled = get_setting(project_root, "plan_review_enabled", "no")
    if plan_review_enabled != "yes":
        return GateResult.allow()

    plans_dir = project_root / ".agentic" / "journal" / "plans"
    if not plans_dir.exists():
        return GateResult.allow()

    draft_plans = []
    for plan_file in sorted(plans_dir.glob("*-plan.md")):
        try:
            content = plan_file.read_text()
            # Only explicit **Status**: DRAFT triggers blocking.
            # Legacy plans (no status line) are treated as implicitly approved —
            # they predate the mechanism. on-plan-mode-exit.sh mechanically injects
            # DRAFT into all new plans, so this only misses truly manual saves.
            if re.search(r'\*\*Status\*\*:\s*DRAFT', content):
                draft_plans.append(plan_file.name)
        except OSError:
            continue

    if draft_plans:
        return GateResult.deny([
            f"REQUIRED: plan review pending ({', '.join(draft_plans)}) — "
            "run Critic + Advocate review, set **Status**: APPROVED before stopping. "
            "If this plan is abandoned, mark it **Status**: REJECTED instead."
        ])
    return GateResult.allow()


def check_plan_review_evidence(project_root: Path) -> GateResult:
    """Block if a plan is marked APPROVED but no review evidence exists.

    Prevents agents from fake-approving plans by editing DRAFT→APPROVED
    without actually spawning Critic+Advocate reviewers. Evidence is
    a review.md file in .agentic/work/{FID}/ with structural markers.

    Applies when plan_review_enabled: yes. Returns allow if no plans
    are APPROVED (nothing to validate) or if evidence exists.
    """
    plan_review_enabled = get_setting(project_root, "plan_review_enabled", "no")
    if plan_review_enabled != "yes":
        return GateResult.allow()

    plans_dir = project_root / ".agentic" / "journal" / "plans"
    if not plans_dir.exists():
        return GateResult.allow()

    # Check if any review-pending sentinel exists (created by on-plan-mode-exit.sh)
    session_dir = project_root / ".agentic" / "session"
    pending_sentinels = list(session_dir.glob("review-pending-*")) if session_dir.exists() else []
    if not pending_sentinels:
        return GateResult.allow()

    # For each pending review, check if evidence now exists
    missing_evidence = []
    for sentinel in pending_sentinels:
        fid = sentinel.name.replace("review-pending-", "")
        if not fid or not is_valid_feature_id(fid):
            continue

        # Check for review evidence in work directory
        work_dir = project_root / ".agentic" / "work" / fid
        review_file = work_dir / "review.md"
        if review_file.exists():
            try:
                content = review_file.read_text()
                # Look for structural markers that indicate a real review.
                # Keep in sync with implement.sh T-0097 evidence gate — same markers + threshold.
                markers = ["Critic", "Advocate", "Synthesis", "Convergence",
                           "Analysis", "Findings", "Recommendation"]
                found = sum(1 for m in markers if m.lower() in content.lower())
                if found >= 2:
                    # Evidence found — remove sentinel
                    try:
                        sentinel.unlink()
                    except OSError:
                        pass
                    continue
            except OSError:
                pass

        missing_evidence.append(fid)

    if missing_evidence:
        return GateResult.deny([
            f"Plan review evidence missing for {', '.join(missing_evidence)}. "
            "Spawn Critic + Advocate agents to review the plan, save findings "
            "to .agentic/work/{FID}/review.md, then set plan **Status**: APPROVED."
        ])
    return GateResult.allow()


def check_merge_without_done(project_root: Path) -> GateResult:
    """Block if a recent feature branch merge has not been marked shipped.

    Detects the case where `gh pr merge` was used directly (bypassing `ag merge`)
    and the completing-work workflow was never run. Only runs when FEATURES.md exists.
    """
    paths = get_paths(project_root)
    features_file = paths.features_file
    if not features_file.exists():
        return GateResult.allow()  # No FEATURES.md = not a structured project

    try:
        # Look for recent merge commits referencing feature branches.
        # --format=%s %D gives subject + ref names for merge commits.
        proc = subprocess.run(
            ["git", "log", "--merges", "--oneline", "-10",
             "--format=%s %D"],
            cwd=str(project_root),
            capture_output=True, text=True, timeout=10,
        )
        if proc.returncode != 0:
            return GateResult.allow()

        features_content = features_file.read_text()
        for line in proc.stdout.strip().splitlines():
            m = FEATURE_ID_RE.search(line)
            if not m:
                continue
            feature_id = m.group(0)

            # Check if feature exists in FEATURES.md and its status
            pattern = rf"## {re.escape(feature_id)}\b.*?(?=\n## |\Z)"
            section = re.search(pattern, features_content, re.DOTALL)
            if not section:
                continue  # Not in FEATURES.md — consolidated or removed, skip
            if re.search(r'\*\*Status\*\*:\s*shipped', section.group()):
                continue  # Already marked shipped — fine

            # Feature IS in FEATURES.md but not marked shipped after merge
            return GateResult.deny([
                f"REQUIRED: run `ag done {feature_id}` — "
                f"feature branch merged but {feature_id} not marked shipped in FEATURES.md"
            ])

        return GateResult.allow()
    except (subprocess.TimeoutExpired, OSError):
        return GateResult.allow()


def check_feature_branch_without_pr(project_root: Path) -> GateResult:
    """Block if on a feature branch with commits ahead of origin and no open PR.

    Catches the case where work was committed to a feature branch but a PR was
    never created. Requires `gh` CLI to be installed and authenticated.
    """
    try:
        # Get current branch name
        proc = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            cwd=str(project_root),
            capture_output=True, text=True, timeout=10,
        )
        if proc.returncode != 0:
            return GateResult.allow()
        branch = proc.stdout.strip()

        # Only check on non-trunk branches
        if branch in ("main", "master", "develop", "HEAD"):
            return GateResult.allow()

        # Check if branch has commits ahead of its origin counterpart
        proc = subprocess.run(
            ["git", "rev-list", f"origin/{branch}..HEAD", "--count"],
            cwd=str(project_root),
            capture_output=True, text=True, timeout=10,
        )
        if proc.returncode != 0:
            return GateResult.allow()  # origin branch may not exist yet (pre-push)

        ahead_count = int(proc.stdout.strip() or "0")
        if ahead_count == 0:
            return GateResult.allow()  # Already pushed or in sync

        # Check for an open PR using gh CLI
        proc = subprocess.run(
            ["gh", "pr", "list", "--head", branch, "--state", "open",
             "--json", "number"],
            cwd=str(project_root),
            capture_output=True, text=True, timeout=15,
        )
        if proc.returncode != 0:
            return GateResult.allow()  # gh not available or not authenticated

        try:
            prs = json.loads(proc.stdout)
        except json.JSONDecodeError:
            return GateResult.allow()

        if not prs:
            return GateResult.deny([
                f"REQUIRED: create PR before stopping — branch '{branch}' has "
                f"{ahead_count} commit(s) pushed to origin with no open PR. "
                "Run: gh pr create"
            ])

        return GateResult.allow()
    except (subprocess.TimeoutExpired, OSError):
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

    btrace.emit(project_root, "gate", "stop_enter", {
        "feature": feature_id or "",
        "profile": profile,
    })

    result = GateResult.allow()

    # Advisory checks (all profiles)
    result = result.merge(check_uncommitted_changes(project_root))
    result = result.merge(check_journal_updated(project_root))
    result = result.merge(check_status_exists(project_root))

    # A1: Block if any saved plan is still DRAFT (pending dialectical review).
    # Applies whenever plan_review_enabled: yes, regardless of profile.
    result = result.merge(check_pending_plan_review(project_root))

    # A1b: Block if plan marked APPROVED without review evidence.
    # Prevents fake-approval by editing DRAFT→APPROVED without reviewers.
    result = result.merge(check_plan_review_evidence(project_root))

    # A2: Block if a feature branch was merged but ag done was never run.
    # Only runs when FEATURES.md exists (structured projects).
    result = result.merge(check_merge_without_done(project_root))

    # A3: Block if on a feature branch with commits ahead of origin but no PR.
    # Requires gh CLI; gracefully skips if not available.
    result = result.merge(check_feature_branch_without_pr(project_root))

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

    btrace.emit(project_root, "gate", "stop_result", {
        "decision": result.decision,
        "reasons": result.reasons[:3],
        "warnings_count": len(result.warnings),
    })

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

    file_path_summary = input_data.get("file_path", input_data.get("command", ""))[:80]
    btrace.emit(project_root, "gate", "pretool_enter", {
        "tool": tool,
        "profile": profile,
        "feature": feature_id or "",
        "input_summary": file_path_summary,
    })

    def _pretool_deny(result: GateResult) -> GateResult:
        """Emit btrace event before returning a deny result."""
        btrace.emit(project_root, "gate", "pretool_result", {
            "decision": "deny",
            "tool": tool,
            "reasons": result.reasons[:3],
        })
        return result

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
                return _pretool_deny(GateResult.deny(
                    [f"Destructive git operation blocked: {reason}"],
                    ["Use worktrees or commit before switching branches"]
                ))

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
                    return _pretool_deny(combined)

        # Block git push without verification (formal mode)
        if is_formal and re.search(r'git\s+push\b', command):
            if feature_id:
                spec_check = check_feature_has_spec(feature_id, project_root)
                ac_check = check_feature_has_ac(feature_id, project_root)
                if spec_check.decision == "deny" or ac_check.decision == "deny":
                    return _pretool_deny(GateResult.deny(
                        [f"git push blocked — {feature_id} missing spec or acceptance criteria"]
                    ))

    # --- Write/Edit tool checks ---
    if tool in ("Write", "Edit", "MultiEdit") and is_formal:
        file_path = input_data.get("file_path", "")

        # Allow edits to framework/config/state files (always safe)
        safe_patterns = [
            r'\.agentic/',
            r'tests?/',
            r'docs?/',
            r'\.md$', r'\.json$', r'\.yaml$', r'\.yml$',
            r'\.sh$', r'\.toml$', r'\.cfg$', r'\.ini$',
        ]
        is_safe = any(re.search(p, file_path) for p in safe_patterns)

        if not is_safe:
            # Change 1: Block code edits when DRAFT plan exists (pre-edit enforcement).
            # Previously only detected AFTER the edit via on-code-edit.sh PostToolUse.
            # Now denied BEFORE the edit — agent cannot write code with unapproved plan.
            draft_check = check_pending_plan_review(project_root)
            if draft_check.decision == "deny":
                draft_check.reasons.insert(0,
                    "Code edit blocked — unapproved DRAFT plan exists. "
                    "Run the convergence loop (Critic + Advocate) and set plan "
                    "status to APPROVED before writing code.")
                return _pretool_deny(draft_check)

            # Change 4 + T-0097: Block code edits when plan is APPROVED without review evidence.
            # Prevents fake-approval. Blocking for ALL profiles when plan_review_enabled: yes.
            evidence_check = check_plan_review_evidence(project_root)
            if evidence_check.decision == "deny":
                return _pretool_deny(evidence_check)

            # F-0300 R1: Block code writes when no active work item in deferred-git mode
            # With git_mode=deferred, pre-commit gates don't fire, so this is the
            # only enforcement point. Agents must use `ag implement F-XXXX` to track work.
            git_mode = get_setting(project_root, "git_mode", "active")
            if not feature_id and git_mode != "active":
                enforcement = get_setting(project_root, "state_enforcement", "off")
                msg = (
                    "Code edit blocked — no active work item. "
                    "With git_mode=deferred, pre-commit gates are disabled. "
                    "Use `ag start F-XXXX` or `ag auto task F-XXXX` to begin tracked work."
                )
                if enforcement == "blocking":
                    return _pretool_deny(GateResult.deny([msg]))
                else:
                    return GateResult.allow([msg])

            # F-0251: Block source code edits when ALL features are still "planned"
            # In formal modes, at least one feature must be in "implementing" or later
            # before source code can be written. This enforces the spec lifecycle.
            if not check_any_feature_implementing(project_root):
                enforcement = get_setting(project_root, "state_enforcement", "off")
                msg = (
                    "Code edit blocked — no feature is in implementation state. "
                    "All features are still 'planned'. In formal mode, run "
                    "`ag implement F-XXXX` to start implementing a feature first. "
                    "This ensures specs and acceptance criteria are created systematically."
                )
                if enforcement == "blocking":
                    return _pretool_deny(GateResult.deny([msg]))
                else:
                    # Advisory: warn but allow
                    return GateResult.allow([msg])

            # Existing check: feature-specific spec + AC enforcement
            if feature_id:
                spec_check = check_feature_has_spec(feature_id, project_root)
                ac_check = check_feature_has_ac(feature_id, project_root)
                combined = spec_check.merge(ac_check)
                if combined.decision == "deny":
                    combined.reasons.insert(0,
                        f"Code edit blocked — {feature_id} needs spec and acceptance criteria first")
                    return _pretool_deny(combined)

    # --- TDD enforcement: block source edits without RED phase checkpoint ---
    # When development_mode: tdd, agents must write a failing test (RED) before
    # editing source code. Checks AGENTS.json for active feature progress entries.
    if tool in ("Write", "Edit", "MultiEdit"):
        dev_mode = get_setting(project_root, "development_mode", "standard")
        if dev_mode == "tdd":
            file_path = input_data.get("file_path", "")
            # Only gate source files — tests, docs, config, framework are always allowed
            tdd_safe = [
                r'tests?/', r'_test\.', r'\.test\.', r'\.spec\.', r'test_',
                r'\.agentic/', r'docs?/', r'\.claude/',
                r'\.md$', r'\.json$', r'\.yaml$', r'\.yml$',
                r'\.sh$', r'\.toml$', r'\.cfg$', r'\.ini$', r'\.lock$',
                r'Makefile$', r'Dockerfile', r'\.gitignore$',
            ]
            is_tdd_safe = any(re.search(p, file_path) for p in tdd_safe)
            if not is_tdd_safe:
                # Check AGENTS.json for RED phase checkpoint
                paths = get_paths(project_root)
                has_red = False
                try:
                    if paths.agents_json.exists():
                        import json as _json
                        items = _json.loads(paths.agents_json.read_text())
                        for item in items:
                            if (item.get("type") != "session"
                                    and item.get("status") in ("active", "created")):
                                for entry in item.get("progress", []):
                                    if isinstance(entry, str) and entry.startswith("RED:"):
                                        has_red = True
                                        break
                            if has_red:
                                break
                except Exception:
                    has_red = True  # fail-open on read errors
                if not has_red:
                    msg = (
                        "TDD mode: write a failing test FIRST. "
                        "Source code edits are blocked until a RED phase checkpoint exists. "
                        "Write your test, then run: "
                        "bash .agentic/lib/tools/wip.sh checkpoint --phase RED \"test for [behavior] fails\""
                    )
                    btrace.emit(project_root, "gate", "tdd_block", {
                        "file": file_path[:80], "reason": "no_red_phase",
                    })
                    return _pretool_deny(GateResult.deny([msg]))

    # --- Defense-in-depth: duplicate git pre-commit checks at edit time ---
    # These checks mirror pre-commit-check.sh so enforcement works even without
    # git hooks (git_mode: deferred/none). See gap analysis in F-0250 plan.

    if tool in ("Write", "Edit", "MultiEdit"):
        file_path = input_data.get("file_path", "")
        paths = get_paths(project_root)

        # Check 14 mirror: Shipped spec protection — editing shipped AC/contract needs migration
        if is_formal and (re.search(r'spec/acceptance/(F|NFR)-\d+\.md$', file_path)
                          or re.search(r'spec/contracts/(F|NFR)-\d+\.yaml$', file_path)):
            fid_match = re.search(r'((?:F|NFR)-\d+)\.(?:md|yaml)$', file_path)
            if fid_match:
                fid = fid_match.group(1)
                features_file = paths.features_file
                if features_file.exists():
                    content = features_file.read_text()
                    # Check if this feature is shipped
                    pattern = rf"## {re.escape(fid)}\b.*?(?=\n## |\Z)"
                    section = re.search(pattern, content, re.DOTALL)
                    if section and re.search(r"\*\*Status\*\*:\s*shipped", section.group()):
                        # Change 2: Escalate shipped-spec editing to blocking in formal mode.
                        # Previously advisory (allowed with warning). Now respects state_enforcement.
                        msg = (
                            f"Editing shipped feature {fid} acceptance criteria blocked. "
                            f"Create a migration first: "
                            f"bash .agentic/lib/tools/migration.sh create 'Update {fid}...'"
                        )
                        enforcement = get_setting(project_root, "state_enforcement", "off")
                        if enforcement == "blocking":
                            return _pretool_deny(GateResult.deny([msg]))
                        return GateResult.allow([msg])

        # Check 7 mirror: Code file length limit (Write tool only — Edit sends
        # old_string/new_string, not full content; git pre-commit catches at commit time)
        if is_formal and not re.search(r'\.(md|json|yaml|yml|sh|toml|cfg|ini)$', file_path):
            max_length = int(get_setting(project_root, "max_code_file_length", "500"))
            new_content = input_data.get("content", "")
            if new_content:
                line_count = new_content.count('\n') + 1
                if line_count > max_length:
                    return GateResult.allow([
                        f"File will be {line_count} lines (limit: {max_length}). "
                        f"Consider splitting into smaller modules."
                    ])

        # Check 16 mirror: Shipped status downgrade protection
        if is_formal and file_path.endswith("FEATURES.md"):
            old_string = input_data.get("old_string", "")
            new_string = input_data.get("new_string", "")
            if old_string and new_string:
                # Match specifically the **Status**: shipped pattern, not incidental "shipped" in text
                if re.search(r"\*\*Status\*\*:\s*shipped", old_string) and \
                   not re.search(r"\*\*Status\*\*:\s*shipped", new_string):
                    return _pretool_deny(GateResult.deny([
                        "Shipped feature status downgrade blocked. "
                        "Create a migration first: bash .agentic/lib/tools/migration.sh create 'Deprecate...'"
                    ]))

    btrace.emit(project_root, "gate", "pretool_result", {
        "decision": "allow",
        "tool": tool,
    })
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
    parser.add_argument("check", choices=["stop", "pretool", "verify", "resolve", "check-artifacts", "prompt-context"],
                       help="Which gate check to run")
    parser.add_argument("--feature", "-f", help="Feature ID (auto-resolved if omitted)")
    parser.add_argument("--tool", "-t", help="Tool name (for pretool check)")
    parser.add_argument("--input", "-i", help="Tool input JSON (for pretool check)")
    parser.add_argument("--project-root", "-p", default=".",
                       help="Project root directory")

    args = parser.parse_args()
    project_root = Path(args.project_root).resolve()

    # "resolve" just prints the active feature ID (no gate check)
    if args.check == "resolve":
        feature_id = args.feature or resolve_active_feature(project_root)
        print(feature_id or "")
        sys.exit(0)

    # "check-artifacts" prints advisory artifact status for active feature
    if args.check == "check-artifacts":
        feature_id = args.feature or resolve_active_feature(project_root)
        if not feature_id:
            sys.exit(0)
        spec = check_feature_has_spec(feature_id, project_root)
        ac = check_feature_has_ac(feature_id, project_root)
        issues = spec.reasons + ac.reasons
        if issues:
            print(json.dumps({"feature": feature_id, "issues": issues}))
        sys.exit(0)

    # "prompt-context" combines resolve + check-artifacts + project memory in one call.
    # Replaces 3 separate Python invocations in UserPromptSubmit.sh, saving ~600-800ms.
    if args.check == "prompt-context":
        feature_id = args.feature or resolve_active_feature(project_root)
        ctx: dict = {"feature": feature_id or "", "issues": [], "cerebrum": []}
        if feature_id:
            spec = check_feature_has_spec(feature_id, project_root)
            ac = check_feature_has_ac(feature_id, project_root)
            ctx["issues"] = spec.reasons + ac.reasons
            # Load relevant project memory entries (project-scoped intelligence).
            # Uses regex extraction — robust to indentation and quoting variations.
            memory_file = project_root / ".agentic" / "intel" / "project-memory.yaml"
            if not memory_file.exists():
                # Backward compat: check old name
                memory_file = project_root / ".agentic" / "intel" / "cerebrum.yaml"
            if memory_file.exists():
                try:
                    content = memory_file.read_text()
                    entries = []
                    # Split on entry boundaries (lines starting with "- id:" at any indent)
                    for block in re.split(r'(?m)^[ \t]*- id:', content):
                        if not block.strip():
                            continue
                        entry: dict = {}
                        # ID is the first line of the block
                        first_line = block.split('\n', 1)[0].strip().strip('"').strip("'")
                        if first_line:
                            entry["id"] = first_line
                        # Extract text and type with regex (handles quotes, indentation)
                        m_text = re.search(r'text:\s*["\']?(.+?)["\']?\s*$', block, re.MULTILINE)
                        if m_text:
                            entry["text"] = m_text.group(1).strip()
                        m_type = re.search(r'type:\s*["\']?(\w+)', block, re.MULTILINE)
                        if m_type:
                            entry["type"] = m_type.group(1)
                        if entry.get("text"):
                            entries.append(entry)
                    # Return last 5 entries (most recent are most relevant)
                    ctx["cerebrum"] = entries[-5:]
                except OSError:
                    pass
        print(json.dumps(ctx))
        sys.exit(0)

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
