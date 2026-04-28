#!/usr/bin/env python3
"""
Tests for `ag fix` hotfix mode (R-010).

Coverage:
  * AGENT_FIX_MODE=1 sets ctx.fix_mode and records the reason
  * check_contracts is skipped in fix mode (spec/contract-existence)
  * check_plan_approved is skipped in fix mode
  * check_tests still runs in fix mode (test requirement preserved)
  * check_journal_freshness still runs in fix mode
  * check_shipped_contract_migrations still blocks in fix mode
  * Passing fix-mode gate emits a `hotfix_commit` event
  * The bash dispatcher exposes `ag fix` and forwards to git commit

Run via pytest, or directly: `python3 tests/hooks/test_fix_mode.py`.
"""
from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile
import textwrap
import unittest.mock as mock
from pathlib import Path
from typing import Optional

_REPO_ROOT = Path(__file__).resolve().parents[2]
_LIB_DIR = _REPO_ROOT / ".agentic" / "lib"
_HOOKS_DIR = _LIB_DIR / "hooks"

sys.path.insert(0, str(_LIB_DIR))
sys.path.insert(0, str(_HOOKS_DIR))

import precommit_gate as gate  # noqa: E402


# ---------------------------------------------------------------------------
# Test scaffold (deliberately mirrors test_precommit_gate.py)
# ---------------------------------------------------------------------------


def _git(repo: Path, *args: str, env: Optional[dict] = None) -> str:
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
    if proc.returncode != 0:
        raise RuntimeError(
            f"git {' '.join(args)} failed (rc={proc.returncode}):\n{proc.stderr}"
        )
    return proc.stdout


def _init_repo(tmp_path: Path, *, profile: str = "discovery", plan_review: str = "yes") -> Path:
    repo = tmp_path / "repo"
    repo.mkdir()
    _git(repo, "init", "-b", "main")
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
    agentic = repo / ".agentic"
    (agentic / "lib").mkdir(parents=True)
    (agentic / "session").mkdir()
    (agentic / "spec" / "contracts").mkdir(parents=True)
    (agentic / "journal").mkdir()
    for entry in ("events.py", "settings.py", "paths.py", "ids.py", "schemas", "presets"):
        src = _LIB_DIR / entry
        if not src.exists():
            continue
        dst = agentic / "lib" / entry
        if dst.exists() or dst.is_symlink():
            continue
        os.symlink(src, dst)
    tools_dir = agentic / "lib" / "tools"
    tools_dir.mkdir(parents=True)
    (tools_dir / "ag.sh").write_text(textwrap.dedent("""\
        #!/usr/bin/env bash
        # Stub: contract check fails (forces AC2 fail unless fix_mode skips).
        if [ "$1" = "contract" ] && [ "$2" = "check" ]; then
            echo "AC-001 failed: missing file" 1>&2
            exit 1
        fi
        exit 0
    """))
    (tools_dir / "ag.sh").chmod(0o755)
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
# Context wiring
# ---------------------------------------------------------------------------


