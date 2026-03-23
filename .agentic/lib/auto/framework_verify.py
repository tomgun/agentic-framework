"""
framework_verify.py -- Autonomous Framework Verification Loop.

Implements F-0215: spawns agents to build example projects from scratch
using the framework's ag commands, verifying the full lifecycle end-to-end.
Self-healing: when the agent hits a framework bug, the system classifies
the failure, spawns a fix agent in a verification worktree, validates the
fix, and restarts from scratch. Accumulated fixes delivered as a single PR.

@feature F-0215

Usage:
    # CLI
    ag auto verify-framework --project todo-app
    ag auto verify-framework --all
    ag auto verify-framework --all --json
"""
from __future__ import annotations

import argparse
import atexit
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Optional

_LIB_DIR = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_LIB_DIR / "tools"))

from auto import SpawnResult, spawn_claude, discover_jsonl  # noqa: E402
from ids import FEATURE_ID_RE, FEATURE_HEADER_RE  # noqa: E402

# Lazy-loaded module cache for session-analyze.py (hyphenated filename)
_session_analyze_mod = None


def _get_session_analyze():
    """Load session-analyze.py via importlib (cached)."""
    global _session_analyze_mod
    if _session_analyze_mod is None:
        import importlib.util
        sa_path = _LIB_DIR / "tools" / "session-analyze.py"
        spec = importlib.util.spec_from_file_location("session_analyze", str(sa_path))
        _session_analyze_mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(_session_analyze_mod)
    return _session_analyze_mod

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
MAX_RETRIES_PER_SCENARIO = 3
MAX_TOTAL_FIXES = 20
MAX_REPAIR_ATTEMPTS = 3
REPAIR_TIMEOUT = 300  # seconds per repair agent
SCENARIOS_DIR = Path(__file__).resolve().parent / "scenarios"
PROMPTS_DIR = Path(__file__).resolve().parent / "prompts"


# ---------------------------------------------------------------------------
# Data types
# ---------------------------------------------------------------------------

@dataclass
class MilestoneResult:
    name: str
    passed: bool
    detail: str = ""


@dataclass
class ScenarioRun:
    scenario_name: str
    settings_label: str
    success: bool = False
    milestones: list[MilestoneResult] = field(default_factory=list)
    retries: int = 0
    fixes: list[str] = field(default_factory=list)
    repairs: list[str] = field(default_factory=list)
    escalations: list[str] = field(default_factory=list)
    error: str = ""
    skipped: bool = False
    prompt_tier: str = "discovery"
    behavioral_results: list[MilestoneResult] = field(default_factory=list)


@dataclass
class VerifyResult:
    """Result of a full verification run."""
    success: bool
    runs: list[ScenarioRun] = field(default_factory=list)
    total_fixes: int = 0
    fix_commits: list[str] = field(default_factory=list)
    pr_url: str = ""
    stopped_at_max_fixes: bool = False
    messages: list[str] = field(default_factory=list)
    log_dir: str = ""

    def to_dict(self) -> dict:
        return {
            "success": self.success,
            "total_fixes": self.total_fixes,
            "log_dir": self.log_dir,
            "fix_commits": self.fix_commits,
            "pr_url": self.pr_url,
            "stopped_at_max_fixes": self.stopped_at_max_fixes,
            "runs": [
                {
                    "scenario": r.scenario_name,
                    "settings": r.settings_label,
                    "success": r.success,
                    "retries": r.retries,
                    "fixes": r.fixes,
                    "repairs": r.repairs,
                    "escalations": r.escalations,
                    "milestones": [
                        {"name": m.name, "passed": m.passed, "detail": m.detail}
                        for m in r.milestones
                    ],
                    "behavioral_results": [
                        {"name": m.name, "passed": m.passed, "detail": m.detail}
                        for m in r.behavioral_results
                    ],
                    "error": r.error,
                    "skipped": r.skipped,
                    "prompt_tier": r.prompt_tier,
                }
                for r in self.runs
            ],
            "messages": self.messages,
        }


# ---------------------------------------------------------------------------
# Scenario loading
# ---------------------------------------------------------------------------

def _load_yaml(text: str) -> dict[str, Any]:
    """Load YAML text, importing PyYAML lazily."""
    try:
        import yaml
    except ImportError:
        raise ImportError(
            "PyYAML is required for framework verification. "
            "Install with: pip install pyyaml"
        )
    return yaml.safe_load(text)


def load_scenario(name: str) -> dict[str, Any]:
    """Load a scenario YAML by slug name (e.g. 'todo_app')."""
    path = SCENARIOS_DIR / f"{name}.yaml"
    if not path.exists():
        raise FileNotFoundError(f"Scenario not found: {path}")
    return _load_yaml(path.read_text())


def list_scenarios() -> list[str]:
    """Return available scenario slugs."""
    return sorted(
        p.stem for p in SCENARIOS_DIR.glob("*.yaml")
    )


# ---------------------------------------------------------------------------
# Phase checking (F-0242) — verify intermediate workflow phases via framework.log
# ---------------------------------------------------------------------------

class PhaseChecker:
    """Check intermediate workflow phases via framework.log.

    Parses framework.log (pipe-delimited: TIMESTAMP|SCRIPT|VERB|ARGS|RESULT)
    and checks that expected phases occurred, optionally verifying filesystem
    state at each detected phase.

    Matching semantics: "at some point, this phase was attempted."
    Matches on 'start' entries by default. A phase that was attempted but
    failed (end:1) still counts as "phase occurred" — the failure is
    separately detectable via the result field.
    """

    def __init__(self, project_root: Path):
        self.root = project_root
        self.log_path = project_root / ".agentic" / "session" / "framework.log"
        self._entries: list[dict] | None = None

    def _parse_log(self) -> list[dict]:
        """Parse framework.log into structured entries.

        Returns empty list if file missing or empty.
        Handles entries with empty fields gracefully.
        Format: TIMESTAMP|SCRIPT|VERB|ARGS|RESULT
        """
        if self._entries is not None:
            return self._entries

        self._entries = []
        if not self.log_path.exists():
            return self._entries

        try:
            for line in self.log_path.read_text().splitlines():
                line = line.strip()
                if not line:
                    continue
                parts = line.split("|", maxsplit=4)
                if len(parts) < 3:
                    continue  # Malformed — need at least timestamp|script|verb
                entry = {
                    "timestamp": parts[0].strip(),
                    "script": parts[1].strip(),
                    "verb": parts[2].strip(),
                    "args": parts[3].strip() if len(parts) > 3 else "",
                    "result": parts[4].strip() if len(parts) > 4 else "",
                }
                self._entries.append(entry)
        except (OSError, IOError):
            pass  # Fail-open: unreadable log → no phase evidence

        return self._entries

    def _find_phase(
        self, detect_via: dict, require_result: str | None = None,
    ) -> dict | None:
        """Find a log entry matching the detection criteria.

        detect_via.framework_log format: "script|verb" (matched as substrings).
        If require_result is set, only match entries with that result.
        """
        pattern = detect_via.get("framework_log", "")
        if not pattern:
            return None

        parts = pattern.split("|", maxsplit=1)
        match_script = parts[0].strip().lower() if parts else ""
        match_verb = parts[1].strip().lower() if len(parts) > 1 else ""

        for entry in self._parse_log():
            script_ok = match_script in entry["script"].lower() if match_script else True
            verb_ok = match_verb in entry["verb"].lower() if match_verb else True

            if script_ok and verb_ok:
                if require_result is not None:
                    if entry["result"].lower() != require_result.lower():
                        continue
                return entry

        return None

    def check_all(self, phase_expectations: list[dict]) -> list[MilestoneResult]:
        """Check all phase expectations.

        Returns one MilestoneResult per phase.
        Missing phases produce failing results with descriptive detail.
        """
        results: list[MilestoneResult] = []

        for expectation in phase_expectations:
            phase_name = expectation.get("phase", "unknown")
            detect_via = expectation.get("detect_via", {})
            require_result = expectation.get("require_result")
            state = expectation.get("state", {})

            # Find the phase entry in framework.log
            entry = self._find_phase(detect_via, require_result)
            if entry is None:
                pattern = detect_via.get("framework_log", "?")
                results.append(MilestoneResult(
                    f"phase({phase_name})", False,
                    f"phase not found in framework.log (pattern: {pattern})",
                ))
                continue

            # Phase found — check state conditions
            if state:
                passed, detail = self._check_state(state)
                results.append(MilestoneResult(
                    f"phase({phase_name})", passed,
                    detail if not passed else f"phase detected, state verified",
                ))
            else:
                results.append(MilestoneResult(
                    f"phase({phase_name})", True,
                    f"phase detected at {entry['timestamp']}",
                ))

        return results

    def _check_state(self, state: dict) -> tuple[bool, str]:
        """Verify filesystem state conditions.

        - files_exist: glob patterns (at least one match required per pattern)
        - file_contains: list of {path, pattern} dicts (regex match on file content)
        """
        failures: list[str] = []

        for pattern in state.get("files_exist", []):
            matches = [
                m for m in self.root.glob(pattern)
                if m.is_file() and ".git" not in m.parts
            ]
            if not matches:
                failures.append(f"files_exist({pattern}): no match")

        for entry in state.get("file_contains", []):
            fpath = self.root / entry.get("path", "")
            regex = entry.get("pattern", "")
            if not fpath.exists():
                failures.append(f"file_contains: {entry.get('path', '?')} not found")
            else:
                try:
                    content = fpath.read_text(errors="ignore")
                    if not re.search(regex, content):
                        failures.append(
                            f"file_contains: pattern '{regex}' not in {entry.get('path', '?')}"
                        )
                except Exception as e:
                    failures.append(f"file_contains: error reading {entry.get('path', '?')}: {e}")

        if failures:
            return False, "; ".join(failures)
        return True, ""


# ---------------------------------------------------------------------------
# Milestone checking
# ---------------------------------------------------------------------------

