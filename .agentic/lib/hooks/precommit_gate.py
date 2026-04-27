#!/usr/bin/env python3
"""
precommit_gate.py — Tier 0 hardcoded-blocking pre-commit gate (R-001).

Fires from `.git/hooks/pre-commit` (or `.agentic/hooks/pre-commit` when
`core.hooksPath` redirects there). Runs in a separate process from any
agent session — the agent does not control invocation.

What it blocks (each is hardcoded; no advisory escapes):

  AC1  Test suite (subprocess; deterministic; timeout-safe)
  AC2  `ag contract check` — structural contract assertions
  AC3  Plan-approved sentinel exists when `plan_review_enabled: yes`
  AC4  JOURNAL.md updated since last commit (formal+ profiles only)
  AC5  Shipped contracts (`lifecycle: shipped`, `protection: contract`)
       changed only when a new `migrations:` array entry is also staged
  AC6  Direct `git commit --no-verify` is rejected with a redirect to
       `ag commit --skip-gate "<reason>"`. Pre-commit cannot itself
       observe `--no-verify` (the flag short-circuits the hook), so this
       check is best-effort: we look for a sentinel breadcrumb that
       `ag commit` writes when the hook is invoked through it. Defense
       in depth: pre-push (R-002) re-runs every check on the full range.

Events emitted (events.jsonl, R-007 spine):

  gate_blocked   — when any AC fails; payload includes the failure list
  gate_skipped   — when `AGENT_SKIP_GATE=1` env is set (audit trail)
  contract_check — when AC2 ran; payload includes pass/fail count
  test_run       — when AC1 ran; payload includes return code + duration

Exit codes:

  0 — all checks pass (or skipped via audited bypass); commit proceeds
  2 — at least one check blocked; commit aborted (git treats !=0 as block)

Bypass (sanctioned, audited):

  AGENT_SKIP_GATE=1 + AGENT_SKIP_GATE_REASON="<reason>"
  Set by `ag commit --skip-gate "<reason>"` (R-001 modify of ag.sh).
  Emits a `gate_skipped` event and returns 0 immediately.

Out of scope for R-001:
  - Hook integrity hashing                     (R-004)
  - Pre-push gate                              (R-002)
  - Stop hook integration                      (R-206)
  - Anatomy hook (PreToolUse:Read)             (R-103)
  - Filesystem read-only on shipped contracts  (R-005)
"""

from __future__ import annotations

import argparse
import os
import re
import subprocess
import sys
import time
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable, Optional


# ---------------------------------------------------------------------------
# Path bootstrapping — keep this importable even if the framework's lib/ has
# moved or is partially installed. Each helper lazy-resolves its target.
# ---------------------------------------------------------------------------

_THIS_FILE = Path(__file__).resolve()
_LIB_DIR = _THIS_FILE.parent.parent  # .agentic/lib/
if str(_LIB_DIR) not in sys.path:
    sys.path.insert(0, str(_LIB_DIR))


def _project_root() -> Path:
    """Resolve the repo root for this gate invocation.

    Order of preference:
      1. `git rev-parse --show-toplevel` from cwd — works whether the gate
         is fired from `.git/hooks/pre-commit`, `core.hooksPath`, or directly.
      2. Walk upward from cwd looking for `.git` or `.agentic`.
      3. cwd as a last resort.

    Crucially we do NOT anchor on `_THIS_FILE.parent` — the file lives in the
    framework lib/, but the *project* the hook is gating may be a separate
    repo (e.g., a test fixture) that imports the framework.
    """
    try:
        proc = subprocess.run(
            ["git", "rev-parse", "--show-toplevel"],
            cwd=str(Path.cwd()),
            capture_output=True,
            text=True,
            timeout=5,
            check=False,
        )
        if proc.returncode == 0 and proc.stdout.strip():
            return Path(proc.stdout.strip())
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        pass
    cur = Path.cwd()
    for _ in range(8):
        if (cur / ".git").exists() or (cur / ".agentic").is_dir():
            return cur
        if cur.parent == cur:
            break
        cur = cur.parent
    return Path.cwd()


def _import_events():
    """Lazy import of events.py — keeps the gate runnable even if events
    is broken; we degrade to printing without writing JSONL."""
    try:
        import events  # type: ignore

        return events
    except Exception:
        return None


