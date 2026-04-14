#!/usr/bin/env python3
"""skills_marketplace.py — fetch/match/install skills from a curated allowlist.

F-008 AC-009/010/011 — PR-A of three-phase skills.sh marketplace integration.

Subcommands:
  suggest                 Print skills matching current stack (no writes).
  install [--all|--select ID...] [--accept-scripts] [--override-builtin]
                          Interactive install of matched skills.
  sync [--dry-run]        Diff installed vs. current-stack recommendations;
                          dry-run prints a single-line summary for the hook.
  list                    Print installed marketplace skills with source + pinned sha.
  remove <id>             Uninstall a marketplace skill; regenerate Claude/Cursor skills.
  update-pins             Maintainer tool: re-resolve HEAD shas for allowlist entries.
  request <github-url>    Open a templated GitHub issue to propose adding a skill
                          (structured community contribution path — R11).

Safety (AC-010):
  - Fetches only from raw.githubusercontent.com (HTTPS).
  - Refuses skills not listed in the allowlist.
  - Refuses entries whose sha is missing or all-zero (seed marker).
  - sha256 of fetched SKILL.md is recorded in .source.json; upstream
    changes surface via `ag skills sync`.
  - If a fetched skill ships scripts/, install aborts unless --accept-scripts.
  - Honors GITHUB_TOKEN (for rate limit), HTTPS_PROXY, NO_PROXY.

Precedence (AC-011, R4):
  If a built-in F-008 quality file covers the same stack
  (.agentic/lib/quality_knowledge/<stack>.yaml), marketplace skills for that
  stack are skipped unless --override-builtin is passed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Iterable

# PyYAML is required for allowlist parsing (the allowlist is YAML because the
# framework already uses YAML for F-008 quality_knowledge + contract specs).
# Defer the import so --help works in minimal environments; all commands that
# actually touch the allowlist call _require_yaml() and fail cleanly if absent.
def _require_yaml():
    try:
        import yaml  # noqa: F401
        return yaml
    except ImportError:
        die("PyYAML is required for `ag skills` (install: `pip install pyyaml`).", code=2)
    return None  # unreachable

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------
TOOLS_DIR = Path(__file__).resolve().parent
LIB_DIR = TOOLS_DIR.parent
AGENTIC_ROOT = LIB_DIR.parent
PROJECT_ROOT = Path(os.environ.get("CLAUDE_PROJECT_DIR") or os.environ.get("ROOT_DIR") or AGENTIC_ROOT.parent)

ALLOWLIST_PATH = LIB_DIR / "data" / "skills-marketplace.yaml"
EXTENSIONS_DIR = AGENTIC_ROOT / "local" / "extensions" / "skills"
STACK_MD = PROJECT_ROOT / "STACK.md"
BUILTIN_QUALITY_DIR = LIB_DIR / "quality_knowledge"
GENERATE_SKILLS = TOOLS_DIR / "generate-skills.sh"
GENERATE_CURSOR = TOOLS_DIR / "generate-cursor-skills.sh"

RAW_HOST = "raw.githubusercontent.com"
ZERO_SHA = "0" * 40


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------
@dataclass
class SkillEntry:
    stack: str
    id: str           # owner/repo or owner/repo#subpath
    reason: str
    sha: str

    @property
    def owner_repo(self) -> str:
        return self.id.split("#", 1)[0]

    @property
    def subpath(self) -> str:
        return self.id.split("#", 1)[1] if "#" in self.id else ""

    @property
    def slug(self) -> str:
        """Directory-safe slug for extension landing zone."""
        return "marketplace-" + re.sub(r"[^a-z0-9]+", "-", self.id.lower()).strip("-")


@dataclass
class Allowlist:
    version: int
    stacks: dict[str, dict]  # raw structure; helpers below

    @classmethod
    def load(cls, path: Path = ALLOWLIST_PATH) -> "Allowlist":
        if not path.exists():
            die(f"Allowlist not found at {path}")
        yaml = _require_yaml()
        data = yaml.safe_load(path.read_text()) or {}
        version = data.get("version")
        if version != 1:
            die(f"Allowlist {path}: expected version 1, got {version!r}")
        stacks = data.get("stacks") or {}
        # Validate shape + mandatory sha on every skill (AC-009)
        for name, body in stacks.items():
            for skill in body.get("skills") or []:
                sha = skill.get("sha")
                if not sha or not re.fullmatch(r"[0-9a-f]{40}", sha):
                    die(f"Allowlist: stack '{name}' skill '{skill.get('id')}' missing or invalid sha pin")
        return cls(version=version, stacks=stacks)

    def entries(self) -> Iterable[SkillEntry]:
        for stack, body in self.stacks.items():
            for skill in body.get("skills") or []:
                yield SkillEntry(
                    stack=stack,
                    id=skill["id"],
                    reason=skill.get("reason", ""),
                    sha=skill["sha"],
                )

    def signals_for(self, stack: str) -> list[str]:
        return list((self.stacks.get(stack) or {}).get("signals") or [])


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
def die(msg: str, code: int = 1) -> None:
    print(f"error: {msg}", file=sys.stderr)
    sys.exit(code)


def info(msg: str) -> None:
    print(msg, file=sys.stderr)


def is_tty() -> bool:
    return sys.stdin.isatty() and sys.stdout.isatty()


# ---------------------------------------------------------------------------
# Stack detection (signals → matching stack keys)
# ---------------------------------------------------------------------------
def _read_package_json() -> dict:
    p = PROJECT_ROOT / "package.json"
    if not p.exists():
        return {}
    try:
        return json.loads(p.read_text())
    except json.JSONDecodeError:
        return {}


def _pkg_json_path(jq_path: str, pkg: dict) -> bool:
    """Resolve e.g. 'dependencies.react' → pkg['dependencies']['react'] exists.

    Supports a trailing glob (e.g. dependencies.@azure/.*) via regex on last segment.
    """
    parts = jq_path.split(".")
    cur: object = pkg
    for i, part in enumerate(parts):
        is_last = i == len(parts) - 1
        if is_last and ("*" in part or part.endswith("/")):
            # wildcard match on keys
            if not isinstance(cur, dict):
                return False
            pattern = re.compile("^" + part.replace(".", r"\.").replace("*", ".*") + "$")
            return any(pattern.match(k) for k in cur.keys())
        if not isinstance(cur, dict) or part not in cur:
            return False
        cur = cur[part]
    return True


def signal_matches(signal: str) -> bool:
    """Evaluate one signal against the project. See allowlist header for grammar."""
    if signal.startswith("package.json:"):
        pkg = _read_package_json()
        if not pkg:
            return False
        return _pkg_json_path(signal.split(":", 1)[1], pkg)
    if signal.startswith("STACK.md:"):
        if not STACK_MD.exists():
            return False
        pattern = re.compile(signal.split(":", 1)[1], re.IGNORECASE)
        return bool(pattern.search(STACK_MD.read_text()))
    # bare filename signals — file presence
    return (PROJECT_ROOT / signal).exists()


def detect_stacks(allow: Allowlist) -> list[str]:
    matched: list[str] = []
    for stack, body in allow.stacks.items():
        signals = body.get("signals") or []
        if any(signal_matches(s) for s in signals):
            matched.append(stack)
    return matched


def builtin_covers(stack: str) -> bool:
    """R4 precedence: skip marketplace if built-in F-008 file exists for stack."""
    # Map allowlist stack-key → built-in quality_knowledge filename
    builtin_map = {
        "react": "mobile_react_native",   # no direct react builtin; RN is closest
        "python": "backend_python",
        "node": "backend_node",
        "nextjs": "web_fullstack",
        "typescript": "web_fullstack",
    }
    name = builtin_map.get(stack)
    if not name:
        return False
    return (BUILTIN_QUALITY_DIR / f"{name}.yaml").exists()


# ---------------------------------------------------------------------------
# Fetch
# ---------------------------------------------------------------------------
def _build_url(entry: SkillEntry, filename: str = "SKILL.md") -> str:
    owner_repo = entry.owner_repo
    sub = f"/{entry.subpath}" if entry.subpath else ""
    return f"https://{RAW_HOST}/{owner_repo}/{entry.sha}{sub}/{filename}"


def fetch(url: str) -> bytes:
    if not url.startswith(f"https://{RAW_HOST}/"):
        die(f"refusing to fetch non-raw URL: {url}")
    req = urllib.request.Request(url, headers={"User-Agent": "agentic-framework/ag-skills"})
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        req.add_header("Authorization", f"Bearer {token}")
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            return resp.read()
    except urllib.error.HTTPError as e:
        die(f"fetch failed ({e.code}): {url}")
    except urllib.error.URLError as e:
        die(f"network error: {e.reason} — {url}")
    return b""  # unreachable


# ---------------------------------------------------------------------------
# Install / Remove
# ---------------------------------------------------------------------------
def install_skill(entry: SkillEntry, accept_scripts: bool = False, override_builtin: bool = False) -> Path:
    if entry.sha == ZERO_SHA:
        die(
            f"skill {entry.id} has a seed placeholder sha — a maintainer must "
            f"set a real pin via `ag skills update-pins` before install."
        )
    if not override_builtin and builtin_covers(entry.stack):
        die(
            f"stack '{entry.stack}' already has a built-in F-008 quality file; "
            f"pass --override-builtin to install the marketplace skill anyway."
        )

    target_dir = EXTENSIONS_DIR / entry.slug
    target_dir.mkdir(parents=True, exist_ok=True)

    # 1. Fetch SKILL.md
    info(f"fetching {entry.id} @ {entry.sha[:7]} …")
    skill_md_bytes = fetch(_build_url(entry, "SKILL.md"))
    sha256 = hashlib.sha256(skill_md_bytes).hexdigest()

    # 2. Detect scripts/ via conservative probe — if the skill commonly ships them,
    #    we cannot enumerate the remote dir via raw. Instead we parse SKILL.md
    #    frontmatter for allowed-tools containing Bash AND check if authors
    #    reference scripts/. Quarantine = refuse-by-default unless --accept-scripts.
    skill_text = skill_md_bytes.decode("utf-8", errors="replace")
    looks_like_scripts = bool(
        re.search(r"^allowed-tools:.*Bash", skill_text, re.MULTILINE)
        or re.search(r"scripts/[^\s`'\"]+\.sh", skill_text)
    )
    if looks_like_scripts and not accept_scripts:
        die(
            f"{entry.id} references executable scripts; review required.\n"
            f"  Re-run with --accept-scripts to acknowledge."
        )

    # 3. Write SKILL.md + .source.json
    (target_dir / "SKILL.md").write_bytes(skill_md_bytes)
    source_meta = {
        "id": entry.id,
        "stack": entry.stack,
        "owner_repo": entry.owner_repo,
        "subpath": entry.subpath,
        "pinned_sha": entry.sha,
        "sha256_skill_md": sha256,
        "reason": entry.reason,
        "installed_via": "ag skills",
    }
    (target_dir / ".source.json").write_text(json.dumps(source_meta, indent=2) + "\n")

    # 4. Invoke generators so Claude + Cursor skill dirs pick up the new content
    _run_generators()
    info(f"installed {entry.id} → {target_dir.relative_to(PROJECT_ROOT)}")
    return target_dir


def remove_skill(skill_id: str) -> None:
    for d in EXTENSIONS_DIR.glob("marketplace-*"):
        meta = d / ".source.json"
        if not meta.exists():
            continue
        try:
            data = json.loads(meta.read_text())
        except json.JSONDecodeError:
            continue
        if data.get("id") == skill_id:
            shutil.rmtree(d)
            _run_generators()
            info(f"removed {skill_id}")
            return
    die(f"skill not installed: {skill_id}")


def list_installed() -> list[dict]:
    if not EXTENSIONS_DIR.exists():
        return []
    out = []
    for d in sorted(EXTENSIONS_DIR.glob("marketplace-*")):
        meta = d / ".source.json"
        if meta.exists():
            try:
                out.append(json.loads(meta.read_text()))
            except json.JSONDecodeError:
                pass
    return out


def _run_generators() -> None:
    """Propagate extensions to Claude + Cursor skill dirs."""
    for script in (GENERATE_SKILLS, GENERATE_CURSOR):
        if not script.exists():
            continue
        try:
            subprocess.run(["bash", str(script)], check=False, capture_output=True, timeout=30)
        except (subprocess.TimeoutExpired, OSError) as e:
            info(f"warning: {script.name} failed: {e}")


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------
def cmd_suggest(args) -> int:
    allow = Allowlist.load()
    stacks = detect_stacks(allow)
    if not stacks:
        print("No stack signals matched. Nothing to suggest.")
        return 0
    print(f"Detected stacks: {', '.join(stacks)}\n")
    installed_ids = {m["id"] for m in list_installed()}
    for entry in allow.entries():
        if entry.stack not in stacks:
            continue
        status = "✓ installed" if entry.id in installed_ids else ("skipped: built-in covers" if builtin_covers(entry.stack) else "available")
        print(f"  [{status}] {entry.id}")
        print(f"      stack: {entry.stack}")
        print(f"      sha:   {entry.sha[:7]}")
        print(f"      why:   {entry.reason}")
    return 0


def cmd_install(args) -> int:
    allow = Allowlist.load()
    stacks = detect_stacks(allow)
    selected_ids = set(args.select or [])

    candidates: list[SkillEntry] = []
    for entry in allow.entries():
        if selected_ids:
            if entry.id in selected_ids:
                candidates.append(entry)
        elif args.all and entry.stack in stacks:
            candidates.append(entry)

    if not candidates:
        print("No skills to install (did you pass --all or --select?).")
        return 0

    installed_ids = {m["id"] for m in list_installed()}
    candidates = [c for c in candidates if c.id not in installed_ids]
    if not candidates:
        print("All matched skills already installed.")
        return 0

    # Confirm (unless --yes or non-interactive)
    if not args.yes and is_tty():
        print("Install the following skills?")
        for c in candidates:
            print(f"  - {c.id} [{c.stack}] — {c.reason}")
        print(f"    source: https://github.com/{c.owner_repo} @ {c.sha[:7]}")
        resp = input("Proceed? [y/N] ").strip().lower()
        if resp not in ("y", "yes"):
            print("Aborted.")
            return 1

    for c in candidates:
        install_skill(c, accept_scripts=args.accept_scripts, override_builtin=args.override_builtin)
    return 0


def cmd_sync(args) -> int:
    allow = Allowlist.load()
    stacks = detect_stacks(allow)
    installed = {m["id"]: m for m in list_installed()}
    recommended = {e.id: e for e in allow.entries() if e.stack in stacks and not builtin_covers(e.stack)}

    to_add = [i for i in recommended if i not in installed]
    to_remove = [i for i, meta in installed.items() if meta.get("stack") not in stacks]

    if args.dry_run:
        if to_add or to_remove:
            print(f"🧩 Stack signals changed — {len(to_add)} skill(s) to add, {len(to_remove)} to remove. Run: ag skills sync")
        return 0 if not (to_add or to_remove) else 2  # 2 = diff present (hook signal)

    if not (to_add or to_remove):
        print("Installed skills are in sync with current stack.")
        return 0

    print("Sync plan:")
    for sid in to_add:
        e = recommended[sid]
        print(f"  + {e.id} [{e.stack}]  {e.reason}")
    for sid in to_remove:
        e_meta = installed[sid]
        print(f"  - {e_meta['id']} [was: {e_meta.get('stack')}]  orphaned — stack signal no longer present")

    if not args.yes and is_tty():
        resp = input("Apply? [y/N] ").strip().lower()
        if resp not in ("y", "yes"):
            print("Aborted.")
            return 1

    for sid in to_add:
        install_skill(recommended[sid], accept_scripts=args.accept_scripts, override_builtin=args.override_builtin)
    for sid in to_remove:
        remove_skill(sid)
    return 0


def cmd_list(args) -> int:
    entries = list_installed()
    if not entries:
        print("No marketplace skills installed.")
        return 0
    for e in entries:
        print(f"{e['id']}")
        print(f"  stack: {e.get('stack')}")
        print(f"  pin:   {e.get('pinned_sha', '?')[:7]}")
        print(f"  sha256(SKILL.md): {e.get('sha256_skill_md', '?')[:12]}…")
    return 0


def cmd_remove(args) -> int:
    remove_skill(args.id)
    return 0


def cmd_update_pins(args) -> int:
    """Maintainer tool: re-resolve HEAD sha for each mapped skill.

    Uses GitHub's refs API (not raw) to fetch the current HEAD sha of the
    default branch. Does NOT write changes; prints proposed edits so a
    maintainer can review and commit intentionally.
    """
    allow = Allowlist.load()
    seen = set()
    any_stale = False
    for entry in allow.entries():
        if entry.owner_repo in seen:
            continue
        seen.add(entry.owner_repo)
        url = f"https://api.github.com/repos/{entry.owner_repo}/commits/HEAD"
        try:
            req = urllib.request.Request(url, headers={"User-Agent": "agentic-framework/ag-skills"})
            if os.environ.get("GITHUB_TOKEN"):
                req.add_header("Authorization", f"Bearer {os.environ['GITHUB_TOKEN']}")
            with urllib.request.urlopen(req, timeout=15) as resp:
                payload = json.loads(resp.read())
            head_sha = payload.get("sha", "")
        except Exception as e:
            print(f"  ? {entry.owner_repo}: could not resolve HEAD ({e})")
            continue
        if head_sha != entry.sha:
            any_stale = True
            print(f"  * {entry.owner_repo}: {entry.sha[:7]} → {head_sha[:7]}")
        else:
            print(f"  = {entry.owner_repo}: up to date ({entry.sha[:7]})")
    if any_stale:
        print("\nReview the above and edit .agentic/lib/data/skills-marketplace.yaml manually.")
    return 0


def cmd_request(args) -> int:
    """Open a templated GitHub issue to propose a new skill (R11)."""
    url = args.url
    stack_guess = args.stack or "unknown"
    body = (
        f"**Proposed skill:** {url}\n"
        f"**Target stack:** {stack_guess}\n\n"
        f"**Why it would help:**\n\n_…rationale here…_\n\n"
        f"**Source reviewed:** [ ] SKILL.md read  [ ] no executable scripts / scripts reviewed\n"
    )
    if not shutil.which("gh"):
        print("Skill request template (install `gh` to auto-open issue):\n")
        print(body)
        return 0
    subprocess.run(
        ["gh", "issue", "create",
         "--title", f"Skills marketplace request: {url}",
         "--body", body,
         "--label", "skills-marketplace"],
        check=False,
    )
    return 0


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------
def main(argv: list[str] | None = None) -> int:
    p = argparse.ArgumentParser(prog="ag skills", description=__doc__.splitlines()[0])
    sub = p.add_subparsers(dest="cmd", required=True)

    sub.add_parser("suggest")

    pi = sub.add_parser("install")
    pi.add_argument("--all", action="store_true", help="install all skills matching detected stack")
    pi.add_argument("--select", nargs="*", help="explicit skill IDs to install")
    pi.add_argument("--accept-scripts", action="store_true")
    pi.add_argument("--override-builtin", action="store_true")
    pi.add_argument("--yes", action="store_true", help="skip confirm prompt")

    ps = sub.add_parser("sync")
    ps.add_argument("--dry-run", action="store_true")
    ps.add_argument("--accept-scripts", action="store_true")
    ps.add_argument("--override-builtin", action="store_true")
    ps.add_argument("--yes", action="store_true")

    sub.add_parser("list")

    pr = sub.add_parser("remove")
    pr.add_argument("id", help="skill id (owner/repo[#subpath])")

    sub.add_parser("update-pins")

    pq = sub.add_parser("request")
    pq.add_argument("url", help="GitHub repo URL of proposed skill")
    pq.add_argument("--stack", help="target stack key (e.g. react)")

    args = p.parse_args(argv)

    dispatch = {
        "suggest": cmd_suggest,
        "install": cmd_install,
        "sync": cmd_sync,
        "list": cmd_list,
        "remove": cmd_remove,
        "update-pins": cmd_update_pins,
        "request": cmd_request,
    }
    return dispatch[args.cmd](args)


if __name__ == "__main__":
    sys.exit(main())
