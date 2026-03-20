"""
workflow.py — CLI entry point for the v2 workflow engine.

Maps `ag` commands to state machine operations:
    ag start F-XXXX "title"  → create work item, transition to planning
    ag transition F-XXXX <state>  → enforce transition with preconditions
    ag check F-XXXX  → validate all required artifacts
    ag verify F-XXXX  → run verification commands, record results
    ag ship F-XXXX  → check ready_to_ship, prepare for merge
    ag status  → show current work items and states
    ag next  → show next item from backlog

Usage:
    python3 -m auto.v2.workflow <command> [args...]
"""
from __future__ import annotations

import json
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Resolve lib/ for imports
# ---------------------------------------------------------------------------
_LIB_DIR = Path(__file__).resolve().parent.parent.parent
sys.path.insert(0, str(_LIB_DIR))

from auto.v2.config import load_config, WorkflowConfig  # noqa: E402
from auto.v2.transitions import TransitionOrchestrator, TransitionResult  # noqa: E402
from auto.v2.preconditions import CheckResult  # noqa: E402
from auto.v2 import work_items  # noqa: E402


# ---------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------

def _print_err(msg: str) -> None:
    print(msg, file=sys.stderr)


def _print_ok(msg: str) -> None:
    print(f"✅ {msg}")


def _print_fail(msg: str) -> None:
    print(f"❌ {msg}", file=sys.stderr)


def _print_warn(msg: str) -> None:
    print(f"⚠️  {msg}", file=sys.stderr)


def _print_info(msg: str) -> None:
    print(f"ℹ️  {msg}")


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------


def cmd_start(project_root: Path, args: list[str]) -> int:
    """Create a new work item and move to planning.

    Usage: ag start F-XXXX "Title" [--mode formal|lean] [--profile hands_on|guided|autonomous]
    """
    if len(args) < 2:
        _print_fail("Usage: ag start <feature-id> <title> [--mode MODE] [--profile PROFILE]")
        return 1

    feature_id = args[0]
    title = args[1]
    mode = "formal"
    profile = "guided"

    # Parse optional flags
    i = 2
    while i < len(args):
        if args[i] == "--mode" and i + 1 < len(args):
            mode = args[i + 1]
            i += 2
        elif args[i] == "--profile" and i + 1 < len(args):
            profile = args[i + 1]
            i += 2
        else:
            i += 1

    config = load_config(project_root)

    # Validate mode and profile
    if mode not in config.modes:
        _print_fail(f"Unknown mode: '{mode}'. Valid: {', '.join(config.modes.keys())}")
        return 1
    if profile not in config.profiles:
        _print_fail(f"Unknown profile: '{profile}'. Valid: {', '.join(config.profiles.keys())}")
        return 1

    # Check if already exists
    if work_items.exists(project_root, feature_id):
        _print_fail(f"Work item {feature_id} already exists")
        return 1

    # Create work item
    item = work_items.create(
        project_root, feature_id, title,
        mode=mode, profile=profile,
    )

    # Transition from idea → queued → planning
    orchestrator = TransitionOrchestrator(project_root, config)
    result = orchestrator.transition(feature_id, "queued", by="system")
    if not result.success:
        _print_fail(f"Failed to queue: {result.format()}")
        return 1

    result = orchestrator.transition(feature_id, "planning", by="system")
    if not result.success:
        _print_fail(f"Failed to start planning: {result.format()}")
        return 1

    _print_ok(f"Created {feature_id}: {title}")
    _print_info(f"Mode: {mode} | Profile: {profile} | Status: planning")
    _print_info(f"Work dir: .agentic/work/{feature_id}/")
    print()
    print("Next: Write plan.md in the work directory, then:")
    print(f"  ag transition {feature_id} plan_review")

    # Emit role prompt if available
    if result.prompt:
        print()
        print("─" * 60)
        print(result.prompt)

    return 0