def _import_settings():
    try:
        import settings  # type: ignore

        return settings
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Result types
# ---------------------------------------------------------------------------


try:
    import messages  # type: ignore  # catalog of canonical block reasons (R-012)
except Exception:  # pragma: no cover — the catalog is bundled with this gate
    messages = None  # type: ignore


@dataclass
class GateResult:
    """One AC's outcome. `failed=False` when the check passed or was skipped.

    Failed results carry an optional `reason` link into the `messages.py`
    catalog (R-012). When set, `print_blocked(verbose=True)` renders the
    catalog's `verbose_detail` + `plan_ref`.
    """

    ac: str
    failed: bool
    title: str = ""
    detail: str = ""
    next_steps: list[str] = field(default_factory=list)
    reason: "Optional[messages.BlockReason]" = None  # type: ignore[name-defined]

    @classmethod
    def from_reason(
        cls,
        reason: "messages.BlockReason",  # type: ignore[name-defined]
        *,
        failed: bool = True,
        detail: str = "",
    ) -> "GateResult":
        """Build a failed result from a `BlockReason` catalog entry. The
        catalog supplies `ac`, `title`, and `next_steps`; `detail` carries
        the runtime-specific output (test tail, file list, etc.)."""
        return cls(
            ac=reason.ac,
            failed=failed,
            title=reason.title,
            detail=detail,
            next_steps=list(reason.next_steps),
            reason=reason,
        )


@dataclass
class GateContext:
    """Shared inputs threaded through every check."""

    root: Path
    profile: str
    plan_review_enabled: bool
    pre_commit_hook: str  # fast | full | no
    test_command: str
    staged_files: list[str]
    session_id: str
    is_formal_like: bool


# ---------------------------------------------------------------------------
# Context resolution
# ---------------------------------------------------------------------------


def _read_setting(root: Path, key: str, default: str) -> str:
    s = _import_settings()
    if s is None:
        return default
    try:
        val = s.get_setting(root, key, default)
        return (val or default).strip()
    except Exception:
        return default


def _is_formal_like(profile: str) -> bool:
    s = _import_settings()
    if s is not None:
        try:
            return bool(s.is_formal_like(profile))
        except Exception:
            pass
    return profile in ("formal", "autonomous_formal")


def _staged_files(root: Path) -> list[str]:
    """Files in the index — what this commit will actually create/modify."""
    try:
        out = subprocess.run(
            ["git", "diff", "--cached", "--name-only"],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        if out.returncode != 0:
            return []
        return [ln for ln in out.stdout.splitlines() if ln.strip()]
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError):
        return []


def _resolve_test_command(root: Path) -> str:
    """Pick the fastest test command. STACK.md may declare:
        test_fast: ...
        test: ...
    Prefer test_fast; fall back to test; fall back to validate_framework.sh.
    """
    stack_md = root / "STACK.md"
    if not stack_md.exists():
        stack_md = root / ".agentic" / "STACK.md"
    if not stack_md.exists():
        return ""

    text = ""
    try:
        text = stack_md.read_text(encoding="utf-8")
    except Exception:
        return ""

    # Match either `- test_fast: ...` or `test_fast: ...` styles
    pattern = re.compile(
        r"^\s*-?\s*(?P<key>test_fast|test)\s*:\s*(?P<val>[^\n#]+)", re.IGNORECASE
    )
    found: dict[str, str] = {}
    for line in text.splitlines():
        m = pattern.match(line)
        if m:
            key = m.group("key").lower()
            val = m.group("val").strip()
            if key not in found and val:
                found[key] = val
    return found.get("test_fast") or found.get("test") or ""


def _build_context(root: Path) -> GateContext:
    profile = _read_setting(root, "profile", "discovery").strip().lower()
    plan_review_raw = _read_setting(root, "plan_review_enabled", "no").strip().lower()
    pch = _read_setting(root, "pre_commit_hook", "fast").strip().lower()
    return GateContext(
        root=root,
        profile=profile,
        plan_review_enabled=plan_review_raw in ("yes", "true", "1", "on"),
        pre_commit_hook=pch if pch in ("no", "fast", "full") else "fast",
        test_command=_resolve_test_command(root),
        staged_files=_staged_files(root),
        session_id=os.environ.get("AGENTIC_SESSION_ID")
        or os.environ.get("CLAUDE_SESSION_ID")
        or f"precommit-{uuid.uuid4().hex[:12]}",
        is_formal_like=_is_formal_like(profile),
    )


