#!/usr/bin/env bash
# commands/integrity.sh — hook integrity baseline command (R-004)
# Sourced by ag.sh — do NOT execute directly.
# Depends on: ROOT_DIR, color codes.

cmd_integrity() {
    local subcmd="${1:-status}"
    shift 2>/dev/null || true

    case "$subcmd" in
        update)        _integrity_update "$@" ;;
        status|check)  _integrity_status "$@" ;;
        help|--help|-h) _integrity_help ;;
        *)
            echo -e "${RED}Unknown integrity subcommand: $subcmd${NC}"
            _integrity_help
            return 1
            ;;
    esac
}

_integrity_help() {
    echo -e "${BOLD}ag integrity${NC} — hook integrity baseline (R-004)"
    echo ""
    echo "  status            Show baseline state and any current mismatches (default)"
    echo "  update            Regenerate the baseline; emits an audit event"
    echo ""
    echo "Baselined paths: .git/hooks/pre-{commit,push}, .agentic/lib/hooks/*.py,"
    echo "                 .agentic/lib/integrity.py, .claude/hooks.json,"
    echo "                 .claude/settings.json[hooks], .claude/agents/*.md"
    echo ""
    echo "Baseline file:   .agentic/integrity.json (committed to repo)"
}

_integrity_status() {
    PYTHONPATH="$ROOT_DIR/.agentic/lib" \
    _AG_ROOT="$ROOT_DIR" \
    python3 - <<'PY'
import json, os, sys
from pathlib import Path
import integrity

root = Path(os.environ["_AG_ROOT"])
result = integrity.verify_all(root)

if result.skipped:
    print(f"integrity skipped: {result.skip_reason}")
    sys.exit(0)

if not result.baseline_present:
    print("no baseline yet — run: ag integrity update")
    print()
    current = integrity.compute_baseline(root)
    if current:
        print(f"would baseline {len(current)} target(s):")
        for path in sorted(current):
            print(f"  {path}")
    sys.exit(1)

if not result.mismatches:
    print("integrity verified: baseline and working tree agree")
    sys.exit(0)

print(f"{len(result.mismatches)} mismatch(es):")
for m in result.mismatches:
    print(f"  [{m.kind:22s}] {m.path}")
print()
print("If the changes are intentional and reviewed:")
print("  ag integrity update     (regenerates baseline; audited)")
print("Otherwise: revert the modified files to HEAD.")
sys.exit(2)
PY
    return $?
}

_integrity_update() {
    PYTHONPATH="$ROOT_DIR/.agentic/lib" \
    _AG_ROOT="$ROOT_DIR" \
    _AG_SESSION="${AG_SESSION_ID:-cli-$$}" \
    python3 - <<'PY'
import json, os, sys
from pathlib import Path
import integrity

root = Path(os.environ["_AG_ROOT"])
path, baseline = integrity.update_baseline(root)
print(f"Baseline updated: {path.relative_to(root)}")
print(f"  {len(baseline)} target(s) hashed")
for p in sorted(baseline):
    print(f"  - {p}")

# Best-effort audit event.
try:
    from events import append_event
    append_event(
        type="integrity_baseline_updated",
        session_id=os.environ["_AG_SESSION"],
        actor="ag integrity update",
        payload={
            "files": sorted(baseline.keys()),
            "count": len(baseline),
        },
    )
except Exception as e:
    sys.stderr.write(f"warning: could not record audit event: {e}\n")
PY
    return $?
}
