"""
integrity.py — Tier 0 hook integrity baseline (R-004).

Closes the second known Tier 0 honest-limit (sibling to R-005's chmod 444 on
shipped contracts): the agent could quietly modify the hook scripts that
run the gate itself. R-004 baselines the hooks (and the `.claude` config
that wires them into the agent runtime) with SHA-256 hashes; the pre-commit
gate verifies before running any other check.

Baselined paths
---------------
Each path is hashed only if it exists. Missing baseline targets are not
errors — the framework supports projects that haven't installed all hooks
or haven't enabled Claude Code yet.

  .git/hooks/pre-commit                   shim → precommit_gate.py
  .git/hooks/pre-push                     shim → prepush_gate.py
  .agentic/lib/hooks/precommit_gate.py    Tier 0 pre-commit gate (R-001)
  .agentic/lib/hooks/prepush_gate.py      Tier 0 pre-push gate (R-002)
  .agentic/lib/hooks/messages.py          gate-message catalog (R-012)
  .agentic/lib/integrity.py               this module
  .claude/hooks.json                      per-project hook config (this repo)
  .claude/settings.json[hooks]            hooks subfield of standard settings
  .claude/agents/*.md                     per-project agent definitions

The `.claude/settings.json` entry hashes only the canonicalized `hooks`
subfield (sorted keys, no whitespace), so cosmetic edits to unrelated
settings don't trip the gate. Other entries hash the whole file.

Bypass policy
-------------
INTEGRITY_SKIP=1 is honored only when CI=true (typically a GitHub Actions
or similar runner). Locally, the env var is recorded with a warning event
and the check still runs — the whole point is that an agent inside a local
session shouldn't be able to disable it.

What this is NOT
----------------
Cryptographic signing (HMAC) is R-209. Real-time tamper detection (e.g.,
filesystem watchers) is out of scope; integrity runs at commit time only.
A determined human with shell access can `chmod`, edit, and `ag integrity
update` to launder a tamper into the baseline. The point of this layer
is to prevent the *accidental* and *agent-pattern-following* class of
mutations, not to defeat a human attacker.
"""

from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Iterable, Optional


BASELINE_FILENAME = ".agentic/integrity.json"
"""Where the baseline JSON lives, relative to project root."""

# Paths that, if they exist, are hashed in full.
_FULL_FILE_PATHS: tuple[str, ...] = (
    ".git/hooks/pre-commit",
    ".git/hooks/pre-push",
    ".agentic/lib/integrity.py",
    ".agentic/lib/hooks/precommit_gate.py",
    ".agentic/lib/hooks/prepush_gate.py",
    ".agentic/lib/hooks/messages.py",
    ".claude/hooks.json",
)

# Globs that, if any matches exist, are each hashed in full.
_FULL_FILE_GLOBS: tuple[str, ...] = (
    ".claude/agents/*.md",
)

# Paths that get a partial hash — only a subfield is canonicalized. Each
# entry is `(path, extractor)`; the extractor takes the parsed JSON and
# returns the subset to hash, or None to skip.
_PARTIAL_JSON_PATHS: tuple[tuple[str, str], ...] = (
    # `.claude/settings.json` may contain user-specific keys we don't want
    # to baseline. Only the `hooks` field controls what runs in-session.
    (".claude/settings.json", "hooks"),
)


@dataclass(frozen=True)
class IntegrityMismatch:
    """One discrepancy between the baseline and the working tree."""

    path: str
    """Path relative to project root."""

    kind: str
    """`"modified"` (hash differs), `"missing_in_tree"` (baselined but absent),
    or `"missing_in_baseline"` (present but never baselined)."""

    expected: Optional[str] = None
    """Hash recorded in baseline, when applicable."""

    actual: Optional[str] = None
    """Hash computed from the working tree, when applicable."""


# ---------------------------------------------------------------------------
# Hashing
# ---------------------------------------------------------------------------


def _sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def _hash_file(path: Path) -> str:
    """SHA-256 of a file's full contents."""
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _hash_partial_json(path: Path, key: str) -> Optional[str]:
    """SHA-256 of a single JSON subfield in canonical form. Returns None
    when the file or the field is missing — the caller treats that as
    "skip this baselined target", not as a mismatch."""
    try:
        data = json.loads(path.read_text())
    except (OSError, ValueError):
        return None
    if not isinstance(data, dict) or key not in data:
        return None
    canonical = json.dumps(data[key], sort_keys=True, separators=(",", ":"))
    return _sha256_bytes(canonical.encode("utf-8"))


def _enumerate_targets(root: Path) -> Iterable[tuple[str, Optional[str]]]:
    """Yield `(path_relative_to_root, hash_or_None)` for every existing
    baselined target. `None` hash means "we found the file but couldn't
    extract a stable hash" (e.g., partial-JSON target with key absent) —
    skipped silently.
    """
    for rel in _FULL_FILE_PATHS:
        full = root / rel
        if full.is_file():
            yield rel, _hash_file(full)

    for glob in _FULL_FILE_GLOBS:
        # `Path.glob` is rooted at root; expand against root.
        for match in sorted(root.glob(glob)):
            if match.is_file():
                yield str(match.relative_to(root)), _hash_file(match)

    for rel, key in _PARTIAL_JSON_PATHS:
        full = root / rel
        if not full.is_file():
            continue
        h = _hash_partial_json(full, key)
        if h is not None:
            yield f"{rel}[{key}]", h


