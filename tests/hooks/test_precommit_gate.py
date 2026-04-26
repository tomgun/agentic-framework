#!/usr/bin/env python3
"""
Tests for `.agentic/lib/hooks/precommit_gate.py` (R-001).

Runs under pytest or directly: `python3 tests/hooks/test_precommit_gate.py`.
The latter is the fallback for environments without pytest installed (CI mirror
images, scratch containers). Pattern mirrors `tests/test_events.py` from R-007.

Each AC from the redesign-backlog has at least two tests (happy + failure path).
The gate's subprocess calls are exercised via a fixture that provides a real
git working tree — so coverage is end-to-end, not mock-heavy.
"""
from __future__ import annotations

import inspect
import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
from pathlib import Path
from typing import Iterable, Optional

_REPO_ROOT = Path(__file__).resolve().parents[2]
_LIB_DIR = _REPO_ROOT / ".agentic" / "lib"
_HOOKS_DIR = _LIB_DIR / "hooks"

sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_HOOKS_DIR))

import precommit_gate as gate  # noqa: E402


# ---------------------------------------------------------------------------
# Test scaffolding — build a tiny git repo with the exact fixtures each test
# needs. Each test owns its own tmp dir; no shared state across tests.
# ---------------------------------------------------------------------------


def _git(repo: Path, *args: str, check: bool = True, env: Optional[dict] = None) -> str:
    full_env = os.environ.copy()
    full_env.update({
        "GIT_AUTHOR_NAME": "Test",
        "GIT_AUTHOR_EMAIL": "test@example.com",
        "GIT_COMMITTER_NAME": "Test",
        "GIT_COMMITTER_EMAIL": "test@example.com",
    })
    if env:
        full_env.update(env)
    proc = subprocess.run(
        ["git", *args],
        cwd=str(repo),
        capture_output=True,
        text=True,
        check=False,
        env=full_env,
    )
    if check and proc.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed (rc={proc.returncode}):\n{proc.stderr}"
        )
    return proc.stdout