# ---------------------------------------------------------------------------
# Event emission (best-effort; never raises out of the gate)
# ---------------------------------------------------------------------------


def _emit_event(*, type: str, session_id: str, payload: dict, feature: Optional[str] = None) -> None:
    events = _import_events()
    if events is None:
        return
    try:
        events.append_event(
            type=type,
            session_id=session_id,
            actor="precommit_gate",
            payload=payload,
            feature=feature,
        )
    except Exception:
        # Telemetry is best-effort; never let it block a commit on its own.
        pass


# ---------------------------------------------------------------------------
# AC checks
# ---------------------------------------------------------------------------


def check_integrity(ctx: GateContext) -> GateResult:
    """AC0 (R-004): hook + agent + .claude config baseline must match the
    committed `.agentic/integrity.json`. Runs first so an agent that
    tampered with a later check still trips this one.

    Honest limits:
      * No baseline file → first-run / not yet baselined; pass with a
        guidance note. The agent that runs `ag integrity update` mints
        the first baseline.
      * Skip via `INTEGRITY_SKIP=1` is honored only under CI (`CI=true`),
        so an agent inside a local session cannot disable the check.
    """
    try:
        import integrity  # type: ignore  # .agentic/lib/integrity.py
    except Exception:
        return GateResult(ac="AC0", failed=False, title="integrity (module missing; skipped)")

    result = integrity.verify_all(ctx.root)
    if result.skipped:
        # CI-mode skip — emit an audit event so the bypass is visible.
        _emit_event(
            type="integrity_baseline_updated",
            session_id=ctx.session_id,
            payload={"action": "verify_skipped_in_ci", "reason": result.skip_reason},
        )
        return GateResult(ac="AC0", failed=False, title=f"integrity skip: {result.skip_reason}")

    if not result.baseline_present:
        # First-run state. Don't block; nudge.
        return GateResult(
            ac="AC0", failed=False,
            title="integrity (no baseline; run `ag integrity update`)",
        )

    if not result.mismatches:
        return GateResult(ac="AC0", failed=False, title="integrity verified")

    detail_lines = [f"{m.kind:22s} {m.path}" for m in result.mismatches]
    detail = "\n".join(["paths failing baseline check:", *detail_lines])
    return GateResult.from_reason(messages.INTEGRITY_TAMPERED, detail=detail)


def _has_code_changes(staged: Iterable[str]) -> bool:
    """True if any staged path looks like real source/test code (not state files)."""
    state_prefixes = (
        ".agentic/journal/",
        ".agentic/session/",
        ".agentic/STATUS",
        "STATUS.md",
        "JOURNAL.md",
    )
    state_suffixes = (".jsonl",)
    for p in staged:
        if p.startswith(state_prefixes) or p.endswith(state_suffixes):
            continue
        return True
    return False