def compute_baseline(root: Path) -> dict[str, str]:
    """Compute the current baseline as `{path_or_path[key]: sha256}`.
    Stable across runs as long as files don't change; sorted by path
    for stable JSON serialization."""
    out = {}
    for path, h in _enumerate_targets(root):
        out[path] = h
    return dict(sorted(out.items()))


# ---------------------------------------------------------------------------
# Baseline I/O
# ---------------------------------------------------------------------------


def baseline_path(root: Path) -> Path:
    return root / BASELINE_FILENAME


def load_baseline(root: Path) -> Optional[dict[str, str]]:
    """Read the committed baseline. Returns `None` when no baseline file
    exists — first-run state; the gate treats this as "not yet baselined"
    and warns rather than blocking."""
    p = baseline_path(root)
    if not p.is_file():
        return None
    try:
        data = json.loads(p.read_text())
    except (OSError, ValueError):
        return None
    files = data.get("files")
    if not isinstance(files, dict):
        return None
    return {str(k): str(v) for k, v in files.items()}


def save_baseline(root: Path, baseline: dict[str, str]) -> Path:
    """Write the baseline to `.agentic/integrity.json`. Schema:

        {
          "version": 1,
          "algorithm": "sha256",
          "files": { "<path-or-path[key]>": "<hex-digest>", ... }
        }

    The wrapper object is forward-compatible: future versions can add
    fields (signing, etc.) without breaking older readers."""
    p = baseline_path(root)
    p.parent.mkdir(parents=True, exist_ok=True)
    payload = {
        "version": 1,
        "algorithm": "sha256",
        "files": dict(sorted(baseline.items())),
    }
    # Trailing newline keeps `git diff` clean and POSIX-friendly.
    p.write_text(json.dumps(payload, indent=2, sort_keys=False) + "\n")
    return p


# ---------------------------------------------------------------------------
# Verification
# ---------------------------------------------------------------------------


@dataclass(frozen=True)
class VerifyResult:
    """Outcome of `verify_all`. `mismatches` is non-empty when something
    differs; `baseline_present` distinguishes first-run from corruption."""

    mismatches: list[IntegrityMismatch]
    baseline_present: bool
    skipped: bool = False
    skip_reason: str = ""


def verify_all(
    root: Path,
    *,
    skip_envvar: str = "INTEGRITY_SKIP",
    ci_envvar: str = "CI",
) -> VerifyResult:
    """Hash every baselined target and compare against the saved baseline.

    Honors `$INTEGRITY_SKIP=1` only when `$CI=true` — preventing an agent
    from disabling the check inside a local session. The CI-only carve-out
    exists so workflow runners that update the baseline (e.g., a scheduled
    `ag integrity update` job) can do so without bouncing themselves.
    """
    if os.environ.get(skip_envvar) == "1":
        if os.environ.get(ci_envvar) in ("true", "1"):
            return VerifyResult(
                mismatches=[],
                baseline_present=True,
                skipped=True,
                skip_reason=f"{skip_envvar}=1 honored under CI",
            )
        # Locally, the skip is ignored. The caller may still emit a guidance
        # event; we record the attempt in the result for visibility.
        return _verify_strict(root, skip_attempted=True)
    return _verify_strict(root)


def _verify_strict(root: Path, *, skip_attempted: bool = False) -> VerifyResult:
    baseline = load_baseline(root)
    if baseline is None:
        # No baseline yet: first run, or `.agentic/integrity.json` absent.
        # Emit `missing_in_baseline` for every target the caller can use to
        # nudge `ag integrity update`. Not a "mismatch" — the result is
        # actionable but not blocking on first run.
        return VerifyResult(mismatches=[], baseline_present=False)

    current = compute_baseline(root)
    mismatches: list[IntegrityMismatch] = []

    # Modified or missing-in-tree.
    for path, expected in baseline.items():
        actual = current.get(path)
        if actual is None:
            mismatches.append(IntegrityMismatch(
                path=path, kind="missing_in_tree", expected=expected
            ))
        elif actual != expected:
            mismatches.append(IntegrityMismatch(
                path=path, kind="modified", expected=expected, actual=actual,
            ))

    # New files appearing in baselined globs that the baseline doesn't know
    # about — surface them; the agent should `ag integrity update` to bless
    # them or remove them.
    for path, actual in current.items():
        if path not in baseline:
            mismatches.append(IntegrityMismatch(
                path=path, kind="missing_in_baseline", actual=actual,
            ))

    return VerifyResult(
        mismatches=mismatches,
        baseline_present=True,
        skipped=False,
        skip_reason=("local skip ignored" if skip_attempted else ""),
    )


# ---------------------------------------------------------------------------
# Public façade for the gate + ag integrity update
# ---------------------------------------------------------------------------


def update_baseline(root: Path) -> tuple[Path, dict[str, str]]:
    """Recompute and persist the baseline. Returns `(file_path, baseline)`.

    Callers (the `ag integrity update` command) should also append an
    `integrity_baseline_updated` event to events.jsonl with the current
    set of files."""
    baseline = compute_baseline(root)
    path = save_baseline(root, baseline)
    return path, baseline