class MilestoneChecker:
    """Check required milestones against a project directory."""

    def __init__(self, project_root: Path, spawn_result: SpawnResult):
        self.root = project_root
        self.result = spawn_result

    def check(self, milestone: str) -> MilestoneResult:
        method = getattr(self, f"_check_{milestone}", None)
        if method is None:
            return MilestoneResult(milestone, False, f"Unknown milestone: {milestone}")
        return method()

    def _check_kickoff_complete(self) -> MilestoneResult:
        features = self.root / ".agentic" / "spec" / "FEATURES.md"
        if not features.exists():
            return MilestoneResult("kickoff_complete", False, "FEATURES.md not found")
        content = features.read_text()
        if not FEATURE_ID_RE.search(content):
            return MilestoneResult("kickoff_complete", False, "No F-XXXX entries in FEATURES.md")
        return MilestoneResult("kickoff_complete", True)

    def _check_features_specced(self) -> MilestoneResult:
        # Check contracts first, then legacy acceptance
        contracts_dir = self.root / ".agentic" / "spec" / "contracts"
        ac_dir = self.root / ".agentic" / "spec" / "acceptance"
        contract_files = list(contracts_dir.glob("F-*.yaml")) if contracts_dir.exists() else []
        ac_files = list(ac_dir.glob("F-*.md")) if ac_dir.exists() else []
        total = len(contract_files) + len(ac_files)
        if total == 0:
            if not contracts_dir.exists() and not ac_dir.exists():
                return MilestoneResult("features_specced", False, "contracts/ and acceptance/ directories not found")
            return MilestoneResult("features_specced", False, "No contract or AC files found")
        return MilestoneResult("features_specced", True, f"{total} contract/AC files")

    def _check_component_features_scoped(self) -> MilestoneResult:
        features = self.root / ".agentic" / "spec" / "FEATURES.md"
        if not features.exists():
            return MilestoneResult("component_features_scoped", False, "FEATURES.md not found")
        content = features.read_text()
        if "**Component**:" not in content:
            return MilestoneResult(
                "component_features_scoped", False,
                "No features with **Component**: field"
            )
        return MilestoneResult("component_features_scoped", True)

    def _check_contracts_defined(self) -> MilestoneResult:
        stack = self.root / "STACK.md"
        if not stack.exists():
            return MilestoneResult("contracts_defined", False, "STACK.md not found")
        content = stack.read_text()
        if "## Contracts" not in content:
            return MilestoneResult("contracts_defined", False, "No ## Contracts section")
        return MilestoneResult("contracts_defined", True)

    def _check_implementation_done(self) -> MilestoneResult:
        try:
            result = subprocess.run(
                ["git", "log", "--oneline", "-20"],
                capture_output=True, text=True, cwd=str(self.root),
            )
            lines = [l for l in result.stdout.strip().split("\n") if l.strip()]
            # Need at least 2 commits (init + at least one implementation commit)
            if len(lines) >= 2:
                return MilestoneResult("implementation_done", True, f"{len(lines)} commits")
            return MilestoneResult("implementation_done", False, "Only init commit found")
        except Exception as e:
            return MilestoneResult("implementation_done", False, str(e))

    def _check_contracts_validated(self) -> MilestoneResult:
        """Call validate_contracts() directly on the project."""
        try:
            from auto.components import load_registry
            from auto.umbrella import validate_contracts
            registry = load_registry(self.root)
            results = validate_contracts(self.root, registry)
            if len(results) > 0 and all(not r.warnings for r in results):
                return MilestoneResult("contracts_validated", True)
            if len(results) == 0:
                return MilestoneResult("contracts_validated", False, "No contracts found")
            warnings = []
            for r in results:
                warnings.extend(r.warnings)
            return MilestoneResult(
                "contracts_validated", False,
                f"{len(warnings)} contract warnings"
            )
        except ImportError:
            return MilestoneResult("contracts_validated", False, "umbrella module not available")
        except Exception as e:
            return MilestoneResult("contracts_validated", False, str(e))

    def _check_integration_verified(self) -> MilestoneResult:
        journal = self.root / ".agentic" / "journal"
        if not journal.exists():
            return MilestoneResult("integration_verified", False, "journal/ not found")
        verify_files = list(journal.glob("verify-epic-*.md"))
        if verify_files:
            return MilestoneResult("integration_verified", True)
        return MilestoneResult("integration_verified", False, "No verify-epic-*.md files")

    def _check_verification_green(self) -> MilestoneResult:
        if self.result.timed_out:
            return MilestoneResult("verification_green", False, "Build agent timed out")
        if self.result.returncode != 0:
            return MilestoneResult(
                "verification_green", False,
                f"Build agent exited with code {self.result.returncode}"
            )
        return MilestoneResult("verification_green", True)


# ---------------------------------------------------------------------------
# Behavioral expectations
# ---------------------------------------------------------------------------