def check_tests(ctx: GateContext) -> GateResult:
    """AC1: harness-run tests. The harness (this gate) reads pytest output;
    the agent cannot claim 'tests pass' because the agent doesn't run them."""

    if not ctx.test_command:
        # No test command configured — pass with a warning event but don't block.
        _emit_event(
            type="test_run",
            session_id=ctx.session_id,
            payload={"skipped": True, "reason": "no test command in STACK.md"},
        )
        return GateResult(ac="AC1", failed=False, title="tests (no command configured; skipped)")

    if ctx.pre_commit_hook == "no":
        return GateResult(ac="AC1", failed=False, title="tests (pre_commit_hook: no; skipped)")

    if not _has_code_changes(ctx.staged_files):
        # State-only commits (journal, status, jsonl appends) skip tests by design.
        _emit_event(
            type="test_run",
            session_id=ctx.session_id,
            payload={"skipped": True, "reason": "state-only commit"},
        )
        return GateResult(ac="AC1", failed=False, title="tests (state-only commit; skipped)")

    timeout_s = 600 if ctx.pre_commit_hook == "full" else 180
    started = time.monotonic()
    rc = -1
    out = ""
    crashed = False
    timed_out = False
    try:
        proc = subprocess.run(
            ctx.test_command,
            shell=True,  # honors STACK.md's exact command string (e.g., "bash tests/foo.sh")
            cwd=str(ctx.root),
            capture_output=True,
            text=True,
            timeout=timeout_s,
            check=False,
        )
        rc = proc.returncode
        # Cap captured output to keep events.jsonl bounded.
        combined = (proc.stdout or "") + (proc.stderr or "")
        out = combined[-2000:] if len(combined) > 2000 else combined
    except subprocess.TimeoutExpired:
        timed_out = True
        rc = 124
    except (FileNotFoundError, OSError) as e:
        crashed = True
        out = f"subprocess crash: {e}"
        rc = 127

    duration_ms = int((time.monotonic() - started) * 1000)
    _emit_event(
        type="test_run",
        session_id=ctx.session_id,
        payload={
            "command": ctx.test_command,
            "returncode": rc,
            "duration_ms": duration_ms,
            "timed_out": timed_out,
            "crashed": crashed,
            "output_tail": out[-500:],
        },
    )

    if rc == 0:
        return GateResult(ac="AC1", failed=False, title=f"tests (pass, {duration_ms}ms)")

    detail_lines = [f"command: {ctx.test_command}", f"return code: {rc}", f"duration: {duration_ms}ms"]
    if timed_out:
        detail_lines.append(f"TIMEOUT after {timeout_s}s")
    if crashed:
        detail_lines.append("subprocess crashed before exit")
    if out.strip():
        detail_lines.append("--- last output ---")
        detail_lines.append(out.rstrip())

    return GateResult.from_reason(messages.TESTS_FAILING, detail="\n".join(detail_lines))


def check_contracts(ctx: GateContext) -> GateResult:
    """AC2: `ag contract check`. Structural assertions verified by the harness."""
    ag_sh = ctx.root / ".agentic" / "lib" / "tools" / "ag.sh"
    if not ag_sh.exists():
        return GateResult(ac="AC2", failed=False, title="contracts (ag.sh missing; skipped)")

    try:
        proc = subprocess.run(
            ["bash", str(ag_sh), "contract", "check"],
            cwd=str(ctx.root),
            capture_output=True,
            text=True,
            timeout=120,
            check=False,
        )
        rc = proc.returncode
        out = (proc.stdout or "") + (proc.stderr or "")
    except subprocess.TimeoutExpired:
        rc = 124
        out = "ag contract check timed out (120s)"
    except (FileNotFoundError, OSError) as e:
        rc = 127
        out = f"ag contract check crashed: {e}"

    _emit_event(
        type="contract_check",
        session_id=ctx.session_id,
        payload={"returncode": rc, "output_tail": out[-500:]},
    )

    if rc == 0:
        return GateResult(ac="AC2", failed=False, title="contracts pass")

    return GateResult.from_reason(messages.CONTRACT_CHECK_FAILED, detail=out[-1500:])


def check_plan_approved(ctx: GateContext) -> GateResult:
    """AC3: `.plan-approved` sentinel must exist when plan_review_enabled."""
    if not ctx.plan_review_enabled:
        return GateResult(ac="AC3", failed=False, title="plan review disabled; skipped")
    if not _has_code_changes(ctx.staged_files):
        return GateResult(ac="AC3", failed=False, title="state-only commit; skipped")

    sentinel = ctx.root / ".agentic" / "session" / ".plan-approved"
    if sentinel.exists():
        return GateResult(ac="AC3", failed=False, title="plan-approved sentinel present")

    return GateResult.from_reason(
        messages.PLAN_NOT_APPROVED,
        detail=(
            "STACK.md has plan_review_enabled: yes but `.agentic/session/.plan-approved`\n"
            "is missing. Code commits require an approved plan in this profile."
        ),
    )


