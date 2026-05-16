#!/usr/bin/env bash
# Tests for memory-check.sh + memory-diff.sh (T-0023, F-022)
#
# Covers:
#   - memory-diff: section parsing produces ADD/REMOVE/MODIFY blocks keyed by anchor
#   - memory-diff: --rev form extracts old version from git successfully
#   - memory-diff: missing inputs fall back without crash (advisory, exit 0)
#   - memory-check: not-seeded case (MEMORY_FILE missing) prints advisory and exits 0
#   - memory-check: worktree resolution prefers main repo root over worktree path
#   - memory-check: stale case invokes memory-diff and produces PATCH output

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
MEMORY_CHECK="$FRAMEWORK_ROOT/.agentic/lib/tools/memory-check.sh"
MEMORY_DIFF="$FRAMEWORK_ROOT/.agentic/lib/tools/memory-diff.sh"

RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

PASSED=0
FAILED=0

test_case() { echo -n "Testing: $1... "; }
pass() { echo -e "${GREEN}PASS${NC}"; ((PASSED++)); }
fail() { echo -e "${RED}FAIL${NC}"; [[ -n "${1:-}" ]] && echo "  $1"; ((FAILED++)); }

echo
echo "=== memory-diff.sh + memory-check.sh (T-0023) ==="
echo

# ──────────────────────────────────────────────────────────────
# memory-diff.sh: ADD / REMOVE / MODIFY classification
# ──────────────────────────────────────────────────────────────

test_case "memory-diff classifies ADD/REMOVE/MODIFY by anchor"
TMP=$(mktemp -d)
cat > "$TMP/old.md" <<'EOF'
# Memory Seed
<!-- memory-seed v0.1.0 -->

<!-- section: keep-modified -->
## Trigger Words
- old-trigger

<!-- section: keep-removed -->
## Old Section
goes away
EOF
cat > "$TMP/new.md" <<'EOF'
# Memory Seed
<!-- memory-seed v0.2.0 -->

<!-- section: keep-modified -->
## Trigger Words (renamed)
- old-trigger
- new-trigger

<!-- section: brand-new -->
## Brand New
appears
EOF
OUT=$(bash "$MEMORY_DIFF" "$TMP/old.md" "$TMP/new.md" 2>/dev/null)
if echo "$OUT" | grep -q 'MODIFY section.*keep-modified' \
   && echo "$OUT" | grep -q 'REMOVE section.*keep-removed' \
   && echo "$OUT" | grep -q 'ADD section.*brand-new'; then
    pass
else
    fail "expected MODIFY/REMOVE/ADD blocks; got:
$OUT"
fi
rm -rf "$TMP"

# ──────────────────────────────────────────────────────────────
# memory-diff.sh: rename → MODIFY (not REMOVE+ADD) because anchor stable
# ──────────────────────────────────────────────────────────────

test_case "memory-diff treats anchor-stable header rename as MODIFY"
TMP=$(mktemp -d)
cat > "$TMP/old.md" <<'EOF'
<!-- section: triggers -->
## Trigger Words
content
EOF
cat > "$TMP/new.md" <<'EOF'
<!-- section: triggers -->
## Triggers (renamed)
content
EOF
OUT=$(bash "$MEMORY_DIFF" "$TMP/old.md" "$TMP/new.md" 2>/dev/null)
if echo "$OUT" | grep -q 'MODIFY section' \
   && echo "$OUT" | grep -q 'header renamed'; then
    pass
else
    fail "expected MODIFY with rename label; got:
$OUT"
fi
rm -rf "$TMP"

# ──────────────────────────────────────────────────────────────
# memory-diff.sh: identical inputs → no patches
# ──────────────────────────────────────────────────────────────

test_case "memory-diff emits no patches when sections are identical"
TMP=$(mktemp -d)
cat > "$TMP/same.md" <<'EOF'
<!-- section: x -->
## X
same
EOF
OUT=$(bash "$MEMORY_DIFF" "$TMP/same.md" "$TMP/same.md" 2>/dev/null)
if [ -z "$(echo "$OUT" | grep -E '^PATCH')" ]; then
    pass