class ExpectationChecker:
    """Run BDD-style expectations against a built project.

    Expectations are declared in scenario YAML under an `expectations` key:

        expectations:
          files_exist:            # glob patterns — at least one match required
            - "app/**/*.py"
            - "tests/test_*.py"
          commands_pass:          # shell commands that must exit 0
            - "pytest"
          source_contains:       # regex patterns in source files
            - pattern: "FastAPI"
              glob: "app/**/*.py"
    """

    def __init__(self, project_root: Path, agent_log: Path | None = None):
        self.root = project_root
        self.agent_log = agent_log

    def check_all(self, expectations: dict[str, Any]) -> list[MilestoneResult]:
        """Run all expectations and return results."""
        results: list[MilestoneResult] = []

        for pattern in expectations.get("files_exist", []):
            results.append(self._check_files_exist(pattern))

        for cmd in expectations.get("commands_pass", []):
            results.append(self._check_command_passes(cmd))

        for entry in expectations.get("source_contains", []):
            results.append(self._check_source_contains(
                entry["pattern"], entry.get("glob", "**/*"),
            ))

        # Workflow expectations — verify the framework process was followed
        for check in expectations.get("workflow", []):
            results.append(self._check_workflow(check))

        return results

    def check_one(self, expectations: dict[str, Any], name: str) -> MilestoneResult | None:
        """Re-check a single expectation by name. Returns None if not found."""
        for result in self.check_all(expectations):
            if result.name == name:
                return result
        return None

    def _check_files_exist(self, pattern: str) -> MilestoneResult:
        matches = list(self.root.glob(pattern))
        # Filter out .git and .agentic matches
        matches = [
            m for m in matches if m.is_file()
            and ".git" not in m.parts and ".agentic" not in m.parts
        ]
        if matches:
            return MilestoneResult(
                f"files_exist({pattern})", True,
                f"{len(matches)} file(s)",
            )
        return MilestoneResult(
            f"files_exist({pattern})", False,
            "no matching files",
        )

    def _check_command_passes(self, cmd: str) -> MilestoneResult:
        try:
            result = subprocess.run(
                ["bash", "-c", cmd],
                cwd=str(self.root),
                capture_output=True, text=True,
                timeout=120,
            )
            if result.returncode == 0:
                return MilestoneResult(
                    f"command_passes({cmd})", True,
                )
            # Include last few lines of output for diagnosis
            output = (result.stdout + result.stderr).strip().split("\n")
            tail = "\n".join(output[-5:]) if len(output) > 5 else "\n".join(output)
            return MilestoneResult(
                f"command_passes({cmd})", False,
                f"exit {result.returncode}: {tail[:200]}",
            )
        except subprocess.TimeoutExpired:
            return MilestoneResult(
                f"command_passes({cmd})", False, "timed out (120s)",
            )
        except Exception as e:
            return MilestoneResult(
                f"command_passes({cmd})", False, str(e),
            )

    def _check_source_contains(self, pattern: str, glob: str) -> MilestoneResult:
        matches = [
            f for f in self.root.glob(glob)
            if f.is_file() and ".git" not in f.parts and ".agentic" not in f.parts
        ]
        if not matches:
            return MilestoneResult(
                f"source_contains({pattern})", False,
                f"no files matching {glob}",
            )
        regex = re.compile(pattern)
        matched_files = []
        for f in matches:
            try:
                if regex.search(f.read_text(errors="ignore")):
                    matched_files.append(f.name)
            except Exception:
                continue
        if matched_files:
            return MilestoneResult(
                f"source_contains({pattern})", True,
                f"found in {len(matched_files)} file(s)",
            )
        return MilestoneResult(
            f"source_contains({pattern})", False,
            f"pattern not found in {len(matches)} file(s)",
        )

    # -- Workflow expectations ------------------------------------------------

    def _check_workflow(self, check: dict[str, Any]) -> MilestoneResult:
        """Dispatch a workflow expectation by type."""
        check_type = check.get("type", "")
        method = getattr(self, f"_wf_{check_type}", None)
        if method is None:
            return MilestoneResult(
                f"workflow({check_type})", False,
                f"Unknown workflow check: {check_type}",
            )
        return method(check)

    def _wf_features_have_status(self, check: dict) -> MilestoneResult:
        """At least N features reached the given status."""
        status = check.get("status", "shipped")
        min_count = check.get("min", 1)
        features_path = self.root / ".agentic" / "spec" / "FEATURES.md"
        if not features_path.exists():
            return MilestoneResult(
                f"features_have_status({status})", False,
                "FEATURES.md not found",
            )
        content = features_path.read_text()
        count = len(re.findall(
            rf"\*\*Status\*\*:\s*{re.escape(status)}", content,
        ))
        if count >= min_count:
            return MilestoneResult(
                f"features_have_status({status})", True,
                f"{count} feature(s) with status '{status}'",
            )
        return MilestoneResult(
            f"features_have_status({status})", False,
            f"only {count} feature(s) with status '{status}' (need {min_count})",
        )

    def _wf_acceptance_criteria_checked(self, check: dict) -> MilestoneResult:
        """At least N contract/AC files have all items checked off [x]."""
        min_count = check.get("min", 1)
        contracts_dir = self.root / ".agentic" / "spec" / "contracts"
        ac_dir = self.root / ".agentic" / "spec" / "acceptance"

        fully_checked = 0

        # Check contract YAML files — no checkbox concept, count as checked
        # if they exist and have assertions
        if contracts_dir.exists():
            for contract_file in contracts_dir.glob("F-*.yaml"):
                try:
                    content = contract_file.read_text()
                    if "assertions:" in content and "- id:" in content:
                        fully_checked += 1
                except Exception:
                    pass

        # Check legacy acceptance markdown files
        if ac_dir.exists():
            for ac_file in ac_dir.glob("F-*.md"):
                content = ac_file.read_text()
                unchecked = re.findall(r"- \[ \]", content)
                checked = re.findall(r"- \[x\]", content)
                if checked and not unchecked:
                    fully_checked += 1

        if fully_checked == 0 and not (contracts_dir and contracts_dir.exists()) and not (ac_dir and ac_dir.exists()):
            return MilestoneResult(
                "acceptance_criteria_checked", False,
                "contracts/ and acceptance/ directories not found",
            )

        if fully_checked >= min_count:
            return MilestoneResult(
                "acceptance_criteria_checked", True,
                f"{fully_checked} contract/AC file(s) fully checked",
            )
        return MilestoneResult(
            "acceptance_criteria_checked", False,
            f"only {fully_checked} contract/AC file(s) fully checked (need {min_count})",
        )

    def _wf_plans_exist(self, check: dict) -> MilestoneResult:
        """Plans directory has at least N plan files."""
        min_count = check.get("min", 1)
        plans_dir = self.root / ".agentic" / "journal" / "plans"
        if not plans_dir.exists():
            return MilestoneResult(
                "plans_exist", False, "plans/ directory not found",
            )
        plan_files = list(plans_dir.glob("F-*-plan.md"))
        if len(plan_files) >= min_count:
            return MilestoneResult(
                "plans_exist", True,
                f"{len(plan_files)} plan file(s)",
            )
        return MilestoneResult(
            "plans_exist", False,
            f"only {len(plan_files)} plan file(s) (need {min_count})",
        )

    def _wf_plans_approved(self, check: dict) -> MilestoneResult:
        """At least N plans have APPROVED status."""
        min_count = check.get("min", 1)
        plans_dir = self.root / ".agentic" / "journal" / "plans"
        if not plans_dir.exists():
            return MilestoneResult(
                "plans_approved", False, "plans/ directory not found",
            )
        approved = 0
        for plan in plans_dir.glob("F-*-plan.md"):
            content = plan.read_text()
            if re.search(r"\*\*Status\*\*:\s*APPROVED", content):
                approved += 1
        if approved >= min_count:
            return MilestoneResult(
                "plans_approved", True,
                f"{approved} plan(s) approved",
            )
        return MilestoneResult(
            "plans_approved", False,
            f"only {approved} approved plan(s) (need {min_count})",
        )

    def _wf_journal_updated(self, _check: dict) -> MilestoneResult:
        """JOURNAL.md has at least one entry beyond the template."""
        journal = self.root / ".agentic" / "journal" / "JOURNAL.md"
        if not journal.exists():
            return MilestoneResult(
                "journal_updated", False, "JOURNAL.md not found",
            )
        content = journal.read_text()
        # Count session entries (### Session: ...) not file-level headings (## ...)
        entries = re.findall(r"^###\s+Session:", content, re.MULTILINE)
        if not entries:
            # Fallback: any ### heading (some journal formats differ)
            entries = re.findall(r"^### ", content, re.MULTILINE)
        if len(entries) >= 1:
            return MilestoneResult(
                "journal_updated", True,
                f"{len(entries)} journal entry/entries",
            )
        return MilestoneResult(
            "journal_updated", False, "no journal entries found",
        )

    def _wf_commits_follow_convention(self, check: dict) -> MilestoneResult:
        """Git commits follow conventional format with feature IDs."""
        min_count = check.get("min", 1)
        pattern = check.get("pattern", r"^(feat|fix|test|chore|docs)\(?.*\)?:")
        try:
            result = subprocess.run(
                ["git", "log", "--oneline", "-20"],
                capture_output=True, text=True, cwd=str(self.root),
                timeout=10,
            )
            lines = [
                l.split(" ", 1)[1] for l in result.stdout.strip().split("\n")
                if l.strip() and " " in l
            ]
            regex = re.compile(pattern)
            matching = [l for l in lines if regex.search(l)]
            # Exclude the init commit
            non_init = [l for l in lines if not l.startswith("init:")]
            if len(matching) >= min_count:
                return MilestoneResult(
                    "commits_follow_convention", True,
                    f"{len(matching)}/{len(non_init)} commits match",
                )
            return MilestoneResult(
                "commits_follow_convention", False,
                f"only {len(matching)}/{len(non_init)} commits match pattern",
            )
        except Exception as e:
            return MilestoneResult(
                "commits_follow_convention", False, str(e),
            )

    def _wf_no_wip_at_end(self, _check: dict) -> MilestoneResult:
        """No WIP.md or active AGENTS.json entries at project completion."""
        wip = self.root / ".agentic" / "session" / "WIP.md"
        if wip.exists():
            return MilestoneResult(
                "no_wip_at_end", False, "WIP.md still exists",
            )
        agents = self.root / ".agentic" / "session" / "AGENTS.json"
        if agents.exists():
            try:
                data = json.loads(agents.read_text())
                if data:  # Non-empty list = active agents
                    return MilestoneResult(
                        "no_wip_at_end", False,
                        f"{len(data)} active agent(s) in AGENTS.json",
                    )
            except (json.JSONDecodeError, OSError):
                pass
        return MilestoneResult("no_wip_at_end", True)

    # -- Behavioral expectation checkers (discovery mode) -------------------

    def check_behavioral(self, expectations: list[dict]) -> list[MilestoneResult]:
        """Run behavioral expectations. Results are advisory (severity: warning)."""
        results: list[MilestoneResult] = []
        for check in expectations:
            method = getattr(self, f"_wf_{check['type']}", None)
            if method:
                results.append(method(check))
            else:
                results.append(MilestoneResult(
                    f"behavioral({check['type']})", False,
                    f"Unknown behavioral check: {check['type']}",
                ))
        return results

    def _wf_spec_before_code(self, check: dict) -> MilestoneResult:
        """Verify spec artifacts were committed before or with implementation code.

        Uses git log to find when files were first added. Compares commit
        position of first AC file vs first source code file. Same-commit
        counts as passing.
        """
        try:
            # Find first commit adding a contract or AC file
            ac_result = subprocess.run(
                ["git", "log", "--reverse", "--format=%H",
                 "--diff-filter=A", "--",
                 ".agentic/spec/contracts/*", ".agentic/spec/acceptance/*"],
                capture_output=True, text=True, cwd=str(self.root), timeout=10,
            )
            ac_commits = [h for h in ac_result.stdout.strip().split("\n") if h]

            if not ac_commits:
                return MilestoneResult(
                    "spec_before_code", False,
                    "no contract or acceptance criteria files found in git history",
                )

            # Find the scaffold commit to exclude it (it's setup, not agent code)
            scaffold_result = subprocess.run(
                ["git", "log", "--reverse", "--format=%H", "--grep=init: project scaffold",
                 "--max-count=1"],
                capture_output=True, text=True, cwd=str(self.root), timeout=10,
            )
            scaffold_hash = scaffold_result.stdout.strip()

            # Find first commit adding source code (common patterns)
            code_globs = ["app/**/*.py", "src/**/*.py", "src/**/*.ts",
                          "*.py", "**/*.py"]
            code_commits: list[str] = []
            for glob in code_globs:
                result = subprocess.run(
                    ["git", "log", "--reverse", "--format=%H",
                     "--diff-filter=A", "--", glob],
                    capture_output=True, text=True, cwd=str(self.root), timeout=10,
                )
                commits = [h for h in result.stdout.strip().split("\n")
                           if h and h != scaffold_hash]
                code_commits.extend(commits)
            code_commits = list(dict.fromkeys(code_commits))  # dedupe, preserve order

            if not code_commits:
                return MilestoneResult(
                    "spec_before_code", True,
                    "no source code commits found (spec-only project)",
                )

            # Get all commit hashes in order to compare positions
            all_commits = subprocess.run(
                ["git", "log", "--reverse", "--format=%H"],
                capture_output=True, text=True, cwd=str(self.root), timeout=10,
            ).stdout.strip().split("\n")

            first_ac_pos = all_commits.index(ac_commits[0]) if ac_commits[0] in all_commits else -1
            first_code_pos = all_commits.index(code_commits[0]) if code_commits[0] in all_commits else -1

            if first_ac_pos == -1:
                return MilestoneResult(
                    "spec_before_code", False, "AC commit not found in history",
                )
            if first_code_pos == -1:
                return MilestoneResult(
                    "spec_before_code", True, "code commit not in history",
                )

            if first_ac_pos <= first_code_pos:
                return MilestoneResult(
                    "spec_before_code", True,
                    f"AC at commit #{first_ac_pos + 1}, code at #{first_code_pos + 1}",
                )
            return MilestoneResult(
                "spec_before_code", False,
                f"code at commit #{first_code_pos + 1} before AC at #{first_ac_pos + 1}",
            )
        except Exception as e:
            return MilestoneResult("spec_before_code", False, str(e))

    def _wf_workflow_commands_used(self, check: dict) -> MilestoneResult:
        """Check artifacts for evidence a framework command was discovered and used."""
        command = check.get("command", "")
        evidence_type = check.get("evidence", "")

        if command == "kickoff" and evidence_type == "features_md_format":
            features_path = self.root / ".agentic" / "spec" / "FEATURES.md"
            if not features_path.exists():
                return MilestoneResult(
                    f"workflow_commands_used({command})", False,
                    "FEATURES.md not found",
                )
            content = features_path.read_text()
            # Evidence of ag kickoff: F-XXXX entries with Status fields
            has_feature_ids = FEATURE_HEADER_RE.search(content)
            has_status_fields = re.search(r"\*\*Status\*\*:", content)
            if has_feature_ids and has_status_fields:
                return MilestoneResult(
                    f"workflow_commands_used({command})", True,
                    "FEATURES.md has F-XXXX entries with Status fields",
                )
            return MilestoneResult(
                f"workflow_commands_used({command})", False,
                "FEATURES.md exists but lacks F-XXXX entries with Status fields",
            )

        if command == "commit" and evidence_type == "conventional_commits":
            try:
                out = subprocess.run(
                    ["git", "log", "--format=%s"],
                    capture_output=True, text=True, cwd=str(self.root), timeout=10,
                ).stdout.strip()
                messages = [m for m in out.split("\n") if m]
                convention = re.compile(
                    r"^(feat|fix|test|chore|docs|refactor|style|perf|ci|build)\(?",
                )
                matching = [m for m in messages if convention.match(m)]
                if matching:
                    return MilestoneResult(
                        f"workflow_commands_used({command})", True,
                        f"{len(matching)} conventional commits found",
                    )
                return MilestoneResult(
                    f"workflow_commands_used({command})", False,
                    "no conventional commit messages found",
                )
            except Exception as e:
                return MilestoneResult(
                    f"workflow_commands_used({command})", False, str(e),
                )

        if command == "implement":
            # Evidence: plan files exist or JOURNAL.md has session entries
            plans_dir = self.root / ".agentic" / "journal" / "plans"
            journal = self.root / ".agentic" / "journal" / "JOURNAL.md"
            has_plans = plans_dir.exists() and any(plans_dir.glob("F-*-plan.md"))
            has_journal = journal.exists() and "### Session:" in journal.read_text()
            if has_plans or has_journal:
                return MilestoneResult(
                    f"workflow_commands_used({command})", True,
                    f"plans={'yes' if has_plans else 'no'}, journal={'yes' if has_journal else 'no'}",
                )
            return MilestoneResult(
                f"workflow_commands_used({command})", False,
                "no plan files or journal session entries found",
            )

        if command == "done":
            features_path = self.root / ".agentic" / "spec" / "FEATURES.md"
            if features_path.exists():
                content = features_path.read_text()
                if re.search(r"\*\*Status\*\*:\s*shipped", content):
                    return MilestoneResult(
                        f"workflow_commands_used({command})", True,
                        "features with shipped status found",
                    )
            return MilestoneResult(
                f"workflow_commands_used({command})", False,
                "no shipped features found",
            )

        return MilestoneResult(
            f"workflow_commands_used({command})", False,
            f"unknown command/evidence combo: {command}/{evidence_type}",
        )

    def _wf_session_start_ran(self, check: dict) -> MilestoneResult:
        """Check if agent ran the session-start protocol.

        Evidence: STATUS.md has content beyond default template, or
        JOURNAL.md has a Session entry.
        """
        status_path = self.root / ".agentic" / "STATUS.md"
        journal_path = self.root / ".agentic" / "journal" / "JOURNAL.md"

        if status_path.exists():
            content = status_path.read_text().strip()
            # Default STATUS.md is minimal; any substantial content = session started
            if content and len(content) > 50:
                return MilestoneResult(
                    "session_start_ran", True,
                    "STATUS.md has content beyond default",
                )

        if journal_path.exists():
            content = journal_path.read_text()
            if "### Session:" in content:
                return MilestoneResult(
                    "session_start_ran", True,
                    "JOURNAL.md has session entry",
                )

        return MilestoneResult(
            "session_start_ran", False,
            "no evidence of session-start protocol in STATUS.md or JOURNAL.md",
        )

    def _wf_plans_reviewed(self, check: dict) -> MilestoneResult:
        """Check that plan files show evidence of review (DRAFT → APPROVED)."""
        plans_dir = self.root / ".agentic" / "journal" / "plans"
        if not plans_dir.exists():
            return MilestoneResult(
                "plans_reviewed", False, "no plans directory found",
            )
        plan_files = list(plans_dir.glob("F-*-plan.md"))
        if not plan_files:
            return MilestoneResult(
                "plans_reviewed", False, "no plan files found",
            )
        approved = 0
        for pf in plan_files:
            content = pf.read_text()
            if re.search(r"\*\*Status\*\*:\s*APPROVED", content):
                approved += 1
        if approved > 0:
            return MilestoneResult(
                "plans_reviewed", True,
                f"{approved}/{len(plan_files)} plan(s) have APPROVED status",
            )
        return MilestoneResult(
            "plans_reviewed", False,
            f"0/{len(plan_files)} plans have APPROVED status",
        )

    def _wf_instruction_files_consulted(self, check: dict) -> MilestoneResult:
        """Grep agent log for evidence of reading instruction files. Supplementary."""
        if not self.agent_log or not self.agent_log.exists():
            return MilestoneResult(
                "instruction_files_consulted", False,
                "no agent log available",
            )
        try:
            log_content = self.agent_log.read_text(errors="ignore")
            markers = ["CLAUDE.md", "skills/", "memory-seed.md",
                        "implementing-features", "session-start"]
            found = [m for m in markers if m in log_content]
            if len(found) >= 2:
                return MilestoneResult(
                    "instruction_files_consulted", True,
                    f"found references to: {', '.join(found)}",
                )
            return MilestoneResult(
                "instruction_files_consulted", False,
                f"only found {len(found)} instruction file reference(s) in log",
            )
        except Exception as e:
            return MilestoneResult(
                "instruction_files_consulted", False, str(e),
            )