def _init_repo(tmp_path: Path, *, profile: str = "discovery", plan_review: str = "no") -> Path:
    """Create a fresh git repo with a STACK.md, an initial commit, and the
    framework's lib/hooks/ symlinked in so the gate can locate events.py."""
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-b", "main")
    # STACK.md drives every setting the gate reads.
    stack = textwrap.dedent(f"""\
        # STACK.md

        ## Settings
        - profile: {profile}
        - plan_review_enabled: {plan_review}
        - pre_commit_hook: fast
        - test: bash -c "exit 0"
        - test_fast: bash -c "exit 0"
    """)
    (repo / "STACK.md").write_text(stack)
    # Bring in the framework lib so the gate's lazy imports work.
    agentic = repo / ".agentic"
    (agentic / "lib").mkdir(parents=True)
    (agentic / "session").mkdir()
    (agentic / "spec" / "contracts").mkdir(parents=True)
    (agentic / "journal").mkdir()
    # Symlink lib/ contents we need: events, settings, paths, ids, schemas, presets.
    for entry in ("events.py", "settings.py", "paths.py", "ids.py", "schemas", "presets"):
        src = _LIB_DIR / entry
        if not src.exists():
            continue
        dst = agentic / "lib" / entry
        if dst.exists() or dst.is_symlink():
            continue
        os.symlink(src, dst)
    # Tools dir for `ag contract check` shell-out fallback (not used in most tests).
    tools_dir = agentic / "lib" / "tools"
    tools_dir.mkdir(parents=True)
    # Stub ag.sh that exits 0 on `contract check` so AC2 passes by default.
    (tools_dir / "ag.sh").write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        if [ "$1" = "contract" ] && [ "$2" = "check" ]; then
            exit 0
        fi
        exit 0
    """))
    (tools_dir / "ag.sh").chmod(0o755)
    # Initial commit so HEAD exists.
    (repo / "README.md").write_text("test repo\n")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-m", "initial")
    return repo


def _stage(repo: Path, relpath: str, content: str) -> None:
    target = repo / relpath
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(content)
    _git(repo, "add", relpath)


def _build_ctx(repo: Path, **overrides) -> "gate.GateContext":
    ctx = gate._build_context(repo)
    for k, v in overrides.items():
        setattr(ctx, k, v)
    return ctx


# ---------------------------------------------------------------------------
# AC1 — tests run via subprocess; pass/fail/timeout/crash all observable
# ---------------------------------------------------------------------------


def test_ac1_passing_test_command_returns_pass(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_tests(ctx)
    assert not result.failed, result.detail


def test_ac1_failing_test_command_blocks_with_detail(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    # Override the test command to a failing one
    stack = (repo / "STACK.md").read_text().replace(
        '- test_fast: bash -c "exit 0"', '- test_fast: bash -c "echo FAILED 1>&2; exit 1"'
    )
    (repo / "STACK.md").write_text(stack)
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_tests(ctx)
    assert result.failed
    assert "return code: 1" in result.detail
    assert any("ag commit --skip-gate" in step for step in result.next_steps)


def test_ac1_state_only_commit_skips_tests(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    _stage(repo, ".agentic/journal/events.jsonl", '{"x":1}\n')
    ctx = _build_ctx(repo)
    result = gate.check_tests(ctx)
    assert not result.failed
    assert "skipped" in result.title.lower()


def test_ac1_no_test_command_passes_with_warning(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    # Strip test command from STACK.md
    stack = "\n".join(
        ln for ln in (repo / "STACK.md").read_text().splitlines()
        if "test_fast" not in ln and "- test:" not in ln
    )
    (repo / "STACK.md").write_text(stack)
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_tests(ctx)
    assert not result.failed
    assert "no command configured" in result.title


def test_ac1_subprocess_crash_recorded(tmp_path: Path) -> None:
    """Subprocess that fails to launch (bad shell) — gate must not raise."""
    repo = _init_repo(tmp_path)
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo, test_command="/nonexistent/binary/path")
    result = gate.check_tests(ctx)
    assert result.failed  # nonzero exit from /bin/sh wrapping unknown binary


# ---------------------------------------------------------------------------
# AC2 — `ag contract check`
# ---------------------------------------------------------------------------


def test_ac2_contract_check_pass(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    ctx = _build_ctx(repo)
    result = gate.check_contracts(ctx)
    assert not result.failed, result.detail


def test_ac2_contract_check_failure_blocks(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    # Make ag.sh fail on contract check
    ag_sh = repo / ".agentic" / "lib" / "tools" / "ag.sh"
    ag_sh.write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        if [ "$1" = "contract" ]; then
            echo "AC-001 failed: missing file" 1>&2
            exit 1
        fi
        exit 0
    """))
    ag_sh.chmod(0o755)
    ctx = _build_ctx(repo)
    result = gate.check_contracts(ctx)
    assert result.failed
    assert "ag contract migrate" in " ".join(result.next_steps)


