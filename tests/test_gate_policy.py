#!/usr/bin/env python3
"""
Tests for the hooks-first policy engine (gate.py) — F-0244, F-0245, F-0246.

Covers:
- Active feature resolution (AGENTS.json, STATUS.md, BACKLOG.json)
- Stop gate (enforcement vs advisory by profile)
- PreToolUse gate (destructive git blocking, spec-first enforcement)
- Verify gate (full verification)
- Tool name normalization
"""
import json
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent.parent / ".agentic" / "lib"))

from gate import (
    GateResult,
    resolve_active_feature,
    check_feature_has_spec,
    check_feature_has_ac,
    check_feature_has_tests,
    gate_stop,
    gate_pretool,
    gate_verify,
    normalize_tool_name,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def project_dir():
    """Temporary project with basic agentic structure."""
    with tempfile.TemporaryDirectory() as tmpdir:
        root = Path(tmpdir)
        (root / ".agentic" / "lib").mkdir(parents=True)
        (root / ".agentic" / "spec" / "acceptance").mkdir(parents=True)
        (root / ".agentic" / "session").mkdir(parents=True)
        (root / ".agentic" / "journal" / "plans").mkdir(parents=True)
        (root / "tests").mkdir(parents=True)

        # Copy paths.py and settings.py for path resolution
        lib_src = Path(__file__).parent.parent / ".agentic" / "lib"
        for f in ["paths.py", "settings.py", "ids.sh"]:
            src = lib_src / f
            if src.exists():
                (root / ".agentic" / "lib" / f).write_text(src.read_text())

        # Default discovery profile
        (root / "STACK.md").write_text("## Settings\n- profile: discovery\n")

        # FEATURES.md with test feature
        (root / ".agentic" / "spec" / "FEATURES.md").write_text("""# Features

## F-0042: Test Feature

**Status**: implementing
**Category**: Test

**Description**: A test feature for gate testing.
""")

        # AC file for F-0042
        (root / ".agentic" / "spec" / "acceptance" / "F-0042.md").write_text("""# F-0042 Acceptance Criteria

## Criteria

- [ ] **AC-001**: Feature works correctly
- [ ] **AC-002**: Tests pass

## Verification

- **Automated**: `echo "test passed"`
""")

        # Test file referencing F-0042
        (root / "tests" / "test_f0042.py").write_text(
            '"""Tests for F-0042."""\ndef test_feature(): pass\n'
        )

        # Empty AGENTS.json
        (root / ".agentic" / "session" / "AGENTS.json").write_text("[]")

        yield root


@pytest.fixture
def formal_project(project_dir):
    """Project with formal profile."""
    (project_dir / "STACK.md").write_text(
        "## Settings\n- profile: formal\n"
    )
    return project_dir


# ---------------------------------------------------------------------------
# Tool name normalization — F-0246
# ---------------------------------------------------------------------------

class TestToolNameNormalization:
    def test_shell_to_bash(self):
        assert normalize_tool_name("Shell") == "Bash"

    def test_already_normalized(self):
        assert normalize_tool_name("Bash") == "Bash"
        assert normalize_tool_name("Read") == "Read"

    def test_unknown_passthrough(self):
        assert normalize_tool_name("CustomTool") == "CustomTool"


# ---------------------------------------------------------------------------
# Active feature resolution — F-0246
# ---------------------------------------------------------------------------

class TestResolveActiveFeature:
    def test_no_feature_found(self, project_dir):
        """Discovery mode: no feature in any source."""
        # Empty STATUS.md, empty AGENTS.json, no BACKLOG.json
        (project_dir / "STATUS.md").write_text("# Status\n\nNothing active\n")
        result = resolve_active_feature(project_dir)
        assert result is None

    def test_from_status_md(self, project_dir):
        """Resolves feature from STATUS.md focus line."""
        (project_dir / "STATUS.md").write_text(
            "# Status\n\n🎯 Focus: F-0042 implementation\n"
        )
        result = resolve_active_feature(project_dir)
        assert result == "F-0042"

    def test_from_agents_json(self, project_dir):
        """Resolves feature from AGENTS.json active agent."""
        import os
        agents_data = [
            {"pid": os.getppid(), "feature": "F-0099", "status": "active"}
        ]
        (project_dir / ".agentic" / "session" / "AGENTS.json").write_text(
            json.dumps(agents_data)
        )
        result = resolve_active_feature(project_dir)
        assert result == "F-0099"

    def test_from_backlog(self, project_dir):
        """Resolves feature from BACKLOG.json position 0."""
        backlog = [{"id": "F-0077", "name": "Next feature"}]
        (project_dir / ".agentic" / "BACKLOG.json").write_text(
            json.dumps(backlog)
        )
        result = resolve_active_feature(project_dir)
        assert result == "F-0077"

    def test_agents_json_takes_priority(self, project_dir):
        """AGENTS.json is checked before STATUS.md."""
        import os
        agents_data = [
            {"pid": os.getppid(), "feature": "F-0099", "status": "active"}
        ]
        (project_dir / ".agentic" / "session" / "AGENTS.json").write_text(
            json.dumps(agents_data)
        )
        (project_dir / "STATUS.md").write_text("Focus: F-0042\n")
        result = resolve_active_feature(project_dir)
        assert result == "F-0099"


# ---------------------------------------------------------------------------
# Individual gate checks — F-0245
# ---------------------------------------------------------------------------

class TestCheckFeatureHasSpec:
    def test_feature_exists(self, project_dir):
        result = check_feature_has_spec("F-0042", project_dir)
        assert result.decision == "allow"

    def test_feature_missing(self, project_dir):
        result = check_feature_has_spec("F-9999", project_dir)
        assert result.decision == "deny"
        assert "not found" in result.reasons[0]


class TestCheckFeatureHasAC:
    def test_ac_exists(self, project_dir):
        result = check_feature_has_ac("F-0042", project_dir)
        assert result.decision == "allow"

    def test_ac_missing(self, project_dir):
        result = check_feature_has_ac("F-9999", project_dir)
        assert result.decision == "deny"
        assert "acceptance criteria" in result.reasons[0].lower()

    def test_ac_empty(self, project_dir):
        """AC file exists but has no AC lines."""
        (project_dir / ".agentic" / "spec" / "acceptance" / "F-9998.md").write_text(
            "# F-9998\n\nNo criteria here\n"
        )
        result = check_feature_has_ac("F-9998", project_dir)
        assert result.decision == "deny"


class TestCheckFeatureHasTests:
    def test_tests_exist(self, project_dir):
        result = check_feature_has_tests("F-0042", project_dir)
        assert result.decision == "allow"

    def test_tests_missing(self, project_dir):
        result = check_feature_has_tests("F-9999", project_dir)
        assert result.decision == "deny"
        assert "No test files" in result.reasons[0]


# ---------------------------------------------------------------------------
# Stop gate — F-0245
# ---------------------------------------------------------------------------

class TestGateStop:
    def test_discovery_always_allows(self, project_dir):
        """Discovery profile: stop gate is advisory only."""
        result = gate_stop("F-0042", project_dir)
        assert result.decision == "allow"

    def test_discovery_missing_feature_warns(self, project_dir):
        """Discovery profile: missing artifacts become warnings, not blocks."""
        result = gate_stop("F-9999", project_dir)
        assert result.decision == "allow"
        # Missing artifacts should be in warnings
        assert any("F-9999" in w for w in result.warnings)

    def test_formal_blocks_missing_ac(self, formal_project):
        """Formal profile: missing AC blocks stop."""
        # F-9999 has no spec, no AC, no tests
        (formal_project / ".agentic" / "spec" / "FEATURES.md").write_text("""# Features

## F-9999: Incomplete Feature

**Status**: implementing
**Description**: Missing everything.
""")
        result = gate_stop("F-9999", formal_project)
        assert result.decision == "deny"
        assert any("acceptance criteria" in r.lower() for r in result.reasons)

    def test_formal_allows_complete_feature(self, formal_project):
        """Formal profile: feature with spec+AC+tests allows stop."""
        result = gate_stop("F-0042", formal_project)
        assert result.decision == "allow"

    def test_no_feature_allows(self, project_dir):
        """No active feature (discovery mode): stop always allowed."""
        result = gate_stop(None, project_dir)
        assert result.decision == "allow"


# ---------------------------------------------------------------------------
# PreToolUse gate — F-0246
# ---------------------------------------------------------------------------

class TestGatePreToolUse:
    def test_blocks_git_reset_hard(self, project_dir):
        """Destructive git ops blocked in any profile."""
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git reset --hard HEAD"}')
        assert result.decision == "deny"
        assert "destructive" in result.reasons[0].lower()

    def test_blocks_git_stash(self, project_dir):
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git stash"}')
        assert result.decision == "deny"

    def test_blocks_git_checkout_dot(self, project_dir):
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git checkout -- ."}')
        assert result.decision == "deny"

    def test_blocks_git_restore_dot(self, project_dir):
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git restore ."}')
        assert result.decision == "deny"

    def test_blocks_git_clean(self, project_dir):
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git clean -fd"}')
        assert result.decision == "deny"

    def test_blocks_git_push_force(self, project_dir):
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git push --force origin main"}')
        assert result.decision == "deny"

    def test_blocks_git_push_f(self, project_dir):
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git push -f origin main"}')
        assert result.decision == "deny"

    def test_blocks_git_checkout_dash_dash_dir(self, project_dir):
        """Broader pattern: blocks checkout -- with any path, not just dot."""
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git checkout -- src/"}')
        assert result.decision == "deny"

    def test_allows_git_restore_staged(self, project_dir):
        """git restore --staged is safe (unstaging, not discarding)."""
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git restore --staged file.py"}')
        assert result.decision == "allow"

    def test_allows_safe_bash(self, project_dir):
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "ls -la"}')
        assert result.decision == "allow"

    def test_allows_git_status(self, project_dir):
        result = gate_pretool(None, project_dir, "Bash",
                             '{"command": "git status"}')
        assert result.decision == "allow"

    def test_formal_blocks_commit_without_spec(self, formal_project):
        """Formal profile: git commit blocked when feature lacks artifacts."""
        result = gate_pretool("F-9999", formal_project, "Bash",
                             '{"command": "git commit -m \\"test\\""}')
        assert result.decision == "deny"
        assert "git commit blocked" in result.reasons[0].lower()

    def test_formal_allows_commit_with_spec(self, formal_project):
        """Formal profile: git commit allowed when feature has artifacts."""
        result = gate_pretool("F-0042", formal_project, "Bash",
                             '{"command": "git commit -m \\"test\\""}')
        assert result.decision == "allow"

    def test_formal_blocks_code_edit_without_spec(self, formal_project):
        """Formal profile: code edits blocked when feature lacks spec."""
        # Add F-9999 to FEATURES.md but no AC
        (formal_project / ".agentic" / "spec" / "FEATURES.md").write_text("""# Features

## F-9999: No Spec Feature

**Status**: implementing
**Description**: Missing AC.
""")
        result = gate_pretool("F-9999", formal_project, "Write",
                             '{"file_path": "src/main.py"}')
        assert result.decision == "deny"
        assert "code edit blocked" in result.reasons[0].lower()

    def test_formal_allows_test_file_edits(self, formal_project):
        """Formal profile: test file edits always allowed."""
        result = gate_pretool("F-9999", formal_project, "Write",
                             '{"file_path": "tests/test_foo.py"}')
        assert result.decision == "allow"

    def test_formal_allows_markdown_edits(self, formal_project):
        """Formal profile: markdown edits always allowed."""
        result = gate_pretool("F-9999", formal_project, "Write",
                             '{"file_path": "README.md"}')
        assert result.decision == "allow"

    def test_normalizes_shell_to_bash(self, project_dir):
        """Cursor's 'Shell' tool name is normalized to 'Bash'."""
        result = gate_pretool(None, project_dir, "Shell",
                             '{"command": "git reset --hard"}')
        assert result.decision == "deny"

    def test_discovery_allows_commit(self, project_dir):
        """Discovery profile: git commit not blocked."""
        result = gate_pretool("F-9999", project_dir, "Bash",
                             '{"command": "git commit -m \\"test\\""}')
        assert result.decision == "allow"