# ---------------------------------------------------------------------------
# Settings-driven workflow expectations
# ---------------------------------------------------------------------------

def derive_workflow_expectations(project_root: Path) -> list[dict]:
    """Derive workflow expectations from the project's resolved settings.

    Uses get_setting() with its three-level fallback (explicit STACK.md →
    profile preset → default) so expectations adapt to overrides, not just
    profile names.
    """
    import settings as _settings
    _settings._cache.clear()

    checks: list[dict] = [
        {"type": "journal_updated"},
        {"type": "commits_follow_convention", "min": 2},
        {"type": "no_wip_at_end"},
    ]

    if _settings.get_setting(project_root, "feature_tracking", "no") == "yes":
        checks.append({"type": "features_have_status", "status": "shipped", "min": 1})

    if (_settings.get_setting(project_root, "spec_directory", "no") == "yes"
            and _settings.get_setting(project_root, "acceptance_criteria", "recommended") == "blocking"):
        checks.append({"type": "acceptance_criteria_checked", "min": 1})

    if _settings.get_setting(project_root, "plan_review_enabled", "no") == "yes":
        checks.append({"type": "plans_exist", "min": 1})
        checks.append({"type": "plans_approved", "min": 1})

    return checks


def derive_behavioral_expectations(project_root: Path, prompt_tier: str) -> list[dict]:
    """Derive behavioral expectations for discovery-mode verification.

    Returns empty list for recipe mode — behavioral compliance is meaningless
    when the agent is told exactly what to do.

    All behavioral checks use severity: warning (advisory, non-blocking).
    """
    if prompt_tier == "recipe":
        return []

    import settings as _settings
    _settings._cache.clear()

    checks: list[dict] = [
        {"type": "spec_before_code", "severity": "warning"},
        {"type": "session_start_ran", "severity": "warning"},
        {"type": "workflow_commands_used", "command": "kickoff",
         "evidence": "features_md_format", "severity": "warning"},
        {"type": "workflow_commands_used", "command": "commit",
         "evidence": "conventional_commits", "severity": "warning"},
    ]

    if _settings.get_setting(project_root, "plan_review_enabled", "no") == "yes":
        checks.append({"type": "plans_reviewed", "severity": "warning"})

    return checks


# ---------------------------------------------------------------------------
# Agent bootstrap — create the files Claude Code auto-reads
# ---------------------------------------------------------------------------

def _bootstrap_agent_files(project_dir: Path) -> None:
    """Run the real setup-agent.sh and generate-skills.sh scripts.

    Without CLAUDE.md and .claude/skills/, the spawned agent has no
    auto-loaded instruction file and no skills — it can't follow the
    framework workflow.  We call the same scripts the install flow uses
    so the test project matches what real users get.
    """
    lib_dir = project_dir / ".agentic" / "lib"
    tools_dir = lib_dir / "tools"
    env = {**os.environ, "ROOT_DIR": str(project_dir)}

    # 1. setup-agent.sh claude — creates CLAUDE.md
    setup_script = tools_dir / "setup-agent.sh"
    if setup_script.exists():
        subprocess.run(
            ["bash", str(setup_script), "claude"],
            cwd=str(project_dir), env=env,
            capture_output=True, text=True,
        )

    # 2. generate-skills.sh — creates .claude/skills/ from skill sources
    skills_script = tools_dir / "generate-skills.sh"
    skills_src = lib_dir / "agents" / "claude" / "skills"
    if skills_script.exists() and skills_src.is_dir():
        subprocess.run(
            ["bash", str(skills_script)],
            cwd=str(project_dir), env=env,
            capture_output=True, text=True,
        )

    # 3. AGENTS.md — non-negotiable rules referenced by CLAUDE.md
    agents_template = lib_dir / "init" / "AGENTS.template.md"
    if agents_template.exists() and not (project_dir / "AGENTS.md").exists():
        shutil.copy2(str(agents_template), str(project_dir / "AGENTS.md"))


# ---------------------------------------------------------------------------
# Project setup
# ---------------------------------------------------------------------------