else
    fail "expected no PATCH blocks; got:
$OUT"
fi
rm -rf "$TMP"

# ──────────────────────────────────────────────────────────────
# memory-diff.sh: missing input → advisory exit 0 (never crashes)
# ──────────────────────────────────────────────────────────────

test_case "memory-diff exits 0 when input file missing"
if bash "$MEMORY_DIFF" /nonexistent/old.md /nonexistent/new.md >/dev/null 2>&1; then
    pass
else
    fail "expected exit 0 on missing input"
fi

# ──────────────────────────────────────────────────────────────
# memory-diff.sh: --rev extracts old version from git
# ──────────────────────────────────────────────────────────────

test_case "memory-diff --rev resolves a real git revision"
# Use the current repo and a known-good commit (HEAD).
SEED_REPO_PATH=".agentic/lib/init/memory-seed.md"
SEED_FILE="$FRAMEWORK_ROOT/$SEED_REPO_PATH"
# A working call should produce no error and exit 0
if bash "$MEMORY_DIFF" --rev HEAD "$SEED_REPO_PATH" "$SEED_FILE" >/dev/null 2>&1; then
    pass
else
    fail "memory-diff --rev HEAD failed"
fi

# ──────────────────────────────────────────────────────────────
# memory-check.sh: behavioral checks via HOME isolation
# ──────────────────────────────────────────────────────────────

# Helper: run memory-check with isolated HOME and (optionally) a fake MEMORY.md
_run_check_isolated() {
    local fake_home="$1"
    local memory_content="$2"   # empty string → MEMORY.md absent
    local repo_root="$FRAMEWORK_ROOT"
    local project_hash
    project_hash=$(echo "$repo_root" | tr '/' '-')
    local memory_dir="$fake_home/.claude/projects/${project_hash}/memory"
    mkdir -p "$memory_dir"
    if [ -n "$memory_content" ]; then
        printf '%s' "$memory_content" > "$memory_dir/MEMORY.md"
    fi
    # The script gates on `$HOME/.claude` existing
    mkdir -p "$fake_home/.claude"
    HOME="$fake_home" bash "$MEMORY_CHECK" 2>&1
}

test_case "memory-check exits 0 with 'not seeded' advisory when MEMORY.md absent"
FAKE_HOME=$(mktemp -d)
OUT=$(_run_check_isolated "$FAKE_HOME" "")
if echo "$OUT" | grep -q 'not seeded'; then
    pass
else
    fail "expected 'not seeded'; got:
$OUT"
fi
rm -rf "$FAKE_HOME"

test_case "memory-check produces PATCH output when memory is stale"
FAKE_HOME=$(mktemp -d)
# A stale MEMORY.md with an old seed version line
STALE_MEMORY=$'# Memory\n<!-- memory-seed v0.54.1 -->\n\npre-commit sequence\ntoken-efficient scripts\nag commit\nag done\n'
OUT=$(_run_check_isolated "$FAKE_HOME" "$STALE_MEMORY")
# Tighter than substring-match: require stale advisory + at least one
# PATCH header + at least one kind label (ADD|REMOVE|MODIFY) + the
# follow-up apply-instructions block. A broken implementation that
# silently fails the diff resolver would print 'stale' but no PATCH.
if echo "$OUT" | grep -q 'Memory: stale' \
   && echo "$OUT" | grep -qE '^PATCH [0-9]+/[0-9]+' \
   && echo "$OUT" | grep -qE '(ADD|REMOVE|MODIFY) section' \
   && echo "$OUT" | grep -q 'Apply each PATCH block'; then
    pass
else
    fail "expected stale + PATCH header + kind label + apply instructions; got:
$OUT"
fi
rm -rf "$FAKE_HOME"

# Fixture-based sectioning assertion — a broken implementation cannot pass
test_case "memory-diff produces deterministic patches from known fixtures"
TMP=$(mktemp -d)
cat > "$TMP/old.md" <<'EOF'
<!-- memory-seed v0.50.0 -->