def cmd_transition(project_root: Path, args: list[str]) -> int:
    """Execute a state transition with enforcement.

    Usage: ag transition F-XXXX <target-state> [--reason "why"] [--skip]
    """
    if len(args) < 2:
        _print_fail("Usage: ag transition <feature-id> <target-state> [--reason TEXT] [--skip]")
        return 1

    feature_id = args[0]
    target_state = args[1]
    reason = None
    force_skip = False

    i = 2
    while i < len(args):
        if args[i] == "--reason" and i + 1 < len(args):
            reason = args[i + 1]
            i += 2
        elif args[i] == "--skip":
            force_skip = True
            i += 1
        else:
            i += 1

    config = load_config(project_root)
    orchestrator = TransitionOrchestrator(project_root, config)
    result = orchestrator.transition(
        feature_id, target_state,
        reason=reason,
        force_skip=force_skip,
    )

    print(result.format())

    # Emit role prompt if transition succeeded
    if result.success and result.prompt:
        print()
        print("─" * 60)
        print(result.prompt)

    return 0 if result.success else 1


def cmd_check(project_root: Path, args: list[str]) -> int:
    """Validate all required artifacts for a work item.

    Usage: ag check F-XXXX [--phase STATE]
    """
    if not args:
        _print_fail("Usage: ag check <feature-id> [--phase STATE]")
        return 1

    feature_id = args[0]
    phase = None

    i = 1
    while i < len(args):
        if args[i] == "--phase" and i + 1 < len(args):
            phase = args[i + 1]
            i += 2
        else:
            i += 1

    config = load_config(project_root)

    try:
        item = work_items.load(project_root, feature_id)
    except FileNotFoundError as e:
        _print_fail(str(e))
        return 1

    # Default: check what's needed for the NEXT state (more useful than current)
    orchestrator = TransitionOrchestrator(project_root, config)
    if phase:
        target = phase
    else:
        target = orchestrator.next_state(feature_id)
        if not target:
            target = item.status  # terminal state — check current

    from .preconditions import check_transition_artifacts
    result = check_transition_artifacts(
        project_root, feature_id, target, config, item.mode,
    )

    label = f"→ {target}" if target != item.status else f"at '{target}'"
    if result.passed:
        _print_ok(f"{feature_id} ready to advance {label}")
        for w in result.warnings:
            _print_warn(w)
        return 0
    else:
        _print_fail(f"{feature_id} not ready {label}:")
        for e in result.errors:
            print(f"  • {e}")
        for w in result.warnings:
            _print_warn(w)
        return 1


def cmd_verify(project_root: Path, args: list[str]) -> int:
    """Run verification commands and record results.

    Usage: ag verify F-XXXX
    """
    if not args:
        _print_fail("Usage: ag verify <feature-id>")
        return 1

    feature_id = args[0]
    config = load_config(project_root)

    if not work_items.exists(project_root, feature_id):
        _print_fail(f"Work item {feature_id} not found")
        return 1

    results: dict = {"feature_id": feature_id, "passed": True, "commands": [], "timestamp": datetime.now(timezone.utc).isoformat()}

    for cmd in config.verification_commands:
        print(f"Running: {cmd.name} ({cmd.run})...")
        try:
            proc = subprocess.run(
                cmd.run, shell=True, cwd=str(project_root),
                capture_output=True, text=True, timeout=cmd.timeout,
            )
            passed = proc.returncode == 0
            results["commands"].append({
                "name": cmd.name,
                "command": cmd.run,
                "passed": passed,
                "returncode": proc.returncode,
                "stdout": proc.stdout[-500:] if proc.stdout else "",
                "stderr": proc.stderr[-500:] if proc.stderr else "",
            })
            if passed:
                _print_ok(f"{cmd.name}: passed")
            else:
                _print_fail(f"{cmd.name}: failed (exit {proc.returncode})")
                results["passed"] = False
        except subprocess.TimeoutExpired:
            _print_fail(f"{cmd.name}: timed out ({cmd.timeout}s)")
            results["commands"].append({
                "name": cmd.name, "command": cmd.run,
                "passed": False, "timeout": True,
            })
            results["passed"] = False

    # Write verification.json
    vpath = work_items.artifact_path(project_root, feature_id, "verification.json")
    vpath.write_text(json.dumps(results, indent=2) + "\n")

    if results["passed"]:
        _print_ok(f"All verification passed for {feature_id}")
    else:
        _print_fail(f"Verification failed for {feature_id}")
    _print_info(f"Results saved to .agentic/work/{feature_id}/verification.json")

    return 0 if results["passed"] else 1