# ---------------------------------------------------------------------------
# Verify gate — F-0245
# ---------------------------------------------------------------------------

class TestGateVerify:
    def test_no_feature_denies(self, project_dir):
        result = gate_verify(None, project_dir)
        assert result.decision == "deny"

    def test_complete_feature_allows(self, project_dir):
        result = gate_verify("F-0042", project_dir)
        assert result.decision == "allow"

    def test_missing_ac_denies(self, project_dir):
        result = gate_verify("F-9999", project_dir)
        assert result.decision == "deny"


# ---------------------------------------------------------------------------
# GateResult operations
# ---------------------------------------------------------------------------

class TestGateResult:
    def test_allow(self):
        r = GateResult.allow()
        assert r.decision == "allow"
        assert r.reasons == []

    def test_deny(self):
        r = GateResult.deny(["reason1"])
        assert r.decision == "deny"
        assert r.reasons == ["reason1"]

    def test_merge_allow_allow(self):
        r1 = GateResult.allow(["warn1"])
        r2 = GateResult.allow(["warn2"])
        merged = r1.merge(r2)
        assert merged.decision == "allow"
        assert merged.warnings == ["warn1", "warn2"]

    def test_merge_allow_deny(self):
        r1 = GateResult.allow()
        r2 = GateResult.deny(["blocked"])
        merged = r1.merge(r2)
        assert merged.decision == "deny"
        assert merged.reasons == ["blocked"]

    def test_to_json(self):
        r = GateResult.deny(["reason"], ["warning"])
        j = json.loads(r.to_json())
        assert j["decision"] == "deny"
        assert j["reasons"] == ["reason"]
        assert j["warnings"] == ["warning"]


