#!/usr/bin/env bash
# commands/merge.sh — local-branch merge gate (R-003)
# Sourced by ag.sh — do NOT execute directly.
#
# Provides `_merge_local_gate <branch>` and `_merge_local <branch>` for the
# `ag merge <branch>` path (when the first argument is not a digit-only PR
# number). The PR-merge path (digits-only argument) stays in
# operations.sh::cmd_merge and dispatches here only when the arg is a
# branch name.
#
# Hard enforcement: users can wire this in via
#     git config alias.merge !"bash .agentic/lib/tools/ag.sh merge"
# so even raw `git merge <branch>` runs through the gate.
#
# Depends on: ROOT_DIR, color codes, FEATURE_ID_ERE (from ids.sh).

# ---- Helpers --------------------------------------------------------------

# Discover feature/dev/epic IDs mentioned in commit messages on the source
# branch but not on the merge target. Returns deduped IDs on stdout.
_merge_discover_features() {
    local branch="$1"
    local target="${2:-HEAD}"
    local base
    base=$(git merge-base "$target" "$branch" 2>/dev/null) || return 0
    git log --format=%B "$base..$branch" 2>/dev/null \
        | grep -oE "$FEATURE_ID_ERE" \
        | sort -u
}

# Echo PASS/FAIL line + accumulate failures into the named array variable.
# Usage: _merge_record <result_array> <ok|fail> <label> [detail...]
_merge_record() {
    local -n arr="$1"
    local status="$2"
    local label="$3"
    shift 3
    if [[ "$status" == "ok" ]]; then
        echo -e "  ${GREEN}✓${NC} $label"
    else
        echo -e "  ${RED}✗${NC} $label"
        for line in "$@"; do
            echo "      $line"
        done
        arr+=("$label")
    fi
}

# Emit `merge_attempt` event (R-007 spine). Never fails the merge.
_merge_emit_event() {
    local branch="$1"
    local outcome="$2"   # blocked | merged | error
    local features="$3"
    local rc="$4"
    PYTHONPATH="$ROOT_DIR/.agentic/lib" \
    _AG_BRANCH="$branch" \
    _AG_OUTCOME="$outcome" \
    _AG_FEATURES="$features" \
    _AG_RC="$rc" \
    _AG_SESSION="${AG_SESSION_ID:-cli-$$}" \
    python3 - <<'PY' 2>/dev/null || true
import os
from events import append_event
features = [f for f in os.environ.get("_AG_FEATURES", "").split() if f]
append_event(
    type="merge_attempt",
    session_id=os.environ["_AG_SESSION"],
    actor="ag merge",
    payload={
        "scope": "local",
        "branch": os.environ["_AG_BRANCH"],
        "outcome": os.environ["_AG_OUTCOME"],
        "features": features,
        "rc": int(os.environ["_AG_RC"]),
    },
)
PY
}

# ---- Local merge gate -----------------------------------------------------