def cmd_ship(project_root: Path, args: list[str]) -> int:
    """Prepare a work item for shipping.

    Usage: ag ship F-XXXX
    """
    if not args:
        _print_fail("Usage: ag ship <feature-id>")
        return 1

    feature_id = args[0]
    config = load_config(project_root)

    try:
        item = work_items.load(project_root, feature_id)
    except FileNotFoundError as e:
        _print_fail(str(e))
        return 1

    if item.status != "ready_to_ship":
        _print_fail(
            f"{feature_id} is in state '{item.status}', must be 'ready_to_ship' to ship.\n"
            f"Use 'ag transition {feature_id} ready_to_ship' first."
        )
        return 1

    _print_ok(f"{feature_id} is ready to ship!")
    _print_info("Steps remaining:")
    print("  1. Create PR (or confirm existing PR)")
    print("  2. Get PR merged")
    print(f"  3. Run: ag transition {feature_id} shipped")

    return 0


def cmd_status(project_root: Path, args: list[str]) -> int:
    """Show current work items and their states.

    Usage: ag status [--all]
    """
    show_all = "--all" in args

    items = work_items.list_items(project_root)
    if not items:
        _print_info("No work items found. Use 'ag start F-XXXX \"Title\"' to create one.")
        return 0

    # Group by status
    active = [i for i in items if i.status not in ("shipped", "deprecated")]
    shipped = [i for i in items if i.status == "shipped"]
    deprecated = [i for i in items if i.status == "deprecated"]

    if active:
        print("📋 Active Work Items")
        print("─" * 60)
        for item in active:
            mode_badge = "🔒" if item.mode == "formal" else "🔓"
            print(f"  {item.id}: {item.title}")
            print(f"    Status: {item.status} {mode_badge} {item.mode}/{item.profile}")
            if item.branch:
                print(f"    Branch: {item.branch}")
        print()

    if show_all and shipped:
        print(f"📦 Shipped ({len(shipped)})")
        print("─" * 60)
        for item in shipped:
            print(f"  {item.id}: {item.title}")
        print()

    if show_all and deprecated:
        print(f"🗑️  Deprecated ({len(deprecated)})")
        print("─" * 60)
        for item in deprecated:
            print(f"  {item.id}: {item.title}")
        print()

    if not active:
        _print_info("No active work items. Use 'ag next' to see what's next.")

    return 0


def cmd_next(project_root: Path, args: list[str]) -> int:
    """Show the next queued work item.

    Usage: ag next
    """
    queued = work_items.list_by_status(project_root, "queued")
    if not queued:
        ideas = work_items.list_by_status(project_root, "idea")
        if ideas:
            _print_info(f"{len(ideas)} idea(s) in inbox. Queue one with:")
            print(f"  ag transition {ideas[0].id} queued")
        else:
            _print_info("No queued work. Use 'ag start F-XXXX \"Title\"' to create one.")
        return 0

    # Return highest priority (lowest number)
    queued.sort(key=lambda x: x.priority)
    item = queued[0]
    print(f"⏭️  Next: {item.id} — {item.title}")
    print(f"   Mode: {item.mode} | Profile: {item.profile}")
    print(f"   Start with: ag transition {item.id} planning")
    return 0