def _reset_project_state(project_dir: Path) -> None:
    """Reset state and spec files so the test project starts fresh.

    After copying .agentic/ from the framework VW, the test project inherits
    all framework features (F-0001 through F-02XX), backlog entries, journal,
    etc. This resets those files so the agent starts with a clean slate and
    feature numbering begins from F-0001.
    """
    agentic = project_dir / ".agentic"

    # Reset spec files — empty FEATURES.md, remove contracts and acceptance criteria
    spec_dir = agentic / "spec"
    if spec_dir.exists():
        features = spec_dir / "FEATURES.md"
        if features.exists():
            features.write_text("# Features\n\n")
        contracts_dir = spec_dir / "contracts"
        if contracts_dir.exists():
            shutil.rmtree(contracts_dir)
            contracts_dir.mkdir()
        ac_dir = spec_dir / "acceptance"
        if ac_dir.exists():
            shutil.rmtree(ac_dir)
            ac_dir.mkdir()
        # Remove ADRs (framework-specific)
        adr_dir = spec_dir / "adr"
        if adr_dir.exists():
            shutil.rmtree(adr_dir)
            adr_dir.mkdir()
        # Reset other spec files
        for f in ("ISSUES.md", "NFR.md", "REFERENCES.md", "LESSONS.md"):
            p = spec_dir / f
            if p.exists():
                p.write_text(f"# {f.replace('.md', '')}\n\n")

    # Reset state files
    backlog = agentic / "BACKLOG.json"
    if backlog.exists():
        backlog.write_text("[]\n")

    status = agentic / "STATUS.md"
    if status.exists():
        status.write_text("# Status\n\n## Current session state\n\n## Current focus\n")

    overview = agentic / "OVERVIEW.md"
    if overview.exists():
        overview.write_text("# Overview\n\n")

    todo = agentic / "TODO.md"
    if todo.exists():
        todo.write_text("# TODO\n\n")

    human_needed = agentic / "HUMAN_NEEDED.md"
    if human_needed.exists():
        human_needed.write_text("# Human Needed\n\n")

    contributions = agentic / "CONTRIBUTIONS.md"
    if contributions.exists():
        contributions.write_text("# Contributions\n\n")

    # Reset journal
    journal_dir = agentic / "journal"
    if journal_dir.exists():
        journal = journal_dir / "JOURNAL.md"
        if journal.exists():
            journal.write_text("# Journal\n\n")
        # Remove plans and manifests
        for subdir in ("plans", "manifests", "lessons"):
            d = journal_dir / subdir
            if d.exists():
                shutil.rmtree(d)
                d.mkdir()

    # Reset session state
    session_dir = agentic / "session"
    if session_dir.exists():
        shutil.rmtree(session_dir)
        session_dir.mkdir()


def setup_project(
    scenario: dict[str, Any],
    vw_path: Path,
    project_dir: Path,
    settings: dict[str, str],
) -> None:
    """Set up an example project directory from the VW framework source."""
    project_dir.mkdir(parents=True, exist_ok=True)

    # Copy framework
    shutil.copytree(vw_path / ".agentic", project_dir / ".agentic")

    # Reset state so the test project starts fresh (clean features, backlog, etc.)
    _reset_project_state(project_dir)

    # Ensure presets are at the path get_setting() expects
    presets_src = project_dir / ".agentic" / "lib" / "presets"
    presets_dst = project_dir / ".agentic" / "presets"
    if presets_src.exists() and not presets_dst.exists():
        shutil.copytree(str(presets_src), str(presets_dst))

    # Create tier-1 settings for non-interactive execution
    claude_dir = project_dir / ".claude"
    claude_dir.mkdir(exist_ok=True)
    (claude_dir / "settings.json").write_text('{"_tier": 1}')

    # Bootstrap agent files (CLAUDE.md, skills, AGENTS.md)
    _bootstrap_agent_files(project_dir)

    # Write STACK.md
    _write_stack_md(project_dir, scenario, settings)

    # Create component dirs for monorepo
    if scenario.get("type") == "monorepo":
        for comp in scenario.get("components", []):
            comp_path = project_dir / comp["path"]
            comp_path.mkdir(parents=True, exist_ok=True)

    # Git init
    subprocess.run(["git", "init"], cwd=str(project_dir), check=True,
                    capture_output=True, text=True)
    subprocess.run(["git", "add", "."], cwd=str(project_dir), check=True,
                    capture_output=True, text=True)
    subprocess.run(
        ["git", "commit", "-m", "init: project scaffold"],
        cwd=str(project_dir), check=True, capture_output=True, text=True,
    )


def setup_multirepo_project(
    scenario: dict[str, Any],
    vw_path: Path,
    base_dir: Path,
    settings: dict[str, str],
) -> Path:
    """Set up a multi-repo project with umbrella + component repos.

    Returns the umbrella project directory (the primary project_root).
    """
    umbrella_dir = base_dir / "umbrella"
    umbrella_dir.mkdir(parents=True, exist_ok=True)

    # Create component repos FIRST (umbrella.py checks .git existence)
    component_paths: dict[str, Path] = {}
    for comp in scenario.get("components", []):
        comp_name = comp["name"]
        # Resolve path relative to umbrella
        comp_dir = (umbrella_dir / comp["path"]).resolve()
        comp_dir.mkdir(parents=True, exist_ok=True)
        component_paths[comp_name] = comp_dir

        # Git init each component repo
        subprocess.run(["git", "init"], cwd=str(comp_dir), check=True,
                        capture_output=True, text=True)
        # Create a minimal file so we can commit
        (comp_dir / "README.md").write_text(f"# {comp_name}\n")
        subprocess.run(["git", "add", "."], cwd=str(comp_dir), check=True,
                        capture_output=True, text=True)
        subprocess.run(
            ["git", "commit", "-m", f"init: {comp_name} component"],
            cwd=str(comp_dir), check=True, capture_output=True, text=True,
        )

    # Now set up umbrella with resolved paths
    shutil.copytree(vw_path / ".agentic", umbrella_dir / ".agentic")

    # Reset state so the test project starts fresh
    _reset_project_state(umbrella_dir)

    # Ensure presets are at the path get_setting() expects
    presets_src = umbrella_dir / ".agentic" / "lib" / "presets"
    presets_dst = umbrella_dir / ".agentic" / "presets"
    if presets_src.exists() and not presets_dst.exists():
        shutil.copytree(str(presets_src), str(presets_dst))

    claude_dir = umbrella_dir / ".claude"
    claude_dir.mkdir(exist_ok=True)
    (claude_dir / "settings.json").write_text('{"_tier": 1}')

    # Bootstrap agent files (CLAUDE.md, skills, AGENTS.md)
    _bootstrap_agent_files(umbrella_dir)

    # Write STACK.md with resolved absolute paths (not 'repo: local')
    _write_multirepo_stack_md(umbrella_dir, scenario, settings, component_paths)

    # Git init umbrella
    subprocess.run(["git", "init"], cwd=str(umbrella_dir), check=True,
                    capture_output=True, text=True)
    subprocess.run(["git", "add", "."], cwd=str(umbrella_dir), check=True,
                    capture_output=True, text=True)
    subprocess.run(
        ["git", "commit", "-m", "init: umbrella scaffold"],
        cwd=str(umbrella_dir), check=True, capture_output=True, text=True,
    )

    return umbrella_dir


def _write_stack_md(
    project_dir: Path,
    scenario: dict[str, Any],
    settings: dict[str, str],
) -> None:
    """Write STACK.md for a single or monorepo project."""
    stack = scenario.get("stack", {})
    lines = [
        "# STACK.md",
        "",
        f"Purpose: {scenario.get('description', 'Example project')}",
        "",
        "## Settings",
        f"- profile: {settings.get('profile', 'discovery')}",
        f"- git_workflow: {settings.get('git_workflow', 'direct')}",
    ]
    if "docs_mode" in settings:
        lines.append(f"- docs_mode: {settings['docs_mode']}")
    if "review_merge" in settings:
        lines.append(f"- review_merge: {settings['review_merge']}")
    # Formal profiles: acceptance_criteria is always blocking.
    # review_plan and review_commit use profile defaults so agents exercise
    # the full workflow (critical_agent for autonomous_formal, human for formal).
    # review_merge stays as specified in scenario YAML (must be "skip" for autonomous).
    profile = settings.get("profile", "discovery")
    if profile in ("formal", "autonomous_formal"):
        lines.append("- acceptance_criteria: blocking")

    lines.extend([
        "",
        "## Stack",
        f"- Language: {stack.get('language', 'python')}",
    ])
    if "framework" in stack:
        lines.append(f"- Framework: {stack['framework']}")
    if "test_runner" in stack:
        lines.append(f"- Test runner: {stack['test_runner']}")

    # Components table for monorepo
    if scenario.get("type") == "monorepo" and scenario.get("components"):
        lines.extend(["", "## Components", "", "| Name | Path | Type | Test Command |",
                       "|------|------|------|-------------|"])
        for comp in scenario["components"]:
            lines.append(
                f"| {comp['name']} | {comp['path']} | {comp.get('type', '')} "
                f"| {comp.get('test_command', '')} |"
            )

    lines.append("")
    (project_dir / "STACK.md").write_text("\n".join(lines))


def _write_multirepo_stack_md(
    umbrella_dir: Path,
    scenario: dict[str, Any],
    settings: dict[str, str],
    component_paths: dict[str, Path],
) -> None:
    """Write STACK.md for a multi-repo umbrella project with resolved paths."""
    lines = [
        "# STACK.md",
        "",
        f"Purpose: {scenario.get('description', 'Multi-repo project')}",
        "",
        "## Settings",
        f"- profile: {settings.get('profile', 'autonomous_formal')}",
        f"- git_workflow: {settings.get('git_workflow', 'pull_request')}",
    ]
    if "review_merge" in settings:
        lines.append(f"- review_merge: {settings['review_merge']}")
    # Formal profiles: acceptance_criteria is always blocking.
    # review_plan and review_commit use profile defaults (see _write_stack_md).
    profile = settings.get("profile", "discovery")
    if profile in ("formal", "autonomous_formal"):
        lines.append("- acceptance_criteria: blocking")

    # Components with resolved paths and Repo column
    lines.extend(["", "## Components", "",
                   "| Name | Path | Repo | Type | Test Command |",
                   "|------|------|------|------|-------------|"])
    for comp in scenario.get("components", []):
        resolved = str(component_paths.get(comp["name"], comp["path"]))
        lines.append(
            f"| {comp['name']} | {comp['path']} | {resolved} "
            f"| {comp.get('type', '')} | {comp.get('test_command', '')} |"
        )

    # Contracts
    if scenario.get("contracts"):
        lines.extend(["", "## Contracts", "",
                       "| Name | Format | Path | Producer | Consumers |",
                       "|------|--------|------|----------|-----------|"])
        for contract in scenario["contracts"]:
            consumers = ", ".join(contract.get("consumers", []))
            lines.append(
                f"| {contract['name']} | {contract.get('format', '')} "
                f"| {contract.get('path', '')} | {contract.get('producer', '')} "
                f"| {consumers} |"
            )

    lines.append("")
    (umbrella_dir / "STACK.md").write_text("\n".join(lines))


