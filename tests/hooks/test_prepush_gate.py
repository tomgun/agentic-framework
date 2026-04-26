#!/usr/bin/env python3
"""
Tests for `.agentic/lib/hooks/prepush_gate.py` (R-002).

Runs under pytest or directly: `python3 tests/hooks/test_prepush_gate.py`.
Mirrors the R-001 / R-007 fixture pattern — each test owns a fresh git repo.
"""
from __future__ import annotations

import inspect
import json
import os
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

import prepush_gate as gate  # noqa: E402


# ---------------------------------------------------------------------------
# Scaffolding — same shape as test_precommit_gate.
# ---------------------------------------------------------------------------


def _git(repo: Path, *args: str, check: bool = True, env: Optional[dict] = None) -> str:
    full_env = os.environ.copy()
    full_env.update({
        "GIT_AUTHOR_NAME": "Test", "GIT_AUTHOR_EMAIL": "test@example.com",
        "GIT_COMMITTER_NAME": "Test", "GIT_COMMITTER_EMAIL": "test@example.com",
    })
    if env:
        full_env.update(env)
    proc = subprocess.run(
        ["git", *args], cwd=str(repo), capture_output=True, text=True,
        check=False, env=full_env,
    )
    if check and proc.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed (rc={proc.returncode}):\n{proc.stderr}")
    return proc.stdout


def _init_repo(tmp_path: Path, *, profile: str = "discovery",
               coverage_threshold: str = "80",
               drift_output: str = "Found 0 potential documentation drift issue(s).",
               coverage_output: str = "  Coverage:          100%",
               full_test_exit: int = 0) -> Path:
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-b", "main")
    stack = textwrap.dedent(f"""\
        # STACK.md
        ## Settings
        - profile: {profile}
        - test: bash -c "exit {full_test_exit}"
        - test_full: bash -c "exit {full_test_exit}"
        - contract_coverage_threshold: {coverage_threshold}
    """)
    (repo / "STACK.md").write_text(stack)
    agentic = repo / ".agentic"
    (agentic / "lib").mkdir(parents=True)
    (agentic / "session").mkdir()
    (agentic / "spec" / "contracts").mkdir(parents=True)
    (agentic / "journal").mkdir()
    for entry in ("events.py", "settings.py", "paths.py", "ids.py", "schemas", "presets"):
        src = _LIB_DIR / entry
        if not src.exists():
            continue
        os.symlink(src, agentic / "lib" / entry)
    # Symlink precommit_gate so prepush imports it for the migration helpers.
    os.makedirs(agentic / "lib" / "hooks", exist_ok=True)
    os.symlink(_HOOKS_DIR / "precommit_gate.py", agentic / "lib" / "hooks" / "precommit_gate.py")
    tools_dir = agentic / "lib" / "tools"
    tools_dir.mkdir(parents=True)
    # Stub ag.sh that returns deterministic coverage output.
    (tools_dir / "ag.sh").write_text(textwrap.dedent(f"""\
        #!/usr/bin/env bash
        if [ "$1" = "contract" ] && [ "$2" = "coverage" ]; then
            cat <<'OUT'
{coverage_output}
OUT
            exit 0
        fi
        exit 0
    """))
    (tools_dir / "ag.sh").chmod(0o755)
    # Stub drift.sh that emits a fixed report.
    (tools_dir / "drift.sh").write_text(textwrap.dedent(f"""\
        #!/usr/bin/env bash
        cat <<'OUT'
{drift_output}
OUT
        exit 0
    """))
    (tools_dir / "drift.sh").chmod(0o755)
    (repo / "README.md").write_text("hello\n")
    _git(repo, "add", "-A")
    _git(repo, "commit", "-m", "initial")
    return repo