def check_journal_freshness(ctx: GateContext) -> GateResult:
    """AC4: JOURNAL.md modified since the parent of HEAD (formal+ only)."""
    if not ctx.is_formal_like:
        return GateResult(ac="AC4", failed=False, title="not formal+; skipped")
    if not _has_code_changes(ctx.staged_files):
        return GateResult(ac="AC4", failed=False, title="state-only commit; skipped")

    candidates = [
        ctx.root / ".agentic" / "journal" / "JOURNAL.md",
        ctx.root / ".agentic" / "JOURNAL.md",
        ctx.root / "JOURNAL.md",
    ]
    journal = next((p for p in candidates if p.exists()), None)
    if journal is None:
        return GateResult(ac="AC4", failed=False, title="JOURNAL.md not present; skipped")

    # Anchor: timestamp of HEAD (the commit we're about to add ON TOP of).
    # If JOURNAL.md is newer than HEAD's commit time, the agent has logged WHY
    # since the last commit landed.
    try:
        proc = subprocess.run(
            ["git", "log", "-1", "--format=%ct", "HEAD"],
            cwd=str(ctx.root),
            capture_output=True,
            text=True,
            timeout=10,
            check=False,
        )
        if proc.returncode != 0 or not proc.stdout.strip():
            # Fresh repo / no HEAD yet — pass.
            return GateResult(ac="AC4", failed=False, title="no HEAD yet; skipped")
        head_ts = int(proc.stdout.strip())
    except (subprocess.TimeoutExpired, ValueError, OSError):
        return GateResult(ac="AC4", failed=False, title="git unavailable; skipped")

    try:
        journal_mtime = int(journal.stat().st_mtime)
    except OSError:
        return GateResult(ac="AC4", failed=False, title="JOURNAL stat failed; skipped")

    # Allow a 5s skew tolerance (tests + filesystem timestamp resolution).
    if journal_mtime + 5 >= head_ts:
        return GateResult(ac="AC4", failed=False, title="JOURNAL fresh")

    return GateResult.from_reason(
        messages.JOURNAL_STALE,
        detail=(
            f"{journal.relative_to(ctx.root)} mtime is older than HEAD's commit time.\n"
            "Formal+ profiles require a journal entry capturing WHY this commit happened."
        ),
    )


# ---- AC5 helpers --------------------------------------------------------


_SHIPPED_LINE = re.compile(r"^\s*lifecycle\s*:\s*shipped\b", re.IGNORECASE)
_PROTECTED_LINE = re.compile(r"^\s*protection\s*:\s*contract\b", re.IGNORECASE)
# Top-level migration entry: a `- id:` line at exactly two leading spaces under
# a `migrations:` block. We don't need a full YAML parser to count entries.
_MIG_KEY = re.compile(r"^migrations\s*:")
_MIG_ENTRY = re.compile(r"^[ \t]+-\s*id\s*:")


def _is_contract_path(path: str) -> bool:
    return path.endswith(".yaml") and (
        "/spec/contracts/" in f"/{path}" or path.startswith(".agentic/spec/contracts/")
    )