# ---------------------------------------------------------------------------
# Build prompt generation
# ---------------------------------------------------------------------------

def build_prompt(scenario: dict[str, Any], settings: dict[str, str]) -> str:
    """Generate the build agent prompt from template + scenario data.

    Uses discovery template by default (agent discovers workflow from
    instruction files). Recipe template is used when prompt_tier=recipe
    (prescriptive step-by-step instructions).
    """
    prompt_tier = settings.get("prompt_tier", "discovery")

    if prompt_tier == "recipe":
        template_path = PROMPTS_DIR / "verify_build.md"
    else:
        template_path = PROMPTS_DIR / "verify_build_discovery.md"

    template = template_path.read_text()

    stack = scenario.get("stack", {})
    stack_desc = ", ".join(f"{k}: {v}" for k, v in stack.items())

    # Discovery template uses fewer variables than recipe; use safe formatting
    format_vars = {
        "vision": scenario.get("vision", "").strip(),
        "stack_description": stack_desc or "See STACK.md",
        "profile": settings.get("profile", "discovery"),
        "git_workflow": settings.get("git_workflow", "direct"),
    }

    # Only include vars the template actually uses
    try:
        return template.format(**format_vars)
    except KeyError:
        # Fallback: format only known placeholders
        result = template
        for key, val in format_vars.items():
            result = result.replace(f"{{{key}}}", str(val))
        return result


# ---------------------------------------------------------------------------
# Core verifier
# ---------------------------------------------------------------------------