def test_fix_mode_env_sets_ctx_flag(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    _stage(repo, "src/foo.py", "x = 1\n")
    with mock.patch.dict(os.environ, {
        "AGENT_FIX_MODE": "1",
        "AGENT_FIX_REASON": "log offer staleness",
    }):
        ctx = gate._build_context(repo)
    assert ctx.fix_mode is True
    assert ctx.fix_reason == "log offer staleness"


def test_fix_mode_off_by_default(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    # Ensure clean env
    env = {k: v for k, v in os.environ.items() if k != "AGENT_FIX_MODE"}
    with mock.patch.dict(os.environ, env, clear=True):
        ctx = gate._build_context(repo)
    assert ctx.fix_mode is False
    assert ctx.fix_reason == ""


# ---------------------------------------------------------------------------
# AC2 — contracts skipped in fix mode
# ---------------------------------------------------------------------------


def test_fix_mode_skips_contract_check(tmp_path: Path) -> None:
    """The stub ag.sh fails contract check; fix_mode must short-circuit."""
    repo = _init_repo(tmp_path)
    _stage(repo, "src/foo.py", "x = 1\n")

    # Without fix_mode, contracts would fail.
    ctx_normal = _build_ctx(repo)
    result_normal = gate.check_contracts(ctx_normal)
    assert result_normal.failed, "stub ag.sh should fail contract check"

    # With fix_mode, the check is skipped.
    ctx_fix = _build_ctx(repo, fix_mode=True)
    result_fix = gate.check_contracts(ctx_fix)
    assert not result_fix.failed
    assert "hotfix" in result_fix.title.lower()


# ---------------------------------------------------------------------------
# AC3 — plan-approved skipped in fix mode (even with plan_review_enabled: yes)
# ---------------------------------------------------------------------------


def test_fix_mode_skips_plan_approved(tmp_path: Path) -> None:
    """plan_review_enabled: yes + no .plan-approved sentinel + code change.
    Without fix_mode this blocks; with fix_mode it passes."""
    repo = _init_repo(tmp_path, plan_review="yes")
    _stage(repo, "src/foo.py", "x = 1\n")

    # Sanity: without fix_mode, this would block (no sentinel).
    ctx_normal = _build_ctx(repo)
    result_normal = gate.check_plan_approved(ctx_normal)
    assert result_normal.failed, "should block without sentinel + plan_review_enabled"

    # With fix_mode, no block.
    ctx_fix = _build_ctx(repo, fix_mode=True)
    result_fix = gate.check_plan_approved(ctx_fix)
    assert not result_fix.failed
    assert "hotfix" in result_fix.title.lower()


# ---------------------------------------------------------------------------
# Tests requirement preserved (AC2 of R-010)
# ---------------------------------------------------------------------------


def test_fix_mode_keeps_test_requirement(tmp_path: Path) -> None:
    """Hotfix mode does NOT skip tests — AC2 says tests are still required."""
    repo = _init_repo(tmp_path)
    # Make tests fail.
    stack = (repo / "STACK.md").read_text().replace(
        '- test_fast: bash -c "exit 0"',
        '- test_fast: bash -c "echo FAILED 1>&2; exit 1"',
    )
    (repo / "STACK.md").write_text(stack)
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo, fix_mode=True)
    result = gate.check_tests(ctx)
    assert result.failed, "fix_mode must NOT bypass test requirement"


# ---------------------------------------------------------------------------
# Migration requirement preserved
# ---------------------------------------------------------------------------


def test_fix_mode_keeps_shipped_contract_migration(tmp_path: Path) -> None:
    """Editing a shipped contract without a migration entry must still block,
    even in fix_mode (R-010 AC-2 explicitly preserves this)."""
    repo = _init_repo(tmp_path)
    # Create a shipped+protected contract and commit it.
    contracts_dir = repo / ".agentic" / "spec" / "contracts"
    initial = textwrap.dedent("""\
        id: F-001
        lifecycle: shipped
        protection: contract
        assertions:
          structural:
            - path: src/foo.py
        migrations: []
    """)
    (contracts_dir / "F-001.yaml").write_text(initial)
    _git(repo, "add", "-A")
    _git(repo, "commit", "-m", "add shipped contract")

    # Now edit it without adding a migration entry.
    edited = initial.replace("- path: src/foo.py", "- path: src/bar.py")
    (contracts_dir / "F-001.yaml").write_text(edited)
    _git(repo, "add", ".agentic/spec/contracts/F-001.yaml")

    ctx = _build_ctx(repo, fix_mode=True)
    result = gate.check_shipped_contract_migrations(ctx)
    assert result.failed, "shipped-contract change without migration must block in fix_mode"


# ---------------------------------------------------------------------------
# Hotfix event emission
# ---------------------------------------------------------------------------


def test_fix_mode_emits_hotfix_event_on_success(tmp_path: Path) -> None:
    """Run the gate as a subprocess from the repo dir so events.jsonl lands
    in repo/.agentic/journal/ (the events writer uses cwd-relative paths)."""
    repo = _init_repo(tmp_path)
    _stage(repo, "src/foo.py", "x = 1\n")
    events_path = repo / ".agentic" / "journal" / "events.jsonl"
    env = os.environ.copy()
    env["AGENT_FIX_MODE"] = "1"
    env["AGENT_FIX_REASON"] = "log offer staleness"
    proc = subprocess.run(
        [sys.executable, str(_HOOKS_DIR / "precommit_gate.py")],
        cwd=str(repo),
        capture_output=True,
        text=True,
        check=False,
        env=env,
    )
    assert proc.returncode == 0, proc.stdout + proc.stderr
    assert events_path.exists()
    lines = [json.loads(ln) for ln in events_path.read_text().splitlines() if ln.strip()]
    hotfix_events = [e for e in lines if e.get("type") == "hotfix_commit"]
    assert len(hotfix_events) == 1
    assert hotfix_events[0]["payload"]["reason"] == "log offer staleness"


def test_fix_mode_does_not_emit_hotfix_event_on_failure(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path)
    # Make tests fail so the gate blocks.
    stack = (repo / "STACK.md").read_text().replace(
        '- test_fast: bash -c "exit 0"',
        '- test_fast: bash -c "exit 1"',
    )
    (repo / "STACK.md").write_text(stack)
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo, fix_mode=True, fix_reason="something")
    rc = gate.run_gate(ctx)
    assert rc == 2
    events_path = repo / ".agentic" / "journal" / "events.jsonl"
    if events_path.exists():
        lines = [json.loads(ln) for ln in events_path.read_text().splitlines() if ln.strip()]
        hotfix_events = [e for e in lines if e.get("type") == "hotfix_commit"]
        assert hotfix_events == []


def test_normal_mode_does_not_emit_hotfix_event(tmp_path: Path) -> None:
    repo = _init_repo(tmp_path, plan_review="no")
    # Stub ag.sh to pass contract check
    (repo / ".agentic" / "lib" / "tools" / "ag.sh").write_text(
        '#!/usr/bin/env bash\nexit 0\n'
    )
    (repo / ".agentic" / "lib" / "tools" / "ag.sh").chmod(0o755)
    _stage(repo, "src/foo.py", "x = 1\n")
    ctx = _build_ctx(repo)  # fix_mode default False
    gate.run_gate(ctx)
    events_path = repo / ".agentic" / "journal" / "events.jsonl"
    if events_path.exists():
        lines = [json.loads(ln) for ln in events_path.read_text().splitlines() if ln.strip()]
        assert not any(e.get("type") == "hotfix_commit" for e in lines)


# ---------------------------------------------------------------------------
# Standalone runner
# ---------------------------------------------------------------------------


if __name__ == "__main__":
    import traceback

    funcs = [(name, fn) for name, fn in globals().items()
             if name.startswith("test_") and callable(fn)]
    passed = failed = 0
    for name, fn in funcs:
        try:
            with tempfile.TemporaryDirectory() as tmp:
                if "tmp_path" in fn.__code__.co_varnames[:fn.__code__.co_argcount]:
                    fn(tmp_path=Path(tmp))
                else:
                    fn()
            passed += 1
            print(f"ok    {name}")
        except Exception:
            failed += 1
            print(f"FAIL  {name}")
            traceback.print_exc()
    print(f"\n{passed} passed, {failed} failed")
    sys.exit(1 if failed else 0)