# ---------------------------------------------------------------------------
# CLI smoke test — F-0245
# ---------------------------------------------------------------------------

class TestCLI:
    def test_stop_gate_cli(self, project_dir):
        """ag gate stop runs without errors."""
        import subprocess
        result = subprocess.run(
            [sys.executable, "-m", "gate", "stop",
             "--feature", "F-0042", "--project-root", str(project_dir)],
            capture_output=True, text=True,
            env={"PYTHONPATH": str(Path(__file__).parent.parent / ".agentic" / "lib"),
                 "PATH": "/usr/bin:/bin"},
        )
        assert result.returncode == 0
        output = json.loads(result.stdout)
        assert output["decision"] == "allow"

    def test_pretool_gate_cli(self, project_dir):
        """ag gate pretool runs without errors."""
        import subprocess
        result = subprocess.run(
            [sys.executable, "-m", "gate", "pretool",
             "--tool", "Bash", "--input", '{"command": "ls"}',
             "--project-root", str(project_dir)],
            capture_output=True, text=True,
            env={"PYTHONPATH": str(Path(__file__).parent.parent / ".agentic" / "lib"),
                 "PATH": "/usr/bin:/bin"},
        )
        assert result.returncode == 0
        output = json.loads(result.stdout)
        assert output["decision"] == "allow"

    def test_pretool_blocks_destructive(self, project_dir):
        """ag gate pretool blocks destructive git ops via CLI."""
        import subprocess
        result = subprocess.run(
            [sys.executable, "-m", "gate", "pretool",
             "--tool", "Bash", "--input", '{"command": "git reset --hard"}',
             "--project-root", str(project_dir)],
            capture_output=True, text=True,
            env={"PYTHONPATH": str(Path(__file__).parent.parent / ".agentic" / "lib"),
                 "PATH": "/usr/bin:/bin"},
        )
        assert result.returncode == 2  # deny
        output = json.loads(result.stdout)
        assert output["decision"] == "deny"