class FrameworkVerifier:
    """Orchestrates framework verification runs."""

    def __init__(
        self,
        project_root: Path,
        *,
        claude_command: str = "claude",
        json_output: bool = False,
    ):
        self.project_root = project_root
        self.claude_command = claude_command
        self.json_output = json_output
        self.vw_path: Optional[Path] = None
        self.vw_branch: str = ""
        self.total_fixes = 0
        self.fix_commits: list[str] = []
        self._push_succeeded = False
        self._pr_created = False
        # Log directory for agent output — stored in workspace for visibility
        # across containers that share the same workspace mount.
        log_base = project_root / ".agentic" / "session" / "verify-logs"
        ts = time.strftime("%Y%m%d-%H%M%S")
        self.log_dir = log_base / f"run-{ts}"
        self.log_dir.mkdir(parents=True, exist_ok=True)

    def _log(self, msg: str) -> None:
        """Print a timestamped progress message to stderr.

        Uses stderr so progress is visible even with --json (which uses stdout).
        """
        ts = time.strftime("%H:%M:%S")
        print(f"[{ts}] {msg}", file=sys.stderr, flush=True)

    # -- Pre-flight ----------------------------------------------------------

    def pre_flight(self) -> list[str]:
        """Run pre-flight checks. Returns list of blocking errors."""
        errors: list[str] = []

        # 0. Framework-only guard: refuse to run in production projects.
        # verify-framework spawns agents with --dangerously-skip-permissions,
        # creates worktrees, and consumes significant tokens. It is meant
        # ONLY for the framework repo itself, not user projects.
        marker = self.project_root / "FRAMEWORK_DEVELOPMENT.md"
        if not marker.exists():
            errors.append(
                "verify-framework is only available in the framework repo itself. "
                "This project does not have FRAMEWORK_DEVELOPMENT.md. "
                "If you are developing the framework, ensure you are in the "
                "correct directory."
            )

        # 1. Claude availability
        try:
            subprocess.run(
                [self.claude_command, "--version"],
                capture_output=True, text=True, timeout=10,
            )
        except (FileNotFoundError, subprocess.TimeoutExpired):
            errors.append(f"Claude CLI not found: {self.claude_command}")

        # 2. Not on main
        branch = subprocess.run(
            ["git", "rev-parse", "--abbrev-ref", "HEAD"],
            capture_output=True, text=True, cwd=str(self.project_root),
        ).stdout.strip()
        if branch in ("main", "master"):
            errors.append(f"Cannot run from {branch} branch")

        # 3. No concurrent verify runs
        branches = subprocess.run(
            ["git", "branch", "--list", "verify/run-*"],
            capture_output=True, text=True, cwd=str(self.project_root),
        ).stdout.strip()
        if branches:
            errors.append(
                f"Concurrent verify run detected: {branches.strip()}. "
                "Clean up first: git worktree remove + git branch -D"
            )

        # 4. No stale AG_TRUNK_BRANCH from a previous run
        if os.environ.get("AG_TRUNK_BRANCH"):
            errors.append(
                "AG_TRUNK_BRANCH env var is already set "
                f"({os.environ['AG_TRUNK_BRANCH']}). "
                "Another verify run may be active."
            )

        return errors

    # -- VW management -------------------------------------------------------

    def create_vw(self) -> None:
        """Create the verification worktree on an ephemeral branch."""
        ts = int(time.time())
        self.vw_branch = f"verify/run-{ts}"
        self.vw_path = Path(tempfile.mkdtemp(prefix="ag-vw-"))

        subprocess.run(
            ["git", "worktree", "add", "-b", self.vw_branch, str(self.vw_path)],
            check=True, capture_output=True, text=True,
            cwd=str(self.project_root),
        )

        # Create tier-1 settings in VW for fix agent
        claude_dir = self.vw_path / ".claude"
        claude_dir.mkdir(exist_ok=True)
        (claude_dir / "settings.json").write_text('{"_tier": 1}')

        # Set env var for all spawned subprocesses
        os.environ["AG_TRUNK_BRANCH"] = self.vw_branch

        # Register cleanup
        atexit.register(self._cleanup)

    def _cleanup(self) -> None:
        """Clean up VW and ephemeral branch."""
        try:
            if self.vw_path and self.vw_path.exists():
                subprocess.run(
                    ["git", "worktree", "remove", "--force", str(self.vw_path)],
                    capture_output=True, text=True,
                    cwd=str(self.project_root),
                )
        except Exception:
            pass

        # Only delete branch if push/PR didn't happen
        if not self._push_succeeded and self.vw_branch:
            try:
                subprocess.run(
                    ["git", "branch", "-D", self.vw_branch],
                    capture_output=True, text=True,
                    cwd=str(self.project_root),
                )
            except Exception:
                pass

        # Clean env
        os.environ.pop("AG_TRUNK_BRANCH", None)

    def _cleanup_agents_json(self, scenario_name: str) -> None:
        """Remove stale AGENTS.json entries from prior scenario attempts."""
        try:
            agents_helper = _LIB_DIR / "tools" / "agents_helpers.py"
            if agents_helper.exists():
                subprocess.run(
                    ["python3", str(agents_helper),
                     "--project-root", str(self.project_root), "cleanup-stale"],
                    capture_output=True, text=True, timeout=10,
                )
        except Exception:
            pass  # Best-effort cleanup

    # -- Run scenario --------------------------------------------------------

    def run_scenario(
        self,
        scenario: dict[str, Any],
        settings: dict[str, str],
    ) -> ScenarioRun:
        """Run a single scenario with a single settings combo."""
        name = scenario.get("name", "unknown")
        settings_label = settings.get("profile", "default")
        timeout = int(settings.get("timeout_override") or scenario.get("timeout", 600))
        prompt_tier = settings.get("prompt_tier", "discovery")

        run = ScenarioRun(
            scenario_name=name, settings_label=settings_label,
            prompt_tier=prompt_tier,
        )

        slug = name.lower().replace(' ', '-')

        for retry in range(MAX_RETRIES_PER_SCENARIO):
            if self.total_fixes >= MAX_TOTAL_FIXES:
                run.skipped = True
                run.error = "Max total fixes reached"
                return run

            run.retries = retry
            attempt = retry + 1
            self._log(
                f"{'─' * 40}\n"
                f"         {name} [{settings_label}] — attempt {attempt}/{MAX_RETRIES_PER_SCENARIO}"
            )

            # Clean up stale AGENTS.json entries from prior attempts
            self._cleanup_agents_json(name)

            # Create fresh project
            project_dir = Path(tempfile.mkdtemp(
                prefix=f"ag-verify-{slug}-"
            ))

            # Log file for this attempt
            log_file = self.log_dir / f"{slug}_{settings_label}_attempt{attempt}.log"
            self._log(f"  Project: {project_dir}")
            self._log(f"  Log:     {log_file}")
            self._log(f"  Watch:   tail -f {log_file}")

            try:
                # Set up project based on type
                if scenario.get("type") == "multirepo":
                    project_root = setup_multirepo_project(
                        scenario, self.vw_path, project_dir, settings
                    )
                else:
                    project_root = project_dir
                    setup_project(scenario, self.vw_path, project_dir, settings)

                self._log(f"  Project scaffolded, spawning build agent (timeout={timeout}s, prompt={prompt_tier})...")

                # Spawn build agent
                prompt = build_prompt(scenario, settings)
                result = spawn_claude(
                    self.claude_command,
                    project_root,
                    prompt,
                    timeout=timeout,
                    log_file=log_file,
                    monitor=True,
                    monitor_interval=30,
                )

                # Report agent exit
                if result.timed_out:
                    self._log(f"  Agent timed out after {timeout}s")
                elif result.returncode == 0:
                    self._log(f"  Agent finished (exit 0)")
                else:
                    self._log(f"  Agent exited with code {result.returncode}")

                # Check milestones
                checker = MilestoneChecker(project_root, result)
                milestones = [
                    checker.check(m) for m in scenario.get("required_milestones", [])
                ]
                run.milestones = milestones

                for m in milestones:
                    icon = "+" if m.passed else "✗"
                    detail = f" — {m.detail}" if m.detail else ""
                    self._log(f"    {icon} {m.name}{detail}")

                # Phase expectations (F-0242) — check intermediate workflow states
                if scenario.get("phase_expectations"):
                    self._log(f"  Running phase expectations...")
                    phase_checker = PhaseChecker(project_root)
                    phase_results = phase_checker.check_all(
                        scenario["phase_expectations"]
                    )
                    milestones.extend(phase_results)
                    run.milestones = milestones

                    for m in phase_results:
                        icon = "+" if m.passed else "✗"
                        detail = f" — {m.detail}" if m.detail else ""
                        self._log(f"    {icon} {m.name}{detail}")

                # JSONL session analysis (F-0242) — detect workflow violations
                jsonl_path = discover_jsonl(project_root)
                if jsonl_path:
                    self._log(f"  Analyzing JSONL session log: {jsonl_path.name}")
                    try:
                        _sa = _get_session_analyze()
                        messages = _sa.parse_jsonl(str(jsonl_path))
                        events = _sa.extract_events(messages)
                        violations = _sa.detect_violations(events)

                        if violations:
                            for v in violations:
                                m = MilestoneResult(
                                    f"no_violation({v['type']})", False,
                                    v.get("description", v["type"]),
                                )
                                milestones.append(m)
                                self._log(
                                    f"    ✗ no_violation({v['type']}) "
                                    f"— {v.get('description', '')}"
                                )
                        else:
                            m = MilestoneResult(
                                "no_violations", True,
                                f"0 violations in {len(events)} events",
                            )
                            milestones.append(m)
                            self._log(
                                f"    + no_violations — clean session "
                                f"({len(events)} events)"
                            )

                        run.milestones = milestones
                    except Exception as e:
                        self._log(f"  ⚠ JSONL analysis failed: {e}")
                else:
                    self._log(f"  ⚠ No JSONL session log found for project")

                # Check behavioral expectations
                # Scenario-level expectations (files_exist, commands_pass, source_contains)
                expectations = dict(scenario.get("expectations", {}))

                # Derive workflow expectations from resolved settings
                expectations["workflow"] = derive_workflow_expectations(project_root)

                # Merge non-workflow settings-level expectations (if any exist in YAML)
                settings_exp = settings.get("expectations", {})
                for key, val in settings_exp.items():
                    if key == "workflow":
                        continue  # workflow is derived, not from YAML
                    if key in expectations and isinstance(expectations[key], list):
                        expectations[key] = expectations[key] + val
                    else:
                        expectations[key] = val
                if expectations:
                    self._log(f"  Running behavioral expectations...")
                    exp_checker = ExpectationChecker(project_root, agent_log=log_file)
                    exp_results = exp_checker.check_all(expectations)
                    milestones.extend(exp_results)
                    run.milestones = milestones

                    for m in exp_results:
                        icon = "+" if m.passed else "✗"
                        detail = f" — {m.detail}" if m.detail else ""
                        self._log(f"    {icon} {m.name}{detail}")

                    # Repair loop: attempt to fix failed expectations
                    failed = [m for m in exp_results if not m.passed]
                    # Only repair if milestone checks passed (expectations are the problem)
                    exp_start_idx = len(milestones) - len(exp_results)
                    if failed and all(m.passed for m in milestones[:exp_start_idx]):
                        self._repair_expectations(
                            project_root, exp_checker, expectations,
                            failed, run, log_file,
                        )
                        # Refresh expectations after repairs (keep milestone checks as-is)
                        refreshed = exp_checker.check_all(expectations)
                        run.milestones = milestones[:exp_start_idx] + refreshed

                # Discovery-mode behavioral expectations (advisory, non-blocking)
                behavioral_exps = derive_behavioral_expectations(
                    project_root, prompt_tier,
                )
                if behavioral_exps:
                    self._log(f"  Running discovery behavioral checks (advisory)...")
                    beh_checker = ExpectationChecker(project_root, agent_log=log_file)
                    beh_results = beh_checker.check_behavioral(behavioral_exps)
                    run.behavioral_results = beh_results
                    for m in beh_results:
                        icon = "+" if m.passed else "~"
                        detail = f" — {m.detail}" if m.detail else ""
                        self._log(f"    {icon} [advisory] {m.name}{detail}")

                if all(m.passed for m in run.milestones):
                    run.success = True
                    self._log(f"  PASSED")
                    return run

                # Classify failure
                from auto.self_heal import SelfHealEngine
                engine = SelfHealEngine(self.vw_path, self.claude_command)
                failure_type = engine.classify(result, milestones)
                self._log(f"  Failure classified as: {failure_type}")

                if failure_type == "framework_bug":
                    fix_msg = engine.attempt_fix(result, milestones, name)
                    if fix_msg:
                        self.total_fixes += 1
                        self.fix_commits.append(fix_msg)
                        run.fixes.append(fix_msg)
                        self._log(f"  Fix applied: {fix_msg}")
                        # Restart from scratch (continue the retry loop)
                        continue
                    # Fix failed — fall through to retry as agent_error
                    self._log(f"  Fix attempt failed, retrying as agent_error")

                # agent_error or external — retry from scratch
                run.error = _summarize_failure(milestones, result)

            finally:
                # Clean up example project
                shutil.rmtree(project_dir, ignore_errors=True)

        return run

    # -- Delivery ------------------------------------------------------------

    # -- Repair loop ---------------------------------------------------------

    def _repair_expectations(
        self,
        project_root: Path,
        exp_checker: ExpectationChecker,
        expectations: dict[str, Any],
        failed: list[MilestoneResult],
        run: ScenarioRun,
        log_file: Path | None,
    ) -> None:
        """Iteratively repair failed expectations.

        For each failed expectation:
        1. Spawn a repair agent targeting that specific failure
        2. Re-check the expectation
        3. If still failing, retry with different instructions
        4. After MAX_REPAIR_ATTEMPTS, escalate and move on
        """
        self._log(f"  Entering repair loop: {len(failed)} failed expectation(s)")

        for fail in failed:
            repaired = False
            for attempt in range(1, MAX_REPAIR_ATTEMPTS + 1):
                self._log(
                    f"    Repairing: {fail.name} "
                    f"(attempt {attempt}/{MAX_REPAIR_ATTEMPTS})"
                )

                # Build repair prompt
                prompt = self._build_repair_prompt(
                    fail, attempt, project_root,
                )

                # Determine log file for repair agent
                repair_log = None
                if log_file:
                    base = log_file.stem
                    safe_name = re.sub(r'[^a-zA-Z0-9_-]', '_', fail.name)[:50]
                    repair_log = log_file.parent / (
                        f"{base}_repair_{safe_name}_attempt{attempt}.log"
                    )

                repair_result = spawn_claude(
                    self.claude_command,
                    project_root,
                    prompt,
                    timeout=REPAIR_TIMEOUT,
                    log_file=repair_log,
                    monitor=True,
                    monitor_interval=15,
                )

                if repair_result.timed_out:
                    self._log(f"      Repair agent timed out")
                    continue

                # Re-check only the specific failed expectation
                fixed = exp_checker.check_one(expectations, fail.name)
                if fixed and fixed.passed:
                    self._log(f"      + Repaired: {fail.name}")
                    run.repairs.append(f"{fail.name} (attempt {attempt})")
                    repaired = True
                    break
                else:
                    detail = fixed.detail if fixed else "check not found"
                    self._log(f"      Still failing: {detail}")

            if not repaired:
                self._log(f"    ESCALATED: {fail.name} — {fail.detail}")
                run.escalations.append(f"{fail.name}: {fail.detail}")

    def _build_repair_prompt(
        self,
        fail: MilestoneResult,
        attempt: int,
        project_root: Path,
    ) -> str:
        """Build a targeted repair prompt for a specific failed expectation."""
        template_path = PROMPTS_DIR / "verify_repair.md"
        template = template_path.read_text()

        # Count commits for context
        try:
            out = subprocess.run(
                ["git", "rev-list", "--count", "HEAD"],
                capture_output=True, text=True, cwd=str(project_root),
                timeout=5,
            ).stdout.strip()
            commit_count = out if out.isdigit() else "unknown"
        except Exception:
            commit_count = "unknown"

        # Build hints based on check type
        repair_hint = self._repair_hint(fail, attempt)

        # Describe what was expected
        expectation_desc = self._expectation_description(fail)

        return template.format(
            check_name=fail.name,
            check_detail=fail.detail or "no detail",
            attempt=attempt,
            max_attempts=MAX_REPAIR_ATTEMPTS,
            expectation_description=expectation_desc,
            commit_count=commit_count,
            repair_hint=repair_hint,
        )

    @staticmethod
    def _expectation_description(fail: MilestoneResult) -> str:
        """Human-readable description of what an expectation checks."""
        name = fail.name
        if name.startswith("files_exist"):
            return f"Source files matching the pattern should exist in the project."
        if name.startswith("command_passes"):
            return f"The command should exit with code 0 (tests pass, build succeeds)."
        if name.startswith("source_contains"):
            return f"Source files should contain the expected pattern (correct framework/library used)."
        if "features_have_status" in name:
            return "Features in FEATURES.md should have reached 'shipped' status. Run `ag done F-XXXX` for completed features."
        if "plans_exist" in name:
            return "Implementation plans should exist at .agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md (dated). Run `ag plan F-XXXX` or `ag implement F-XXXX` which creates plans."
        if "plans_approved" in name:
            return "Plans should have **Status**: APPROVED. The plan review process must complete."
        if "acceptance_criteria_checked" in name:
            return "Contract/acceptance criteria files should be complete. Run `ag done` to mark features complete."
        if "journal_updated" in name:
            return "JOURNAL.md should have at least one entry. Use `bash .agentic/lib/tools/journal.sh` to add entries."
        if "commits_follow_convention" in name:
            return "Git commits should follow conventional format: feat(scope): description, fix: description, etc."
        if "no_wip_at_end" in name:
            return "No WIP.md or active AGENTS.json should remain. Run `ag done` for all features."
        return f"Expectation '{name}' should pass."

    @staticmethod
    def _repair_hint(fail: MilestoneResult, attempt: int) -> str:
        """Progressive hints — more specific guidance on later attempts."""
        name = fail.name
        hints = []

        if attempt >= 2:
            hints.append(
                "Previous repair attempt did not fix this. "
                "Try a different approach."
            )
        if attempt >= 3:
            hints.append(
                "This is the last attempt. Be thorough — check the actual "
                "file contents and state before making changes."
            )

        # Check-specific hints
        if "command_passes" in name:
            hints.append(
                "Run the command manually first to see the full error output. "
                "Common issues: missing dependencies, import errors, test failures."
            )
        elif "plans_approved" in name:
            if attempt == 1:
                hints.append(
                    "Check if plans exist but have DRAFT status. "
                    "Update the status to APPROVED in the plan file."
                )
            else:
                hints.append(
                    "Create the plan file directly at "
                    ".agentic/journal/plans/YYYY-MM-DD-F-XXXX-plan.md with "
                    "**Status**: APPROVED if the plan review is not possible."
                )
        elif "acceptance_criteria_checked" in name:
            hints.append(
                "Open .agentic/spec/contracts/F-*.yaml or .agentic/spec/acceptance/F-*.md files "
                "and mark all completed criteria."
            )
        elif "journal_updated" in name:
            hints.append(
                "Run: bash .agentic/lib/tools/journal.sh "
                '"Topic" "What was done" "Next steps" "Blockers"'
            )
        elif "features_have_status" in name:
            hints.append(
                "Run `ag done F-XXXX` for each completed feature, or "
                "update FEATURES.md status directly."
            )

        return "\n".join(hints) if hints else ""

    # -- Delivery ------------------------------------------------------------

    def create_pr(self) -> str:
        """Push VW branch and create PR. Returns PR URL or empty string."""
        if self.total_fixes == 0:
            return ""

        # Push
        push_result = subprocess.run(
            ["git", "push", "-u", "origin", self.vw_branch],
            capture_output=True, text=True,
            cwd=str(self.project_root),
        )
        if push_result.returncode != 0:
            return f"PUSH_FAILED: {push_result.stderr.strip()}"

        self._push_succeeded = True

        # Build PR body
        body_lines = ["## Framework Verification Fixes", ""]
        for i, commit in enumerate(self.fix_commits, 1):
            body_lines.append(f"{i}. {commit}")
        body_lines.extend(["", f"Total fixes: {self.total_fixes}"])

        body = "\n".join(body_lines)

        # Create PR
        pr_result = subprocess.run(
            ["gh", "pr", "create",
             "--base", "main",
             "--head", self.vw_branch,
             "--title", f"fix: framework verification fixes ({self.total_fixes} fixes)",
             "--body", body],
            capture_output=True, text=True,
            cwd=str(self.project_root),
        )
        if pr_result.returncode != 0:
            return f"PR_FAILED: {pr_result.stderr.strip()}"

        self._pr_created = True
        return pr_result.stdout.strip()

    # -- Main entry ----------------------------------------------------------

    def run(
        self,
        scenarios: list[dict[str, Any]],
    ) -> VerifyResult:
        """Run all specified scenarios and return results."""
        result = VerifyResult(success=True)

        # Pre-flight
        errors = self.pre_flight()
        if errors:
            result.success = False
            result.messages = errors
            return result

        # Create VW
        self.create_vw()

        self._log(f"Verification started")
        self._log(f"  VW branch: {self.vw_branch}")
        self._log(f"  VW path:   {self.vw_path}")
        self._log(f"  Logs:      {self.log_dir}/")
        self._log(f"  Scenarios: {len(scenarios)}")

        # Run scenarios
        for scenario in scenarios:
            for i, settings in enumerate(scenario.get("settings_matrix", [{}])):
                if self.total_fixes >= MAX_TOTAL_FIXES:
                    result.stopped_at_max_fixes = True
                    result.messages.append(
                        f"Stopped at max fixes ({MAX_TOTAL_FIXES})"
                    )
                    break

                run = self.run_scenario(scenario, settings)
                result.runs.append(run)

                if not run.success:
                    result.success = False

            if result.stopped_at_max_fixes:
                break

        # Delivery
        result.total_fixes = self.total_fixes
        result.fix_commits = self.fix_commits
        result.log_dir = str(self.log_dir)

        if self.total_fixes > 0:
            self._log(f"Delivering {self.total_fixes} fix(es) as PR...")
            pr_url = self.create_pr()
            result.pr_url = pr_url
            self._log(f"  PR: {pr_url}")

        passed = sum(1 for r in result.runs if r.success)
        total = len(result.runs)
        self._log(f"Verification complete: {passed}/{total} passed, {self.total_fixes} fixes")
        self._log(f"Logs preserved at: {self.log_dir}/")

        return result


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _summarize_failure(
    milestones: list[MilestoneResult],
    result: SpawnResult,
) -> str:
    failed = [m for m in milestones if not m.passed]
    if failed:
        return "; ".join(f"{m.name}: {m.detail}" for m in failed)
    if result.timed_out:
        return "Build agent timed out"
    if result.returncode != 0:
        return f"Build agent exited with code {result.returncode}"
    return "Unknown failure"


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def main() -> None:
    parser = argparse.ArgumentParser(
        description="Autonomous Framework Verification Loop (F-0215)"
    )
    parser.add_argument("--project-root", required=True, help="Framework repo root")
    parser.add_argument("--project", help="Run single scenario by slug name")
    parser.add_argument("--all", action="store_true", dest="run_all",
                        help="Run all scenarios")
    parser.add_argument("--settings-index", type=int, default=None,
                        help="Run specific settings combo by index")
    parser.add_argument("--json", action="store_true", dest="json_output",
                        help="Machine-readable JSON output")
    parser.add_argument("--claude-command", default="claude",
                        help="Claude CLI command (default: claude)")
    parser.add_argument("--prompt-tier", choices=["discovery", "recipe"], default=None,
                        help="Override prompt tier for all scenarios (default: per-scenario)")
    args = parser.parse_args()

    project_root = Path(args.project_root).resolve()

    if not args.project and not args.run_all:
        parser.error("Specify --project <name> or --all")

    # Load scenarios
    if args.run_all:
        scenario_names = list_scenarios()
    elif args.project:
        scenario_names = [args.project]
    else:
        scenario_names = []

    scenarios = []
    for name in scenario_names:
        try:
            scenario = load_scenario(name)
        except FileNotFoundError:
            print(f"Error: Scenario '{name}' not found", file=sys.stderr)
            print(f"Available: {', '.join(list_scenarios())}", file=sys.stderr)
            sys.exit(1)
        # Apply --prompt-tier override to all settings matrix entries
        if args.prompt_tier:
            for s in scenario.get("settings_matrix", [{}]):
                s["prompt_tier"] = args.prompt_tier
        # Filter settings matrix if index specified
        if args.settings_index is not None:
            matrix = scenario.get("settings_matrix", [{}])
            if args.settings_index >= len(matrix):
                print(
                    f"Error: --settings-index {args.settings_index} out of range "
                    f"(max {len(matrix) - 1})",
                    file=sys.stderr,
                )
                sys.exit(1)
            scenario["settings_matrix"] = [matrix[args.settings_index]]
        scenarios.append(scenario)

    # Run
    verifier = FrameworkVerifier(
        project_root,
        claude_command=args.claude_command,
        json_output=args.json_output,
    )
    result = verifier.run(scenarios)

    # Output
    if args.json_output:
        print(json.dumps(result.to_dict(), indent=2))
    else:
        _print_report(result)

    sys.exit(0 if result.success else 1)