def _fake_push_ranges(repo: Path, *, base: Optional[str] = None) -> str:
    """Return a stdin string for the pre-push hook with a single range from
    `base` (defaults to HEAD~1 if available, else HEAD) to HEAD."""
    head = _git(repo, "rev-parse", "HEAD").strip()
    if base is None:
        # Try HEAD~1; fall back to ZERO_OID for "create branch" semantics.
        try:
            base = _git(repo, "rev-parse", "HEAD~1", check=True).strip()
        except RuntimeError:
            base = gate._ZERO_OID
    return f"refs/heads/main {head} refs/heads/main {base}\n"


def _build_ctx(repo: Path, **overrides) -> "gate.GateContext":
    ctx = gate._build_context(repo)
    for k, v in overrides.items():
        setattr(ctx, k, v)
    return ctx


# ---------------------------------------------------------------------------
# AC2 — full test suite
# ---------------------------------------------------------------------------


def test_ac2_passing_full_test_suite(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, full_test_exit=0)
    ctx = _build_ctx(repo)
    result = gate.check_full_tests(ctx)
    assert not result.failed, result.detail


def test_ac2_failing_full_test_suite_blocks(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, full_test_exit=1)
    ctx = _build_ctx(repo)
    result = gate.check_full_tests(ctx)
    assert result.failed
    assert "return code: 1" in result.detail