def test_ac2_no_ag_sh_skips_check(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    (repo / ".agentic" / "lib" / "tools" / "ag.sh").unlink()
    ctx = _build_ctx(repo)
    result = gate.check_contracts(ctx)
    assert not result.failed
    assert "skipped" in result.title.lower()


# ---------------------------------------------------------------------------
# AC3 — plan-approved sentinel when plan_review_enabled
# ---------------------------------------------------------------------------


def test_ac3_blocks_when_plan_review_enabled_without_sentinel(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, plan_review="yes")
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_plan_approved(ctx)
    assert result.failed
    assert "approved plan" in result.title


def test_ac3_passes_when_sentinel_present(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, plan_review="yes")
    (repo / ".agentic" / "session" / ".plan-approved").write_text("F-001\n")
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_plan_approved(ctx)
    assert not result.failed


def test_ac3_skipped_when_plan_review_disabled(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, plan_review="no")
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_plan_approved(ctx)
    assert not result.failed
    assert "disabled" in result.title


def test_ac3_skipped_for_state_only_commits(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, plan_review="yes")
    _stage(repo, ".agentic/journal/events.jsonl", '{"x":1}\n')
    ctx = _build_ctx(repo)
    result = gate.check_plan_approved(ctx)
    assert not result.failed


# ---------------------------------------------------------------------------
# AC4 — JOURNAL.md staleness in formal+ profiles
# ---------------------------------------------------------------------------


def test_ac4_blocks_when_journal_older_than_head(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="formal")
    journal = repo / ".agentic" / "journal" / "JOURNAL.md"
    journal.write_text("# initial\n")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-m", "add journal")
    # Backdate the journal to before HEAD
    head_ts = int(_git(repo, "log", "-1", "--format=%ct").strip())
    os.utime(journal, (head_ts - 3600, head_ts - 3600))
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_journal_freshness(ctx)
    assert result.failed
    assert "JOURNAL" in result.title


def test_ac4_passes_when_journal_fresh(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="autonomous_formal")
    journal = repo / ".agentic" / "journal" / "JOURNAL.md"
    journal.write_text("# fresh\n")
    head_ts = int(_git(repo, "log", "-1", "--format=%ct").strip())
    # Touch journal to AFTER HEAD
    os.utime(journal, (head_ts + 100, head_ts + 100))
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_journal_freshness(ctx)
    assert not result.failed


def test_ac4_skipped_in_discovery_profile(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="discovery")
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_journal_freshness(ctx)
    assert not result.failed
    assert "formal" in result.title.lower()


def test_ac4_skipped_when_no_journal_present(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="formal")
    # No JOURNAL.md anywhere
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_journal_freshness(ctx)
    assert not result.failed


# ---------------------------------------------------------------------------
# AC5 — shipped + protected contracts require migration entries
# ---------------------------------------------------------------------------


_SHIPPED_CONTRACT = textwrap.dedent("""\
    id: F-001
    name: Test
    lifecycle: shipped
    profile: formal
    protection: contract
    description: |
      test
    assertions:
      - id: AC-001
        text: hello
        type: structural
        verify: |
          true
    migrations: []
""")

_SHIPPED_CONTRACT_WITH_MIG = textwrap.dedent("""\
    id: F-001
    name: Test
    lifecycle: shipped
    profile: formal
    protection: contract
    description: |
      test
    assertions:
      - id: AC-001
        text: hello again
        type: structural
        verify: |
          true
    migrations:
      - id: 2026-04-26-fix
        trigger: bug
        reason: clarify hello text
        changes: AC-001 text updated
        approved_by: test
""")


def test_ac5_blocks_shipped_contract_change_without_migration(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    contract_path = ".agentic/spec/contracts/F-001.yaml"
    (repo / contract_path).parent.mkdir(parents=True, exist_ok=True)
    (repo / contract_path).write_text(_SHIPPED_CONTRACT)
    _git(repo, "add", contract_path)
    _git(repo, "commit", "-m", "ship F-001")
    # Modify text WITHOUT adding migration entry
    modified = _SHIPPED_CONTRACT.replace("hello", "hi")
    (repo / contract_path).write_text(modified)
    _git(repo, "add", contract_path)
    ctx = _build_ctx(repo)
    result = gate.check_shipped_contract_migrations(ctx)
    assert result.failed
    assert "migration" in result.title.lower()


def test_ac5_passes_with_new_migration_entry(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    contract_path = ".agentic/spec/contracts/F-001.yaml"
    (repo / contract_path).parent.mkdir(parents=True, exist_ok=True)
    (repo / contract_path).write_text(_SHIPPED_CONTRACT)
    _git(repo, "add", contract_path)
    _git(repo, "commit", "-m", "ship F-001")
    (repo / contract_path).write_text(_SHIPPED_CONTRACT_WITH_MIG)
    _git(repo, "add", contract_path)
    ctx = _build_ctx(repo)
    result = gate.check_shipped_contract_migrations(ctx)
    assert not result.failed, result.detail


def test_ac5_skips_planned_contract_changes(tmp_path: Path) -> None:
    """Non-shipped contracts (lifecycle: planned) freely change."""
    planned = _SHIPPED_CONTRACT.replace("lifecycle: shipped", "lifecycle: planned")
    repo = _init_repo(tmp_path)
    contract_path = ".agentic/spec/contracts/F-002.yaml"
    (repo / contract_path).parent.mkdir(parents=True, exist_ok=True)
    (repo / contract_path).write_text(planned)
    _git(repo, "add", contract_path)
    _git(repo, "commit", "-m", "draft F-002")
    (repo / contract_path).write_text(planned.replace("hello", "hi"))
    _git(repo, "add", contract_path)
    ctx = _build_ctx(repo)
    result = gate.check_shipped_contract_migrations(ctx)
    assert not result.failed


def test_ac5_skips_when_no_contract_files_staged(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)
    result = gate.check_shipped_contract_migrations(ctx)
    assert not result.failed


def test_ac5_new_shipped_contract_is_allowed(tmp_path: Path) -> None:
    """First-time addition of a shipped contract has no HEAD version to migrate from."""
    repo = _init_repo(tmp_path)
    contract_path = ".agentic/spec/contracts/F-003.yaml"
    (repo / contract_path).parent.mkdir(parents=True, exist_ok=True)
    (repo / contract_path).write_text(_SHIPPED_CONTRACT.replace("F-001", "F-003"))
    _git(repo, "add", contract_path)
    ctx = _build_ctx(repo)
    result = gate.check_shipped_contract_migrations(ctx)
    assert not result.failed


# ---------------------------------------------------------------------------
# AC6 — raw `git commit` produces an informational note (not a hard block);
# AC7 — `AGENT_SKIP_GATE` env returns 0 with audit event
# ---------------------------------------------------------------------------


def test_ac6_breadcrumb_present_means_invoked_via_ag(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    breadcrumb = repo / ".agentic" / "session" / ".gate-invoked-via-ag"
    breadcrumb.write_text("via ag\n")
    ctx = _build_ctx(repo)
    result = gate.check_no_verify_breadcrumb(ctx)
    assert not result.failed
    assert "ag commit" in result.title
    # Breadcrumb should be cleaned up after observation
    assert not breadcrumb.exists()


def test_ac6_no_breadcrumb_emits_guidance_but_does_not_block(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    ctx = _build_ctx(repo)
    result = gate.check_no_verify_breadcrumb(ctx)
    assert not result.failed
    assert "raw git commit" in result.title


def test_ac7_skip_gate_env_returns_zero_and_logs_event(tmp_path: Path, monkeypatch=None) -> None:
    repo = _init_repo(tmp_path, plan_review="yes")
    _stage(repo, "src/foo.py", "x = 1\n")
    # Even with plan-approved missing, the bypass should return 0.
    events_path = repo / ".agentic" / "journal" / "events.jsonl"
    env = os.environ.copy()
    env["AGENT_SKIP_GATE"] = "1"
    env["AGENT_SKIP_GATE_REASON"] = "test bootstrap"
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "precommit_gate.py")],
        cwd=str(repo),
        capture_output=True,
        text=True,
        env=env,
        check=False,
    )
    assert proc.returncode == 0, f"stdout={proc.stdout}\nstderr={proc.stderr}"
    # Event was logged
    assert events_path.exists()
    content = events_path.read_text()
    assert "gate_skipped" in content
    assert "test bootstrap" in content


# ---------------------------------------------------------------------------
# AC8 — error messages include concrete next-step commands
# ---------------------------------------------------------------------------


def test_ac8_blocked_output_includes_next_steps(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, plan_review="yes")
    _stage(repo, "src/foo.py", "x = 1\n")
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "precommit_gate.py")],
        cwd=str(repo),
        capture_output=True,
        text=True,
        check=False,
    )
    # Plan-approved sentinel missing → AC3 blocks → exit 2
    assert proc.returncode == 2, proc.stderr
    err = proc.stderr
    assert "BLOCKED" in err
    assert "AC3" in err
    # Concrete commands appear (not just "BLOCKED")
    assert "ag plan" in err
    assert "ag commit --skip-gate" in err