def _print_report(result: VerifyResult) -> None:
    """Human-readable report."""
    print("\n" + "=" * 60)
    print("FRAMEWORK VERIFICATION REPORT")
    print("=" * 60)

    for run in result.runs:
        status = "PASS" if run.success else ("SKIP" if run.skipped else "FAIL")
        tier_tag = f" [{run.prompt_tier}]" if run.prompt_tier != "discovery" else ""
        print(f"\n  [{status}] {run.scenario_name} ({run.settings_label}){tier_tag}")
        if run.milestones:
            for m in run.milestones:
                icon = "+" if m.passed else "-"
                detail = f" — {m.detail}" if m.detail else ""
                print(f"    {icon} {m.name}{detail}")
        if run.behavioral_results:
            print(f"    Advisory (discovery behavior):")
            for m in run.behavioral_results:
                icon = "+" if m.passed else "~"
                detail = f" — {m.detail}" if m.detail else ""
                print(f"      {icon} {m.name}{detail}")
        if run.error:
            print(f"    Error: {run.error}")
        if run.fixes:
            print(f"    Fixes applied: {len(run.fixes)}")
        if run.repairs:
            print(f"    Repairs: {len(run.repairs)}")
            for r in run.repairs:
                print(f"      + {r}")
        if run.escalations:
            print(f"    Escalated: {len(run.escalations)}")
            for e in run.escalations:
                print(f"      ! {e}")
        if run.retries > 0:
            print(f"    Retries: {run.retries}")

    print(f"\n  Total fixes: {result.total_fixes}")
    if result.pr_url:
        print(f"  PR: {result.pr_url}")
    if result.stopped_at_max_fixes:
        print(f"  WARNING: Stopped at max fixes ({MAX_TOTAL_FIXES})")
    if result.messages:
        for msg in result.messages:
            print(f"  {msg}")
    if result.log_dir:
        print(f"  Logs: {result.log_dir}/")
    print()


if __name__ == "__main__":
    main()