# Run AC checks against a branch about to be merged into the current HEAD.
# Returns 0 on pass, non-zero on block. Prints a structured report.
_merge_local_gate() {
    local branch="$1"

    if ! git rev-parse --verify "$branch" >/dev/null 2>&1; then
        echo -e "${RED}Branch not found: $branch${NC}" >&2
        return 1
    fi

    echo -e "${BOLD}=== ag merge gate · $branch ===${NC}"

    local target
    target=$(git rev-parse --abbrev-ref HEAD)
    echo "  source: $branch"
    echo "  target: $target"
    echo ""

    # Discover feature IDs across the range
    local features
    features=$(_merge_discover_features "$branch" HEAD)
    if [[ -z "$features" ]]; then
        echo -e "  ${YELLOW}!${NC} no feature IDs detected in commit messages"
        echo "      (chore/state branch — only structural checks will run)"
    else
        echo "  features: $(echo "$features" | tr '\n' ' ')"
    fi
    echo ""
    echo "  checks:"

    local -a failed=()

    # AC1.b — `ag contract check F-XXX` for each detected feature.
    if [[ -n "$features" ]]; then
        for fid in $features; do
            if bash "$ROOT_DIR/.agentic/lib/tools/ag.sh" contract check "$fid" >/dev/null 2>&1; then
                _merge_record failed ok "contract check: $fid"
            else
                _merge_record failed fail "contract check: $fid" \
                    "Run: ag contract check $fid    (see failing assertions)"
            fi
        done
    fi

    # AC1.c — `ag contract pending` reports nothing for the detected features.
    local pending_out
    pending_out=$(bash "$ROOT_DIR/.agentic/lib/tools/ag.sh" contract pending 2>&1 || true)
    if [[ -n "$features" ]]; then
        local pending_features=""
        for fid in $features; do
            if echo "$pending_out" | grep -qE "(^|[^A-Za-z0-9])${fid}([^A-Za-z0-9]|$)"; then
                pending_features="$pending_features $fid"
            fi
        done
        if [[ -z "$pending_features" ]]; then
            _merge_record failed ok "no pending user_input on detected features"
        else
            _merge_record failed fail "pending user_input on:$pending_features" \
                "Run: ag contract pending     (resolve before merging)"
        fi
    fi

    # AC1.a — feature status in FEATURES.md. The merge precedes `ag done`,
    # so the expected state is "in_progress" or "ready" — *not* "shipped"
    # (which would mean the merge already happened). We block only on the
    # missing-from-FEATURES.md case, which signals a feature that was never
    # tracked.
    if [[ -n "$features" ]] && [[ -f "$ROOT_DIR/.agentic/spec/FEATURES.md" ]]; then
        local untracked=""
        for fid in $features; do
            # Strip dotted children for the FEATURES.md lookup (parent owns the row).
            local parent="${fid%%.*}"
            if ! grep -qE "(^|[^A-Za-z0-9])${parent}([^A-Za-z0-9]|$)" \
                  "$ROOT_DIR/.agentic/spec/FEATURES.md"; then
                untracked="$untracked $fid"
            fi
        done
        if [[ -z "$untracked" ]]; then
            _merge_record failed ok "all features tracked in FEATURES.md"
        else
            _merge_record failed fail "untracked in FEATURES.md:$untracked" \
                "Run: bash .agentic/lib/tools/feature.sh cap add ..."
        fi
    fi

    # AC1.d — CI mirror status (R-006). Advisory: skipped silently when
    # gh cli isn't available, no GitHub remote, or no recent run for the
    # branch. R-006 will tighten this once the workflow ships.
    if command -v gh >/dev/null 2>&1 \
       && git remote get-url origin >/dev/null 2>&1; then
        local ci_status
        ci_status=$(gh run list --branch "$branch" --limit 1 \
                    --json conclusion -q '.[0].conclusion' 2>/dev/null || echo "")
        case "$ci_status" in
            success)
                _merge_record failed ok "CI mirror: success on $branch"
                ;;
            failure|cancelled|timed_out)
                _merge_record failed fail "CI mirror: $ci_status on $branch" \
                    "Run: gh run list --branch $branch    (then re-run / fix)"
                ;;
            *)
                # No run yet, or gh returned empty. Advisory note, no block.
                echo -e "  ${YELLOW}!${NC} CI mirror: no recent run for $branch (advisory)"
                ;;
        esac
    fi

    echo ""
    if [[ ${#failed[@]} -eq 0 ]]; then
        echo -e "${GREEN}gate pass${NC} — proceed with merge"
        _MERGE_GATE_FEATURES="$features"
        return 0
    fi

    echo -e "${RED}gate blocked${NC} — ${#failed[@]} check(s) failed"
    echo ""
    echo "Bypass with audit (use sparingly):"
    echo "  ag merge $branch --skip-gate \"<reason>\""
    _MERGE_GATE_FEATURES="$features"
    return 2
}

# Top-level local-merge handler: gate, then `git merge --no-ff`.
# Always emits a `merge_attempt` event; honors `--skip-gate "<reason>"`.
_merge_local() {
    local branch="$1"; shift 2>/dev/null || true

    local skip_reason=""
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --skip-gate)
                skip_reason="${2:-unspecified}"
                shift 2
                ;;
            *) shift ;;
        esac
    done

    _MERGE_GATE_FEATURES=""

    local rc=0
    if [[ -n "$skip_reason" ]]; then
        echo -e "${YELLOW}ag merge gate skipped (audited): $skip_reason${NC}"
        # Still discover features so the audit event is informative.
        _MERGE_GATE_FEATURES=$(_merge_discover_features "$branch" HEAD)
        # Emit a sanctioned-skip event analogous to ag commit/push --skip-gate.
        PYTHONPATH="$ROOT_DIR/.agentic/lib" \
        _AG_BRANCH="$branch" _AG_REASON="$skip_reason" \
        _AG_SESSION="${AG_SESSION_ID:-cli-$$}" \
        python3 - <<'PY' 2>/dev/null || true
import os
from events import append_event
append_event(
    type="gate_skipped",
    session_id=os.environ["_AG_SESSION"],
    actor="ag merge",
    payload={"gate": "merge_local", "branch": os.environ["_AG_BRANCH"],
             "reason": os.environ["_AG_REASON"]},
)
PY
    else
        # Capture rc BEFORE any other command — `if ! cmd; then rc=$?` would
        # clobber it (after `!`, $? reflects the negation, not the original).
        _merge_local_gate "$branch"
        rc=$?
        if [[ $rc -ne 0 ]]; then
            _merge_emit_event "$branch" "blocked" "$_MERGE_GATE_FEATURES" "$rc"
            return $rc
        fi
    fi

    # Build an audit-friendly merge commit message.
    local features_inline=""
    if [[ -n "$_MERGE_GATE_FEATURES" ]]; then
        features_inline=" ($(echo "$_MERGE_GATE_FEATURES" | tr '\n' ',' | sed 's/,$//'))"
    fi
    local audit_note=""
    [[ -n "$skip_reason" ]] && audit_note=$'\n\nGate skipped: '"$skip_reason"

    echo ""
    echo -e "${BOLD}Running git merge --no-ff${NC}"
    if git merge --no-ff "$branch" \
        -m "Merge branch '$branch'${features_inline}${audit_note}" >/dev/null; then
        echo -e "${GREEN}✓ merged $branch${NC}"
        _merge_emit_event "$branch" "merged" "$_MERGE_GATE_FEATURES" 0
        return 0
    fi

    rc=$?
    echo -e "${RED}git merge failed (rc=$rc); resolve conflicts and retry${NC}" >&2
    _merge_emit_event "$branch" "error" "$_MERGE_GATE_FEATURES" "$rc"
    return "$rc"
}