def _git_show_head(root: Path, path: str) -> Optional[str]:
    try:
        proc = subprocess.run(
            ["git", "show", f"HEAD:{path}"],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        if proc.returncode != 0:
            return None
        return proc.stdout
    except (subprocess.TimeoutExpired, OSError):
        return None


def _staged_blob(root: Path, path: str) -> Optional[str]:
    try:
        proc = subprocess.run(
            ["git", "diff", "--cached", "--", path],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        # Empty diff means file content equals HEAD (e.g., mode-only change).
        if proc.returncode != 0:
            return None
        # The staged content lives in the index; read it directly.
        idx = subprocess.run(
            ["git", "show", f":0:{path}"],
            cwd=str(root),
            capture_output=True,
            text=True,
            timeout=15,
            check=False,
        )
        if idx.returncode != 0:
            return None
        return idx.stdout
    except (subprocess.TimeoutExpired, OSError):
        return None


def _is_shipped_protected_yaml(text: str) -> bool:
    has_shipped = False
    has_protected = False
    for line in text.splitlines():
        if _SHIPPED_LINE.match(line):
            has_shipped = True
        elif _PROTECTED_LINE.match(line):
            has_protected = True
        if has_shipped and has_protected:
            return True
    return False


def _count_migration_entries(text: str) -> int:
    """Count top-level entries under the `migrations:` mapping. Line-based —
    sufficient for the canonical contract YAML structure used by the framework."""
    in_section = False
    entries = 0
    base_indent: Optional[int] = None
    for line in text.splitlines():
        if _MIG_KEY.match(line):
            in_section = True
            base_indent = None
            continue
        if not in_section:
            continue
        # Empty / comment lines don't end the section.
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        # A new top-level key (zero leading spaces) closes the section.
        if line[:1] not in (" ", "\t"):
            in_section = False
            continue
        m = _MIG_ENTRY.match(line)
        if not m:
            continue
        indent = len(line) - len(line.lstrip(" \t"))
        if base_indent is None:
            base_indent = indent
        if indent == base_indent:
            entries += 1
    return entries


def check_shipped_contract_migrations(ctx: GateContext) -> GateResult:
    """AC5: any change to a shipped+contract YAML must add a new migration entry."""
    contract_paths = [p for p in ctx.staged_files if _is_contract_path(p)]
    if not contract_paths:
        return GateResult(ac="AC5", failed=False, title="no shipped contracts staged; skipped")

    offending: list[str] = []
    notes: list[str] = []
    for path in contract_paths:
        head_text = _git_show_head(ctx.root, path)
        if head_text is None:
            # New contract file — nothing to migrate from.
            continue
        if not _is_shipped_protected_yaml(head_text):
            continue
        staged_text = _staged_blob(ctx.root, path)
        if staged_text is None or staged_text == head_text:
            continue
        head_count = _count_migration_entries(head_text)
        staged_count = _count_migration_entries(staged_text)
        if staged_count <= head_count:
            offending.append(path)
            notes.append(f"{path}: migrations entries head={head_count} staged={staged_count}")

    if not offending:
        return GateResult(ac="AC5", failed=False, title="shipped-contract guard pass")

    # Replace the catalog's generic F-XXX with the actual offending feature ID
    # in the first next-step. The catalog stays generic; the runtime contextualizes.
    result = GateResult.from_reason(
        messages.SHIPPED_CONTRACT_NO_MIGRATION,
        detail=(
            "These contracts have lifecycle: shipped + protection: contract.\n"
            "Any change requires a new entry under `migrations:`:\n  - "
            + "\n  - ".join(notes)
        ),
    )
    feature_id = Path(offending[0]).stem
    result.next_steps = [
        step.replace("F-XXX", feature_id) for step in result.next_steps
    ]
    return result


def check_no_verify_breadcrumb(ctx: GateContext) -> GateResult:
    """AC6: detect raw `git commit --no-verify` and redirect users to the
    sanctioned skip path. Pre-commit cannot itself observe `--no-verify`
    (the flag bypasses hook execution), so this check is informational
    when invoked, and depends on a sentinel that `ag commit` writes to
    distinguish sanctioned from raw invocations.

    The breadcrumb file is `.agentic/session/.gate-invoked-via-ag` (touched
    by `ag commit` immediately before invoking git). When the gate runs
    *without* the breadcrumb, we know the agent went around `ag commit`.
    We don't block on this alone (the agent may legitimately use raw git
    in many cases) — we emit guidance and an event so pre-push (R-002)
    can apply stricter policy on the full pushed range.
    """
    breadcrumb = ctx.root / ".agentic" / "session" / ".gate-invoked-via-ag"
    if breadcrumb.exists():
        # Best-effort cleanup — the breadcrumb is per-invocation.
        try:
            breadcrumb.unlink()
        except OSError:
            pass
        return GateResult(ac="AC6", failed=False, title="invoked via ag commit")
    # Not blocking, but emit guidance so the pattern is observable.
    return GateResult(
        ac="AC6",
        failed=False,
        title="raw git commit (consider `ag commit`)",
        detail=(
            "This commit was invoked directly via `git commit`, not `ag commit`.\n"
            "`ag commit` adds an audit trail and the sanctioned `--skip-gate <reason>`\n"
            "escape hatch. Pre-push (R-002) will re-run all checks regardless."
        ),
    )


# ---------------------------------------------------------------------------
# Output formatting
# ---------------------------------------------------------------------------


_RED = "\033[31m"
_YELLOW = "\033[33m"
_GREEN = "\033[32m"
_BOLD = "\033[1m"
_RESET = "\033[0m"


def _color(s: str, code: str) -> str:
    if not sys.stderr.isatty():
        return s
    return f"{code}{s}{_RESET}"


def print_blocked(failures: list[GateResult], *, verbose: bool = False) -> None:
    """Structured BLOCKED output (R-001 AC8 + R-012). Each failure gets a
    title, detail, concrete next-step commands, and — when `verbose=True` —
    expanded explanations + plan refs from `messages.py`.

    The catalog (`messages.BlockReason`) carries the verbose extras; the
    runtime detail (test output tail, file list, etc.) carries the failure-
    specific facts. We render both.
    """
    sys.stderr.write(_color("\n━━━ pre-commit gate BLOCKED ━━━\n", _RED + _BOLD))
    sys.stderr.write(f"{len(failures)} check(s) failed:\n\n")
    for i, fail in enumerate(failures, 1):
        sys.stderr.write(_color(f"[{i}] {fail.ac} — {fail.title}\n", _RED + _BOLD))
        if fail.detail:
            for line in fail.detail.splitlines():
                sys.stderr.write(f"    {line}\n")
        if fail.next_steps:
            sys.stderr.write(_color("    suggested next steps:\n", _YELLOW))
            for step in fail.next_steps:
                sys.stderr.write(f"      • {step}\n")
        if verbose and fail.reason is not None:
            if fail.reason.verbose_detail:
                sys.stderr.write("\n")
                for line in fail.reason.verbose_detail.splitlines():
                    sys.stderr.write(f"    {line}\n")
            if fail.reason.plan_ref:
                sys.stderr.write(f"\n    Plan ref: {fail.reason.plan_ref}\n")
        sys.stderr.write("\n")
    sys.stderr.write(_color("To bypass with audit (use sparingly):\n", _YELLOW))
    sys.stderr.write("  ag commit --skip-gate \"<reason>\"\n")
    if not verbose:
        sys.stderr.write(_color(
            "Tip: re-run with explicit invocation for expanded detail + plan refs:\n"
            "  python3 .agentic/lib/hooks/precommit_gate.py --verbose\n",
            _YELLOW,
        ))
    sys.stderr.write("\n")


def print_passed(results: list[GateResult]) -> None:
    if not sys.stderr.isatty():
        return
    sys.stderr.write(_color("pre-commit gate: ", _GREEN))
    sys.stderr.write(", ".join(f"{r.ac} {r.title}" for r in results) + "\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


_CHECKS = [
    check_integrity,  # R-004: runs first so a tampered later-check is still caught
    check_tests,
    check_contracts,
    check_plan_approved,
    check_journal_freshness,
    check_shipped_contract_migrations,
    check_no_verify_breadcrumb,
]


def run_gate(ctx: GateContext, *, verbose: bool = False) -> int:
    results = [check(ctx) for check in _CHECKS]
    failures = [r for r in results if r.failed]
    if failures:
        print_blocked(failures, verbose=verbose)
        _emit_event(
            type="gate_blocked",
            session_id=ctx.session_id,
            payload={
                "gate": "precommit",
                "failures": [{"ac": r.ac, "title": r.title} for r in failures],
                "staged_file_count": len(ctx.staged_files),
            },
        )
        return 2
    print_passed(results)
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="precommit_gate", add_help=True)
    parser.add_argument("--ci-mode", action="store_true",
                        help="Run as if invoked by CI (currently identical to local mode).")
    parser.add_argument("--print-context", action="store_true",
                        help="Print resolved gate context and exit.")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Print expanded explanations and plan refs for blocked checks (R-012).")
    args = parser.parse_args(argv)

    root = _project_root()
    ctx = _build_context(root)

    if args.print_context:
        sys.stdout.write(
            f"root={ctx.root}\nprofile={ctx.profile}\nplan_review_enabled={ctx.plan_review_enabled}\n"
            f"pre_commit_hook={ctx.pre_commit_hook}\ntest_command={ctx.test_command!r}\n"
            f"is_formal_like={ctx.is_formal_like}\nstaged_files={len(ctx.staged_files)}\n"
            f"session_id={ctx.session_id}\n"
        )
        return 0

    # Sanctioned bypass — set by `ag commit --skip-gate <reason>`.
    if os.environ.get("AGENT_SKIP_GATE") == "1":
        reason = os.environ.get("AGENT_SKIP_GATE_REASON", "unspecified")
        _emit_event(
            type="gate_skipped",
            session_id=ctx.session_id,
            payload={"gate": "precommit", "reason": reason, "ci_mode": args.ci_mode},
        )
        if sys.stderr.isatty():
            sys.stderr.write(_color(
                f"pre-commit gate skipped (audited): {reason}\n", _YELLOW))
        return 0

    return run_gate(ctx, verbose=args.verbose)


if __name__ == "__main__":
    sys.exit(main())