def test_ac8_passing_run_returns_zero(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)  # discovery, plan_review off
    _stage(repo, ".agentic/journal/events.jsonl", '{"x":1}\n')
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "precommit_gate.py")],
        cwd=str(repo),
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0, proc.stderr


# ---------------------------------------------------------------------------
# Cross-cutting — gate emits gate_blocked event on any failure
# ---------------------------------------------------------------------------


def test_gate_blocked_event_recorded_on_failure(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, plan_review="yes")
    _stage(repo, "src/foo.py", "x = 1\n")
    events_path = repo / ".agentic" / "journal" / "events.jsonl"
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "precommit_gate.py")],
        cwd=str(repo),
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 2
    assert events_path.exists()
    saw_blocked = False
    for line in events_path.read_text().splitlines():
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("type") == "gate_blocked":
            saw_blocked = True
            assert rec["payload"]["gate"] == "precommit"
            assert any(f["ac"] == "AC3" for f in rec["payload"]["failures"])
    assert saw_blocked


def test_print_context_flag_returns_zero_and_summary(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "precommit_gate.py"), "--print-context"],
        cwd=str(repo),
        capture_output=True,
        text=True,
        check=False,
    )
    assert proc.returncode == 0
    assert "profile=" in proc.stdout
    assert "test_command=" in proc.stdout


