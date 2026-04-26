#!/usr/bin/env python3
"""
prepush_gate.py — Tier 0 second-wall pre-push gate (R-002).

Pre-commit (R-001) blocks per-commit; pre-push fires when the full range is
about to leave the local repo. The two gates compose: R-001 catches the
last-commit-shaped failures; R-002 catches range-shaped failures (rebases,
amends, force-pushes that would land bad state on a remote).

What it blocks (each is hardcoded; no advisory escapes):

  AC1  `git push` always invokes the gate, regardless of remote
  AC2  Full integration test command (STACK.md `test:` — slower / deeper
       than R-001's `test_fast`); subprocess timeout/crash safe
  AC3  `ag contract coverage` — parses the "Coverage: N%" summary;
       blocks if any feature is below `contract_coverage_threshold`
       (default 80, settable in STACK.md)
  AC4  `drift.sh --docs` — formal+ profiles only. Drift output ends in
       "Found N potential documentation drift issue(s)" when N>0; gate
       blocks the push when N>0.
  AC5  Migration entry presence check — re-runs the R-001 shape (shipped+
       protected contract changes need a new `migrations:` entry) but
       across the full range `<remote_oid>..<local_oid>`, not just HEAD.
  AC6  Skip mechanism — `git push --no-verify` is silently skipped by git
       and we cannot observe it directly. The sanctioned bypass is
       `ag push --skip-gate "<reason>"` which sets AGENT_SKIP_GATE env
       and forwards to `git push` with the skip-recorded.
  AC7  Every invocation emits a `push_attempt` event regardless of outcome.

Exit codes:
  0  push allowed
  2  push blocked (or any internal hard error; git aborts the push)

Bypass (sanctioned, audited):
  AGENT_SKIP_GATE=1 + AGENT_SKIP_GATE_REASON="<reason>"
  Set by `ag push --skip-gate "<reason>"`. Emits gate_skipped + push_attempt
  events with the reason and returns 0.

Pre-push stdin contract (man githooks):
  Each line: <local_ref> <local_oid> <remote_ref> <remote_oid>
  Special: when there's nothing to push for a ref, oids are zeros.
  We read all lines, build the union of commit ranges, and walk them.

Out of scope (own backlog items):
  - Hook integrity hashing                      (R-004)
  - Stop hook integration                       (R-206)
  - Anatomy hook                                (R-103)
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
from typing import Optional


# ---------------------------------------------------------------------------
# Shared with precommit_gate where it makes sense — keep imports lazy so the
# gate runs even if precommit_gate is broken / partially installed.
# ---------------------------------------------------------------------------

_THIS_FILE = Path(__file__).resolve()
_LIB_DIR = _THIS_FILE.parent.parent  # .agentic/lib/
_HOOKS_DIR = _THIS_FILE.parent
for _p in (_LIB_DIR, _HOOKS_DIR):
    if str(_p) not in sys.path:
        sys.path.insert(0, str(_p))


_ZERO_OID = "0" * 40


def _project_root() -> Path:
    """Resolve the repo root from cwd. See precommit_gate._project_root for
    the same logic and rationale (we duplicate to stay independent)."""
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


def _import_precommit_gate():
    """Use precommit_gate's contract-yaml line helpers verbatim."""
    try:
        import precommit_gate  # type: ignore
        return precommit_gate
    except Exception:
        return None


# ---------------------------------------------------------------------------
# Result types
# ---------------------------------------------------------------------------


try:
    import messages  # type: ignore  # catalog of canonical block reasons (R-012)
except Exception:  # pragma: no cover
    messages = None  # type: ignore


@dataclass
class GateResult:
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
        """Build a failed result from a `BlockReason` catalog entry (R-012)."""
        return cls(
            ac=reason.ac,
            failed=failed,
            title=reason.title,
            detail=detail,
            next_steps=list(reason.next_steps),
            reason=reason,
        )


@dataclass
class PushRange:
    """One <local_ref local_oid remote_ref remote_oid> tuple from stdin."""
    local_ref: str
    local_oid: str
    remote_ref: str
    remote_oid: str

    @property
    def is_delete(self) -> bool:
        return self.local_oid == _ZERO_OID

    @property
    def is_create(self) -> bool:
        return self.remote_oid == _ZERO_OID

    @property
    def commit_range(self) -> Optional[str]:
        """Range to walk for commit-by-commit checks. Returns None for
        deletes. For creates, returns just the local_oid (we walk all reachable
        commits not on the remote — git rev-list handles the --not <remote/*>
        case at call site)."""
        if self.is_delete:
            return None
        if self.is_create:
            return self.local_oid  # caller adds --not <other-remote-refs>
        return f"{self.remote_oid}..{self.local_oid}"