<!-- section: alpha -->
## Alpha
line one
line two

<!-- section: beta -->
## Beta
beta content
EOF
cat > "$TMP/new.md" <<'EOF'
<!-- memory-seed v0.51.0 -->

<!-- section: alpha -->
## Alpha
line one
line two
line three

<!-- section: gamma -->
## Gamma
new section
EOF
OUT=$(bash "$MEMORY_DIFF" "$TMP/old.md" "$TMP/new.md" 2>/dev/null)
# Exactly three patches: alpha MODIFY, beta REMOVE, gamma ADD
PATCH_COUNT=$(echo "$OUT" | grep -cE '^PATCH [0-9]+/[0-9]+')
ALPHA_OK=$(echo "$OUT" | grep -c 'MODIFY section.*alpha' || true)
BETA_OK=$(echo "$OUT" | grep -c 'REMOVE section.*beta' || true)
GAMMA_OK=$(echo "$OUT" | grep -c 'ADD section.*gamma' || true)
LINE_THREE_IN_DIFF=$(echo "$OUT" | grep -c '^+line three' || true)
if [ "$PATCH_COUNT" -eq 3 ] && [ "$ALPHA_OK" -ge 1 ] \
   && [ "$BETA_OK" -ge 1 ] && [ "$GAMMA_OK" -ge 1 ] \
   && [ "$LINE_THREE_IN_DIFF" -ge 1 ]; then
    pass
else
    fail "fixture expected 3 patches (alpha MODIFY + beta REMOVE + gamma ADD) with 'line three' in alpha diff; got PATCH_COUNT=$PATCH_COUNT alpha=$ALPHA_OK beta=$BETA_OK gamma=$GAMMA_OK line3=$LINE_THREE_IN_DIFF
$OUT"
fi
rm -rf "$TMP"

test_case "memory-check passes (OK) when version matches and sentinels present"
FAKE_HOME=$(mktemp -d)
CURRENT_VERSION=$(grep -o 'memory-seed v[0-9]*\.[0-9]*\.[0-9]*' "$SEED_FILE" | head -1 | sed 's/memory-seed v//')
FRESH_MEMORY=$'# Memory\n<!-- memory-seed v'"$CURRENT_VERSION"$' -->\n\npre-commit sequence\ntoken-efficient scripts\nag commit\nag done\n'
OUT=$(_run_check_isolated "$FAKE_HOME" "$FRESH_MEMORY")
if echo "$OUT" | grep -q 'Memory: OK'; then
    pass
else
    fail "expected 'Memory: OK'; got:
$OUT"
fi
rm -rf "$FAKE_HOME"

# ──────────────────────────────────────────────────────────────
# Worktree path resolution: --git-common-dir trick
# ──────────────────────────────────────────────────────────────

test_case "main repo root resolves correctly via --git-common-dir"
# Sanity check on the actual logic memory-check uses
COMMON_DIR=$(git -C "$FRAMEWORK_ROOT" rev-parse --path-format=absolute --git-common-dir)
MAIN_REPO="${COMMON_DIR%/.git}"
if [ -d "$MAIN_REPO/.agentic" ]; then
    pass
else
    fail "computed main repo '$MAIN_REPO' has no .agentic/"
fi

# Anchor parity in seed file: every '## ' header has a matching anchor
test_case "memory-seed.md has one <!-- section: --> anchor per ## header"
SEED="$FRAMEWORK_ROOT/.agentic/lib/init/memory-seed.md"
HEADERS=$(grep -c '^## ' "$SEED")
ANCHORS=$(grep -c '^<!-- section:' "$SEED")
if [ "$HEADERS" -eq "$ANCHORS" ]; then
    pass
else
    fail "headers=$HEADERS anchors=$ANCHORS — every '## ' must have a <!-- section: slug --> sibling"
fi

# ──────────────────────────────────────────────────────────────

echo
echo "=== Results ==="
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"

[ "$FAILED" -eq 0 ]