def test_helper_count_migration_entries_handles_indented_block() -> None:
    sample = textwrap.dedent("""\
        migrations:
          - id: a
            trigger: bug
          - id: b
            trigger: bug
        other:
          - id: c
    """)
    assert gate._count_migration_entries(sample) == 2


def test_helper_is_shipped_protected_yaml_requires_both_keys() -> None:
    only_shipped = "lifecycle: shipped\n"
    only_protected = "protection: contract\n"
    both = "lifecycle: shipped\nprotection: contract\n"
    assert not gate._is_shipped_protected_yaml(only_shipped)
    assert not gate._is_shipped_protected_yaml(only_protected)
    assert gate._is_shipped_protected_yaml(both)


def test_helper_is_contract_path_matches_canonical_locations() -> None:
    assert gate._is_contract_path(".agentic/spec/contracts/F-001.yaml")
    assert gate._is_contract_path("spec/contracts/F-002.yaml")
    assert not gate._is_contract_path("docs/notes.yaml")
    assert not gate._is_contract_path(".agentic/spec/contracts/F-001.md")


# ---------------------------------------------------------------------------
# Direct-run harness (mirrors tests/test_events.py)
# ---------------------------------------------------------------------------


def _discover_tests() -> Iterable[tuple[str, callable]]:
    g = globals()
    for name in sorted(g):
        if name.startswith("test_") and callable(g[name]):
            yield name, g[name]


def _run_directly() -> int:
    failures: list[tuple[str, BaseException]] = []
    passed = 0
    for name, fn in _discover_tests():
        sig = inspect.signature(fn)
        with tempfile.TemporaryDirectory() as td:
            kwargs = {}
            if "tmp_path" in sig.parameters:
                kwargs["tmp_path"] = Path(td)
            try:
                fn(**kwargs)
            except BaseException as exc:  # noqa: BLE001
                failures.append((name, exc))
                print(f"FAIL {name}: {exc}")
            else:
                passed += 1
                print(f"PASS {name}")
    print(f"\n{passed} passed, {len(failures)} failed")
    return 0 if not failures else 1


if __name__ == "__main__":
    sys.exit(_run_directly())