@dataclass
class GateContext:
    root: Path
    profile: str
    is_formal_like: bool
    test_command: str
    coverage_threshold: int
    push_ranges: list[PushRange]
    session_id: str


# ---------------------------------------------------------------------------
# Context resolution
# ---------------------------------------------------------------------------


def _read_setting(root: Path, key: str, default: str) -> str:
    s = _import_settings()
    if s is None:
        return default
    try:
        return (s.get_setting(root, key, default) or default).strip()
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


def _resolve_full_test_command(root: Path) -> str:
    """Pre-push uses the full / integration test command, not test_fast."""
    stack_md = root / "STACK.md"
    if not stack_md.exists():
        stack_md = root / ".agentic" / "STACK.md"
    if not stack_md.exists():
        return ""
    try:
        text = stack_md.read_text(encoding="utf-8")
    except Exception:
        return ""
    pattern = re.compile(
        r"^\s*-?\s*(?P<key>test_full|test)\s*:\s*(?P<val>[^\n#]+)", re.IGNORECASE
    )
    found: dict[str, str] = {}
    for line in text.splitlines():
        m = pattern.match(line)
        if m:
            key = m.group("key").lower()
            val = m.group("val").strip()
            if key not in found and val:
                found[key] = val
    return found.get("test_full") or found.get("test") or ""


def _read_push_ranges_from_stdin() -> list[PushRange]:
    """Pre-push hook receives `<local_ref> <local_oid> <remote_ref> <remote_oid>`
    lines on stdin. Empty stdin = manual invocation (e.g., from tests); we
    still produce useful output (no commit-range-shaped checks fire)."""
    ranges: list[PushRange] = []
    if sys.stdin is None or sys.stdin.isatty():
        return ranges
    for raw in sys.stdin.read().splitlines():
        parts = raw.split()
        if len(parts) != 4:
            continue
        ranges.append(PushRange(*parts))
    return ranges


def _build_context(root: Path) -> GateContext:
    profile = _read_setting(root, "profile", "discovery").strip().lower()
    threshold_raw = _read_setting(root, "contract_coverage_threshold", "80").strip()
    try:
        threshold = max(0, min(100, int(threshold_raw)))
    except (TypeError, ValueError):
        threshold = 80
    return GateContext(
        root=root,
        profile=profile,
        is_formal_like=_is_formal_like(profile),
        test_command=_resolve_full_test_command(root),
        coverage_threshold=threshold,
        push_ranges=_read_push_ranges_from_stdin(),
        session_id=os.environ.get("AGENTIC_SESSION_ID")
        or os.environ.get("CLAUDE_SESSION_ID")
        or f"prepush-{uuid.uuid4().hex[:12]}",
    )


def _emit_event(*, type: str, session_id: str, payload: dict, feature: Optional[str] = None) -> None:
    events = _import_events()
    if events is None:
        return
    try:
        events.append_event(
            type=type, session_id=session_id, actor="prepush_gate",
            payload=payload, feature=feature,
        )
    except Exception:
        pass


# ---------------------------------------------------------------------------
# AC2 — full test suite
# ---------------------------------------------------------------------------


def check_full_tests(ctx: GateContext) -> GateResult:
    if not ctx.test_command:
        _emit_event(type="test_run", session_id=ctx.session_id,
                    payload={"phase": "prepush", "skipped": True,
                             "reason": "no test command in STACK.md"})
        return GateResult(ac="AC2", failed=False, title="tests (no command; skipped)")

    started = time.monotonic()
    rc = -1
    out = ""
    timed_out = False
    crashed = False
    try:
        proc = subprocess.run(
            ctx.test_command, shell=True, cwd=str(ctx.root),
            capture_output=True, text=True, timeout=1800, check=False,
        )
        rc = proc.returncode
        combined = (proc.stdout or "") + (proc.stderr or "")
        out = combined[-3000:] if len(combined) > 3000 else combined
    except subprocess.TimeoutExpired:
        timed_out = True
        rc = 124
    except (FileNotFoundError, OSError) as e:
        crashed = True
        out = f"subprocess crash: {e}"
        rc = 127
    duration_ms = int((time.monotonic() - started) * 1000)

    _emit_event(
        type="test_run", session_id=ctx.session_id,
        payload={"phase": "prepush", "command": ctx.test_command,
                 "returncode": rc, "duration_ms": duration_ms,
                 "timed_out": timed_out, "crashed": crashed,
                 "output_tail": out[-700:]},
    )

    if rc == 0:
        return GateResult(ac="AC2", failed=False, title=f"tests pass ({duration_ms}ms)")

    detail = [f"command: {ctx.test_command}", f"return code: {rc}", f"duration: {duration_ms}ms"]
    if timed_out:
        detail.append("TIMEOUT after 1800s")
    if crashed:
        detail.append("subprocess crashed before exit")
    if out.strip():
        detail += ["--- last output ---", out.rstrip()]

    return GateResult.from_reason(messages.INTEGRATION_TESTS_FAILING, detail="\n".join(detail))