def cmd_info(project_root: Path, args: list[str]) -> int:
    """Show detailed info about a work item.

    Usage: ag info F-XXXX
    """
    if not args:
        _print_fail("Usage: ag info <feature-id>")
        return 1

    feature_id = args[0]

    try:
        item = work_items.load(project_root, feature_id)
    except FileNotFoundError as e:
        _print_fail(str(e))
        return 1

    print(f"📋 {item.id}: {item.title}")
    print("─" * 60)
    print(f"  Type:     {item.type}")
    print(f"  Status:   {item.status}")
    print(f"  Mode:     {item.mode}")
    print(f"  Profile:  {item.profile}")
    print(f"  Priority: {item.priority}")
    print(f"  Created:  {item.created}")
    if item.updated:
        print(f"  Updated:  {item.updated}")
    if item.branch:
        print(f"  Branch:   {item.branch}")
    if item.parent:
        print(f"  Parent:   {item.parent}")

    # Check which artifacts exist
    print()
    print("  Artifacts:")
    wdir = work_items.item_dir(project_root, feature_id)
    for name in ["plan.md", "review.md", "spec.md", "journal.md", "verification.json", "pr.md", "handoff.md"]:
        path = wdir / name
        exists = "✅" if path.exists() else "  "
        print(f"    {exists} {name}")

    # Show transition log
    if item.transitions:
        print()
        print("  Transition History:")
        for t in item.transitions:
            skip_marker = " [SKIP]" if t.get("skipped") else ""
            reason = f" — {t['reason']}" if t.get("reason") else ""
            print(f"    {t['at'][:19]}  {t['from']} → {t['to']}{skip_marker}{reason}")

    # Show next possible transitions
    config = load_config(project_root)
    print()
    print("  Next transitions:")
    for td in config.transitions:
        if td.from_state == item.status:
            req = f" (requires: {', '.join(td.requires)})" if td.requires else ""
            gate = f" [gate: {td.gate}]" if td.gate else ""
            print(f"    → {td.to_state}{req}{gate}")
    # Check skip transitions
    for skip in config.get_skip_transitions(item.mode):
        if skip.from_state == item.status:
            print(f"    → {skip.to_state} (skip, {item.mode} mode)")

    return 0


# ---------------------------------------------------------------------------
# CLI dispatcher
# ---------------------------------------------------------------------------


COMMANDS = {
    "start": cmd_start,
    "transition": cmd_transition,
    "check": cmd_check,
    "verify": cmd_verify,
    "ship": cmd_ship,
    "status": cmd_status,
    "next": cmd_next,
    "info": cmd_info,
}


def main(argv: list[str] | None = None) -> int:
    """CLI entry point."""
    if argv is None:
        argv = sys.argv[1:]

    if not argv:
        print("Usage: python -m auto.v2.workflow <command> [args...]")
        print()
        print("Commands:")
        print("  start F-XXXX \"Title\"     Create work item, start planning")
        print("  transition F-XXXX STATE  Enforce state transition")
        print("  check F-XXXX             Validate required artifacts")
        print("  verify F-XXXX            Run verification commands")
        print("  ship F-XXXX              Prepare for shipping")
        print("  status [--all]           Show work items")
        print("  next                     Show next queued item")
        print("  info F-XXXX              Detailed work item info")
        return 0

    # Resolve project root
    project_root = Path.cwd()
    # Walk up to find .agentic/
    while project_root != project_root.parent:
        if (project_root / ".agentic").is_dir():
            break
        project_root = project_root.parent
    else:
        _print_fail("Not in an Agentic Framework project (no .agentic/ directory found)")
        return 1

    command = argv[0]
    args = argv[1:]

    handler = COMMANDS.get(command)
    if not handler:
        _print_fail(f"Unknown command: '{command}'. Run without arguments for help.")
        return 1

    return handler(project_root, args)


if __name__ == "__main__":
    sys.exit(main())