def test_ac2_no_test_command_skips(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    stack = (repo / "STACK.md").read_text().replace(
        '- test: bash -c "exit 0"', "").replace(
        '- test_full: bash -c "exit 0"', "")
    (repo / "STACK.md").write_text(stack)
    ctx = _build_ctx(repo)
    result = gate.check_full_tests(ctx)
    assert not result.failed
    assert "no command" in result.title


# ---------------------------------------------------------------------------
# AC3 — coverage threshold
# ---------------------------------------------------------------------------


def test_ac3_coverage_above_threshold_passes(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, coverage_threshold="80",
                      coverage_output="  Coverage:          92%")
    ctx = _build_ctx(repo)
    result = gate.check_contract_coverage(ctx)
    assert not result.failed
    assert "92" in result.title


def test_ac3_coverage_below_threshold_blocks(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, coverage_threshold="80",
                      coverage_output="  Coverage:          55%")
    ctx = _build_ctx(repo)
    result = gate.check_contract_coverage(ctx)
    assert result.failed
    assert "55" in result.title


def test_ac3_unparseable_coverage_advisory_pass(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, coverage_output="some other format here")
    ctx = _build_ctx(repo)
    result = gate.check_contract_coverage(ctx)
    assert not result.failed
    assert "advisory" in result.title or "unparseable" in result.title


def test_ac3_decimal_coverage_parses(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, coverage_threshold="80",
                      coverage_output="  Coverage:          80.5%")
    ctx = _build_ctx(repo)
    result = gate.check_contract_coverage(ctx)
    assert not result.failed


# ---------------------------------------------------------------------------
# AC4 — drift.sh --docs in formal+
# ---------------------------------------------------------------------------


def test_ac4_drift_zero_passes_in_formal(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="formal",
                      drift_output="Found 0 potential documentation drift issue(s).")
    ctx = _build_ctx(repo)
    result = gate.check_doc_drift(ctx)
    assert not result.failed


def test_ac4_drift_nonzero_blocks_in_formal(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="autonomous_formal",
                      drift_output="Found 3 potential documentation drift issue(s).")
    ctx = _build_ctx(repo)
    result = gate.check_doc_drift(ctx)
    assert result.failed
    assert "3 doc" in result.title


def test_ac4_drift_skipped_in_discovery(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="discovery",
                      drift_output="Found 5 potential documentation drift issue(s).")
    ctx = _build_ctx(repo)
    result = gate.check_doc_drift(ctx)
    assert not result.failed
    assert "formal" in result.title.lower()


# ---------------------------------------------------------------------------
# AC5 — migration check across full pushed range
# ---------------------------------------------------------------------------


_SHIPPED = textwrap.dedent("""\
    id: F-100
    name: Range Test
    lifecycle: shipped
    profile: formal
    protection: contract
    description: |
      test
    assertions:
      - id: AC-001
        text: hi
        type: structural
        verify: |
          true
    migrations: []
""")

_SHIPPED_V2 = _SHIPPED.replace("hi", "hello")  # changed without migration

_SHIPPED_V2_WITH_MIG = textwrap.dedent("""\
    id: F-100
    name: Range Test
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
    migrations:
      - id: 2026-04-26-rename
        trigger: improvement
        reason: clarity
        changes: AC-001 text
        approved_by: test
""")


def _seed_shipped_contract(repo: Path, path: str = ".agentic/spec/contracts/F-100.yaml") -> str:
    full = repo / path
    full.parent.mkdir(parents=True, exist_ok=True)
    full.write_text(_SHIPPED)
    _git(repo, "add", path)
    _git(repo, "commit", "-m", "ship F-100")
    return _git(repo, "rev-parse", "HEAD").strip()


def test_ac5_blocks_when_range_includes_unmigrated_change(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    base = _seed_shipped_contract(repo)
    # Modify shipped contract WITHOUT migration entry; commit
    (repo / ".agentic/spec/contracts/F-100.yaml").write_text(_SHIPPED_V2)
    _git(repo, "add", ".agentic/spec/contracts/F-100.yaml")
    _git(repo, "commit", "-m", "tweak F-100 text")
    head = _git(repo, "rev-parse", "HEAD").strip()
    ctx = _build_ctx(repo, push_ranges=[gate.PushRange(
        local_ref="refs/heads/main", local_oid=head,
        remote_ref="refs/heads/main", remote_oid=base,
    )])
    result = gate.check_range_migrations(ctx)
    assert result.failed
    assert "F-100" in result.detail


def test_ac5_passes_when_migration_added(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    base = _seed_shipped_contract(repo)
    (repo / ".agentic/spec/contracts/F-100.yaml").write_text(_SHIPPED_V2_WITH_MIG)
    _git(repo, "add", ".agentic/spec/contracts/F-100.yaml")
    _git(repo, "commit", "-m", "rename + migrate F-100")
    head = _git(repo, "rev-parse", "HEAD").strip()
    ctx = _build_ctx(repo, push_ranges=[gate.PushRange(
        local_ref="refs/heads/main", local_oid=head,
        remote_ref="refs/heads/main", remote_oid=base,
    )])
    result = gate.check_range_migrations(ctx)
    assert not result.failed, result.detail


def test_ac5_skips_for_branch_deletion(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    head = _git(repo, "rev-parse", "HEAD").strip()
    ctx = _build_ctx(repo, push_ranges=[gate.PushRange(
        local_ref="refs/heads/main", local_oid=gate._ZERO_OID,
        remote_ref="refs/heads/main", remote_oid=head,
    )])
    result = gate.check_range_migrations(ctx)
    assert not result.failed


def test_ac5_skips_when_no_ranges_provided(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    ctx = _build_ctx(repo, push_ranges=[])
    result = gate.check_range_migrations(ctx)
    assert not result.failed


# ---------------------------------------------------------------------------
# AC6 — breadcrumb / informational note
# ---------------------------------------------------------------------------


def test_ac6_breadcrumb_present_means_via_ag(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    breadcrumb = repo / ".agentic" / "session" / ".push-invoked-via-ag"
    breadcrumb.write_text("via ag\n")
    ctx = _build_ctx(repo)
    result = gate.check_push_breadcrumb(ctx)
    assert not result.failed
    assert "ag push" in result.title
    assert not breadcrumb.exists()  # cleaned up after observation


def test_ac6_no_breadcrumb_emits_note(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    ctx = _build_ctx(repo)
    result = gate.check_push_breadcrumb(ctx)
    assert not result.failed
    assert "raw git push" in result.title


# ---------------------------------------------------------------------------
# Top-level — bypass env, push_attempt event
# ---------------------------------------------------------------------------


def test_skip_gate_env_returns_zero_and_records_event(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="autonomous_formal", full_test_exit=1)
    events_path = repo / ".agentic" / "journal" / "events.jsonl"
    env = os.environ.copy()
    env["AGENT_SKIP_GATE"] = "1"
    env["AGENT_SKIP_GATE_REASON"] = "test bypass"
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "prepush_gate.py"), "origin", "https://example.com"],
        cwd=str(repo), capture_output=True, text=True, env=env, check=False,
    )
    assert proc.returncode == 0
    # gate_skipped + push_attempt both written
    content = events_path.read_text()
    assert "gate_skipped" in content
    assert "push_attempt" in content
    assert "test bypass" in content


def test_push_attempt_event_recorded_on_success(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="discovery")
    events_path = repo / ".agentic" / "journal" / "events.jsonl"
    head = _git(repo, "rev-parse", "HEAD").strip()
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "prepush_gate.py"), "origin", "https://example.com"],
        cwd=str(repo), capture_output=True, text=True, check=False,
        input=f"refs/heads/main {head} refs/heads/main {gate._ZERO_OID}\n",
    )
    assert proc.returncode == 0, proc.stderr
    seen_push = False
    for line in events_path.read_text().splitlines():
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("type") == "push_attempt":
            seen_push = True
            assert rec["payload"]["blocked"] is False
    assert seen_push


def test_push_attempt_event_recorded_on_block(tmp_path: Path) -> None:
    """Even when blocked, push_attempt is recorded (AC7)."""
    repo = _init_repo(tmp_path, profile="autonomous_formal", full_test_exit=1)
    events_path = repo / ".agentic" / "journal" / "events.jsonl"
    head = _git(repo, "rev-parse", "HEAD").strip()
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "prepush_gate.py"), "origin", "https://example.com"],
        cwd=str(repo), capture_output=True, text=True, check=False,
        input=f"refs/heads/main {head} refs/heads/main {gate._ZERO_OID}\n",
    )
    assert proc.returncode == 2
    seen_push = False
    seen_blocked = False
    for line in events_path.read_text().splitlines():
        try:
            rec = json.loads(line)
        except json.JSONDecodeError:
            continue
        if rec.get("type") == "push_attempt":
            seen_push = True
            assert rec["payload"]["blocked"] is True
        elif rec.get("type") == "gate_blocked":
            seen_blocked = True
    assert seen_push and seen_blocked