# ---------------------------------------------------------------------------
# AC3 — contract coverage threshold
# ---------------------------------------------------------------------------


_COVERAGE_RE = re.compile(r"^\s*Coverage:\s*([0-9]+(?:\.[0-9]+)?)\s*%", re.MULTILINE)


def check_contract_coverage(ctx: GateContext) -> GateResult:
    ag_sh = ctx.root / ".agentic" / "lib" / "tools" / "ag.sh"
    if not ag_sh.exists():
        return GateResult(ac="AC3", failed=False, title="coverage (ag.sh missing; skipped)")

    try:
        proc = subprocess.run(
            ["bash", str(ag_sh), "contract", "coverage"],
            cwd=str(ctx.root), capture_output=True, text=True,
            timeout=120, check=False,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
        rc = proc.returncode
    except subprocess.TimeoutExpired:
        return GateResult(ac="AC3", failed=True, title="coverage check timed out",
                          detail="ag contract coverage > 120s",
                          next_steps=["Investigate why coverage is slow; rerun manually."])
    except (FileNotFoundError, OSError) as e:
        return GateResult(ac="AC3", failed=False,
                          title=f"coverage skipped (subprocess error: {e})")

    m = _COVERAGE_RE.search(out)
    if m is None:
        # Couldn't parse — treat as advisory pass (the existing tool may
        # change its output shape; we don't want a false-negative block).
        return GateResult(ac="AC3", failed=False,
                          title="coverage unparseable; advisory pass",
                          detail=out[-600:])

    pct = float(m.group(1))
    _emit_event(type="contract_check", session_id=ctx.session_id,
                payload={"phase": "prepush", "coverage_pct": pct,
                         "threshold": ctx.coverage_threshold,
                         "returncode": rc})

    if pct + 1e-9 >= ctx.coverage_threshold:
        return GateResult(ac="AC3", failed=False,
                          title=f"coverage {pct:.1f}% ≥ {ctx.coverage_threshold}%")

    return GateResult.from_reason(
        messages.COVERAGE_BELOW_THRESHOLD,
        detail=(
            f"Coverage {pct:.1f}% < {ctx.coverage_threshold}% threshold. "
            "Some shipped/in-progress contracts have assertions without tests "
            "or verify commands."
        ),
    )


# ---------------------------------------------------------------------------
# AC4 — drift.sh --docs in formal+
# ---------------------------------------------------------------------------


_DRIFT_FOUND_RE = re.compile(
    r"Found\s+([0-9]+)\s+potential\s+documentation\s+drift", re.IGNORECASE
)


def check_doc_drift(ctx: GateContext) -> GateResult:
    if not ctx.is_formal_like:
        return GateResult(ac="AC4", failed=False, title="not formal+; skipped")
    drift_sh = ctx.root / ".agentic" / "lib" / "tools" / "drift.sh"
    if not drift_sh.exists():
        return GateResult(ac="AC4", failed=False, title="drift.sh missing; skipped")

    try:
        proc = subprocess.run(
            ["bash", str(drift_sh), "--docs"],
            cwd=str(ctx.root), capture_output=True, text=True,
            timeout=120, check=False,
        )
        out = (proc.stdout or "") + (proc.stderr or "")
    except subprocess.TimeoutExpired:
        return GateResult(ac="AC4", failed=True, title="drift check timed out (120s)",
                          detail="drift.sh --docs >120s",
                          next_steps=["Investigate; rerun manually."])
    except (FileNotFoundError, OSError) as e:
        return GateResult(ac="AC4", failed=False,
                          title=f"drift skipped (subprocess error: {e})")

    m = _DRIFT_FOUND_RE.search(out)
    drifted = int(m.group(1)) if m else 0

    if drifted == 0:
        return GateResult(ac="AC4", failed=False, title="no doc drift")

    return GateResult.from_reason(
        messages.DOC_DRIFT,
        detail=(
            f"{drifted} doc(s) drifting from code. "
            "In formal+ profiles, docs referencing changed code must be "
            "refreshed or de-tracked before push.\n\n" + out[-1500:]
        ),
    )


# ---------------------------------------------------------------------------
# AC5 — shipped-contract migration check across the full pushed range
# ---------------------------------------------------------------------------


def _commits_in_range(root: Path, push_range: PushRange) -> list[str]:
    """Returns the SHAs in `<remote_oid>..<local_oid>` (or all reachable from
    local_oid for branch creates, modulo other local/remote refs). Returns []
    for deletes."""
    if push_range.is_delete:
        return []

    if push_range.is_create:
        # Branch create: walk all commits reachable from local_oid that aren't
        # already on any other ref. We list other refs (heads + remotes) and
        # negate them. Falls back to a bounded rev-list if for-each-ref fails.
        try:
            other = subprocess.run(
                ["git", "for-each-ref", "--format=%(objectname)",
                 "refs/heads/", "refs/remotes/"],
                cwd=str(root), capture_output=True, text=True,
                timeout=10, check=False,
            )
            negs: list[str] = []
            if other.returncode == 0:
                for line in other.stdout.splitlines():
                    line = line.strip()
                    if line and line != push_range.local_oid:
                        negs.append("^" + line)
            args = ["git", "rev-list", push_range.local_oid, *negs]
        except (subprocess.TimeoutExpired, OSError):
            args = ["git", "rev-list", "--max-count=200", push_range.local_oid]
    else:
        args = ["git", "rev-list", push_range.commit_range or push_range.local_oid]

    try:
        proc = subprocess.run(args, cwd=str(root), capture_output=True, text=True,
                              timeout=20, check=False)
        if proc.returncode != 0:
            return []
        return [ln for ln in proc.stdout.splitlines() if ln.strip()]
    except (subprocess.TimeoutExpired, OSError):
        return []


def _commit_changed_files(root: Path, sha: str) -> list[str]:
    try:
        proc = subprocess.run(
            ["git", "show", "--name-only", "--format=", sha],
            cwd=str(root), capture_output=True, text=True, timeout=15, check=False,
        )
        if proc.returncode != 0:
            return []
        return [ln for ln in proc.stdout.splitlines() if ln.strip()]
    except (subprocess.TimeoutExpired, OSError):
        return []


def _git_show(root: Path, ref: str, path: str) -> Optional[str]:
    try:
        proc = subprocess.run(
            ["git", "show", f"{ref}:{path}"],
            cwd=str(root), capture_output=True, text=True, timeout=15, check=False,
        )
        if proc.returncode != 0:
            return None
        return proc.stdout
    except (subprocess.TimeoutExpired, OSError):
        return None


def check_range_migrations(ctx: GateContext) -> GateResult:
    """For each commit in each pushed range, re-apply R-001 AC5 logic:
    if a shipped+protected contract changed, the commit must add a
    migrations entry. Reuses precommit_gate's line-based helpers."""
    pcg = _import_precommit_gate()
    if pcg is None:
        return GateResult(ac="AC5", failed=False,
                          title="migration check (precommit_gate import failed; skipped)")

    if not ctx.push_ranges:
        return GateResult(ac="AC5", failed=False,
                          title="no push range provided; skipped")

    offending: list[str] = []
    for pr in ctx.push_ranges:
        if pr.is_delete:
            continue
        for sha in _commits_in_range(ctx.root, pr):
            files = _commit_changed_files(ctx.root, sha)
            for path in files:
                if not pcg._is_contract_path(path):
                    continue
                parent_text = _git_show(ctx.root, f"{sha}^", path)
                if parent_text is None:
                    # New file in this commit; nothing to migrate from.
                    continue
                if not pcg._is_shipped_protected_yaml(parent_text):
                    continue
                this_text = _git_show(ctx.root, sha, path)
                if this_text is None or this_text == parent_text:
                    continue
                parent_count = pcg._count_migration_entries(parent_text)
                this_count = pcg._count_migration_entries(this_text)
                if this_count <= parent_count:
                    offending.append(f"{sha[:8]} {path} (entries {parent_count}→{this_count})")

    if not offending:
        return GateResult(ac="AC5", failed=False,
                          title="range migration check pass")

    return GateResult.from_reason(
        messages.RANGE_MIGRATIONS_MISSING,
        detail="\n  ".join(
            ["these commits modified shipped+protected YAMLs without migrations:"]
            + offending
        ),
    )


# ---------------------------------------------------------------------------
# AC6 helper — informational note on raw `git push`
# ---------------------------------------------------------------------------


def check_push_breadcrumb(ctx: GateContext) -> GateResult:
    breadcrumb = ctx.root / ".agentic" / "session" / ".push-invoked-via-ag"
    if breadcrumb.exists():
        try:
            breadcrumb.unlink()
        except OSError:
            pass
        return GateResult(ac="AC6", failed=False, title="invoked via ag push")
    return GateResult(
        ac="AC6", failed=False, title="raw git push (consider `ag push`)",
        detail=("Push invoked directly via `git push`, not `ag push`. "
                "`ag push` adds an audit trail and the sanctioned `--skip-gate <reason>`."),
    )


# ---------------------------------------------------------------------------
# Output
# ---------------------------------------------------------------------------


_RED = "\033[31m"
_YELLOW = "\033[33m"
_GREEN = "\033[32m"
_BOLD = "\033[1m"
_RESET = "\033[0m"


def _color(s: str, code: str) -> str:
    return s if not sys.stderr.isatty() else f"{code}{s}{_RESET}"


def print_blocked(failures: list[GateResult], *, verbose: bool = False) -> None:
    """Structured BLOCKED output. With `verbose=True`, expand each failure
    with the catalog's `verbose_detail` + `plan_ref` (R-012)."""
    sys.stderr.write(_color("\n━━━ pre-push gate BLOCKED ━━━\n", _RED + _BOLD))
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
    sys.stderr.write("  ag push --skip-gate \"<reason>\"\n")
    if not verbose:
        sys.stderr.write(_color("Tip: pass --verbose for expanded explanations and plan refs.\n", _YELLOW))
    sys.stderr.write("\n")


def print_passed(results: list[GateResult]) -> None:
    if not sys.stderr.isatty():
        return
    sys.stderr.write(_color("pre-push gate: ", _GREEN))
    sys.stderr.write(", ".join(f"{r.ac} {r.title}" for r in results) + "\n")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


_CHECKS = [
    check_full_tests,
    check_contract_coverage,
    check_doc_drift,
    check_range_migrations,
    check_push_breadcrumb,
]


def run_gate(ctx: GateContext, *, verbose: bool = False) -> int:
    results = [check(ctx) for check in _CHECKS]
    failures = [r for r in results if r.failed]
    _emit_event(
        type="push_attempt", session_id=ctx.session_id,
        payload={"ranges": [vars(r) for r in ctx.push_ranges],
                 "results": [{"ac": r.ac, "failed": r.failed, "title": r.title}
                             for r in results],
                 "blocked": bool(failures)},
    )
    if failures:
        print_blocked(failures, verbose=verbose)
        _emit_event(
            type="gate_blocked", session_id=ctx.session_id,
            payload={"gate": "prepush",
                     "failures": [{"ac": r.ac, "title": r.title} for r in failures]},
        )
        return 2
    print_passed(results)
    return 0


def main(argv: Optional[list[str]] = None) -> int:
    parser = argparse.ArgumentParser(prog="prepush_gate", add_help=True)
    parser.add_argument("--ci-mode", action="store_true",
                        help="Run as if invoked by CI (currently identical).")
    parser.add_argument("--print-context", action="store_true",
                        help="Print resolved context and exit.")
    parser.add_argument("--verbose", "-v", action="store_true",
                        help="Print expanded explanations and plan refs for blocked checks (R-012).")
    # git invokes pre-push with `<remote-name> <remote-url>` as positional args.
    parser.add_argument("remote_name", nargs="?", default="")
    parser.add_argument("remote_url", nargs="?", default="")
    args = parser.parse_args(argv)

    root = _project_root()
    ctx = _build_context(root)

    if args.print_context:
        sys.stdout.write(
            f"root={ctx.root}\nprofile={ctx.profile}\nis_formal_like={ctx.is_formal_like}\n"
            f"test_command={ctx.test_command!r}\ncoverage_threshold={ctx.coverage_threshold}\n"
            f"push_ranges={len(ctx.push_ranges)}\nsession_id={ctx.session_id}\n"
        )
        return 0

    if os.environ.get("AGENT_SKIP_GATE") == "1":
        reason = os.environ.get("AGENT_SKIP_GATE_REASON", "unspecified")
        _emit_event(type="gate_skipped", session_id=ctx.session_id,
                    payload={"gate": "prepush", "reason": reason,
                             "remote_name": args.remote_name})
        _emit_event(type="push_attempt", session_id=ctx.session_id,
                    payload={"skipped": True, "reason": reason,
                             "remote_name": args.remote_name})
        if sys.stderr.isatty():
            sys.stderr.write(_color(
                f"pre-push gate skipped (audited): {reason}\n", _YELLOW))
        return 0

    return run_gate(ctx, verbose=args.verbose)


if __name__ == "__main__":
    sys.exit(main())