def test_print_context_flag_works(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "prepush_gate.py"), "--print-context"],
        cwd=str(repo), capture_output=True, text=True, check=False,
    )
    assert proc.returncode == 0
    assert "coverage_threshold=" in proc.stdout
    assert "test_command=" in proc.stdout


def test_blocked_output_includes_skip_gate_hint(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, profile="autonomous_formal", full_test_exit=1)
    head = _git(repo, "rev-parse", "HEAD").strip()
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "prepush_gate.py"), "origin", "https://example.com"],
        cwd=str(repo), capture_output=True, text=True, check=False,
        input=f"refs/heads/main {head} refs/heads/main {gate._ZERO_OID}\n",
    )
    assert proc.returncode == 2
    err = proc.stderr
    assert "BLOCKED" in err
    assert "ag push --skip-gate" in err


def test_helper_push_range_classifies_create_and_delete() -> None:
    pr = gate.PushRange("refs/heads/x", "abc123", "refs/heads/x", gate._ZERO_OID)
    assert pr.is_create and not pr.is_delete
    pr2 = gate.PushRange("refs/heads/x", gate._ZERO_OID, "refs/heads/x", "abc123")
    assert pr2.is_delete and not pr2.is_create
    pr3 = gate.PushRange("refs/heads/x", "abc123", "refs/heads/x", "def456")
    assert pr3.commit_range == "def456..abc123"


# ---------------------------------------------------------------------------
# Direct-run harness
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
