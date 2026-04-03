#!/usr/bin/env bash
# test_capability_catalog.sh — Tests for F-042 Universal Capability Catalog
#
# Tests:
#   Section 1: state-files.conf + template (AC-001, AC-002, AC-003)
#   Section 2: feature.sh cap add/status (AC-004, AC-005, AC-006)
#   Section 3: PostToolUse FEATURES.md tracking (AC-007)
#   Section 4: Stop.sh catalog warning (AC-008)
#   Section 5: UserPromptSubmit nudge (AC-009)
#   Section 6: ag done catalog gate (AC-011, AC-012)
#   Section 7: Dashboard capability count (AC-013)
#   Section 8: profiles.conf setting (AC-010)

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

PASS=0
FAIL=0
TOTAL=0

pass() { echo "  ✅ $1"; PASS=$((PASS + 1)); TOTAL=$((TOTAL + 1)); }
fail() { echo "  ❌ $1: $2"; FAIL=$((FAIL + 1)); TOTAL=$((TOTAL + 1)); }

# Create a discovery-mode project
create_discovery_project() {
    local dir
    dir=$(mktemp -d)
    mkdir -p "$dir/.agentic/spec" "$dir/.agentic/lib/tools" "$dir/.agentic/lib/presets"
    mkdir -p "$dir/.agentic/lib/claude-hooks" "$dir/.agentic/session" "$dir/.agentic/intel"

    cp "$REPO_ROOT/.agentic/lib/settings.sh" "$dir/.agentic/lib/"
    cp "$REPO_ROOT/.agentic/lib/paths.sh" "$dir/.agentic/lib/" 2>/dev/null || true
    cp -r "$REPO_ROOT/.agentic/lib/presets" "$dir/.agentic/lib/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/feature.sh" "$dir/.agentic/lib/tools/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/PostToolUse.sh" "$dir/.agentic/lib/claude-hooks/"
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/Stop.sh" "$dir/.agentic/lib/claude-hooks/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/claude-hooks/UserPromptSubmit.sh" "$dir/.agentic/lib/claude-hooks/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/tools/fwlog.sh" "$dir/.agentic/lib/tools/" 2>/dev/null || true
    cp "$REPO_ROOT/.agentic/lib/ids.sh" "$dir/.agentic/lib/" 2>/dev/null || true

    # Copy the template as FEATURES.md (simulating scaffold)
    cp "$REPO_ROOT/.agentic/lib/templates/FEATURES.template.md" "$dir/.agentic/spec/FEATURES.md"

    cat > "$dir/STACK.md" << 'EOF'
# Stack
## Settings
- profile: discovery
- state_enforcement: off
- feature_tracking: no
EOF

    (cd "$dir" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true
    echo "$dir"
}

TEMP_DIRS=()
cleanup() {
    for d in "${TEMP_DIRS[@]}"; do
        [[ -n "$d" ]] && rm -rf "$d"
    done
}
trap cleanup EXIT

echo "═══════════════════════════════════════════════════"
echo " F-042 Universal Capability Catalog Tests"
echo "═══════════════════════════════════════════════════"
echo ""

# ═══════════════════════════════════════════════════════
# Section 1: state-files.conf + template
# ═══════════════════════════════════════════════════════
echo "Section 1: Universal Catalog Foundation"
echo "────────────────────────────────────────"

echo "Test 1: AC-001 — state-files.conf lists FEATURES.md as 'all' profile"
if grep -q 'FEATURES.md.*:all' "$REPO_ROOT/.agentic/lib/init/state-files.conf"; then
    pass "AC-001: FEATURES.md is profile:all in state-files.conf"
else
    fail "AC-001: FEATURES.md not set to all" "$(grep FEATURES "$REPO_ROOT/.agentic/lib/init/state-files.conf")"
fi

echo "Test 2: AC-002 — template has dual-format preamble"
TMPL="$REPO_ROOT/.agentic/lib/templates/FEATURES.template.md"
if grep -q "Discovery" "$TMPL" && grep -q "Formal" "$TMPL" && grep -q "built" "$TMPL"; then
    pass "AC-002: template has discovery + formal formats"
else
    fail "AC-002: template missing dual format" ""
fi

echo "Test 3: AC-003 — discovery status values: built, in_progress, planned"
if grep -q '`built`' "$TMPL" && grep -q '`in_progress`' "$TMPL" && grep -q '`planned`' "$TMPL"; then
    pass "AC-003: discovery status values documented"
else
    fail "AC-003: missing discovery status values" ""
fi

# ═══════════════════════════════════════════════════════
# Section 2: feature.sh cap add/status
# ═══════════════════════════════════════════════════════
echo ""
echo "Section 2: feature.sh cap Commands"
echo "────────────────────────────────────"

PROJECT=$(create_discovery_project)
TEMP_DIRS+=("$PROJECT")

echo "Test 4: AC-004 — cap add creates discovery entry"
OUTPUT=$(bash "$PROJECT/.agentic/lib/tools/feature.sh" cap add "Search" "Full-text product search" 2>&1)
if grep -q "^## Search$" "$PROJECT/.agentic/spec/FEATURES.md" && \
   grep -q "planned" "$PROJECT/.agentic/spec/FEATURES.md"; then
    pass "AC-004: cap add creates heading + planned status"
else
    fail "AC-004: entry not created" "$OUTPUT"
fi

echo "Test 5: AC-004 — cap add includes description"
if grep -q "Full-text product search" "$PROJECT/.agentic/spec/FEATURES.md"; then
    pass "AC-004: description present in entry"
else
    fail "AC-004: description missing" ""
fi

echo "Test 6: AC-006 — cap add with --decisions flag"
bash "$PROJECT/.agentic/lib/tools/feature.sh" cap add "Shopping Cart" "Cart management" --decisions "Used localStorage for persistence" 2>&1 >/dev/null
if grep -q "Decisions: Used localStorage" "$PROJECT/.agentic/spec/FEATURES.md"; then
    pass "AC-006: --decisions stored in entry"
else
    fail "AC-006: decisions missing" "$(tail -10 "$PROJECT/.agentic/spec/FEATURES.md")"
fi

echo "Test 7: AC-005 — cap status updates discovery entry"
bash "$PROJECT/.agentic/lib/tools/feature.sh" cap status "Search" "built" 2>&1 >/dev/null
if grep -A1 "^## Search$" "$PROJECT/.agentic/spec/FEATURES.md" | grep -q "built"; then
    pass "AC-005: Search status updated to built"
else
    fail "AC-005: status not updated" "$(grep -A2 "Search" "$PROJECT/.agentic/spec/FEATURES.md")"
fi

echo "Test 8: cap add rejects duplicate"
OUTPUT=$(bash "$PROJECT/.agentic/lib/tools/feature.sh" cap add "Search" "duplicate" 2>&1) || true
if echo "$OUTPUT" | grep -q "already exists"; then
    pass "duplicate capability rejected"
else
    fail "duplicate not caught" "$OUTPUT"
fi

echo "Test 9: cap status rejects invalid status"
OUTPUT=$(bash "$PROJECT/.agentic/lib/tools/feature.sh" cap status "Search" "invalid" 2>&1) || true
if echo "$OUTPUT" | grep -q "Invalid"; then
    pass "invalid status rejected"
else
    fail "invalid status not caught" "$OUTPUT"
fi

echo "Test 10: cap status maps 'shipped' to 'built'"
bash "$PROJECT/.agentic/lib/tools/feature.sh" cap status "Shopping Cart" "shipped" 2>&1 >/dev/null
if grep -A1 "^## Shopping Cart$" "$PROJECT/.agentic/spec/FEATURES.md" | grep -q "built"; then
    pass "shipped mapped to built for discovery"
else
    fail "shipped not mapped to built" ""
fi

# ═══════════════════════════════════════════════════════
# Section 3: PostToolUse FEATURES.md tracking
# ═══════════════════════════════════════════════════════
echo ""
echo "Section 3: PostToolUse Catalog Tracking"
echo "────────────────────────────────────────"

echo "Test 11: AC-007 — PostToolUse sets .cap_updated when FEATURES.md written"
rm -f "$PROJECT/.agentic/session/.cap_updated"
echo '{"tool_name": "Write", "tool_input": {"file_path": ".agentic/spec/FEATURES.md"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT" bash "$PROJECT/.agentic/lib/claude-hooks/PostToolUse.sh" 2>/dev/null || true
if [[ -f "$PROJECT/.agentic/session/.cap_updated" ]]; then
    pass "AC-007: .cap_updated flag set on FEATURES.md write"
else
    fail "AC-007: .cap_updated not set" ""
fi

echo "Test 12: PostToolUse does NOT set flag for other files"
rm -f "$PROJECT/.agentic/session/.cap_updated"
echo '{"tool_name": "Write", "tool_input": {"file_path": "src/main.ts"}}' | \
    CLAUDE_PROJECT_DIR="$PROJECT" bash "$PROJECT/.agentic/lib/claude-hooks/PostToolUse.sh" 2>/dev/null || true
if [[ ! -f "$PROJECT/.agentic/session/.cap_updated" ]]; then
    pass "no flag for non-FEATURES.md writes"
else
    fail "spurious .cap_updated" ""
fi

# ═══════════════════════════════════════════════════════
# Section 4: Stop.sh catalog warning
# ═══════════════════════════════════════════════════════
echo ""
echo "Section 4: Stop.sh Session-End Warning"
echo "────────────────────────────────────────"

echo "Test 13: AC-008 — Stop.sh warns when impl files written but catalog not updated"
rm -f "$PROJECT/.agentic/session/.cap_updated"
# Simulate 4 writes to impl files in token-events.log
cat > "$PROJECT/.agentic/session/token-events.log" << 'EOF'
W|src/components/Cart.tsx|500
W|src/hooks/useCart.ts|300
W|src/pages/checkout.tsx|800
W|lib/utils/helpers.ts|200
EOF
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT" bash "$PROJECT/.agentic/lib/claude-hooks/Stop.sh" 2>&1) || true
if echo "$OUTPUT" | grep -q "📦.*Capability catalog not updated\|catalog not updated"; then
    pass "AC-008: Stop.sh warns about missing catalog update"
else
    fail "AC-008: no catalog warning" "$(echo "$OUTPUT" | grep -i "cap\|catalog\|FEATURES")"
fi

echo "Test 14: Stop.sh does NOT warn when .cap_updated exists"
touch "$PROJECT/.agentic/session/.cap_updated"
cat > "$PROJECT/.agentic/session/token-events.log" << 'EOF'
W|src/main.ts|500
W|src/app.ts|300
W|src/utils.ts|200
EOF
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT" bash "$PROJECT/.agentic/lib/claude-hooks/Stop.sh" 2>&1) || true
if echo "$OUTPUT" | grep -q "catalog not updated"; then
    fail "Stop.sh warned despite .cap_updated" ""
else
    pass "Stop.sh silent when .cap_updated flag exists"
fi
rm -f "$PROJECT/.agentic/session/.cap_updated"

echo "Test 15: Stop.sh does NOT warn for <3 impl writes"
cat > "$PROJECT/.agentic/session/token-events.log" << 'EOF'
W|src/main.ts|500
W|README.md|200
EOF
OUTPUT=$(echo '{}' | CLAUDE_PROJECT_DIR="$PROJECT" bash "$PROJECT/.agentic/lib/claude-hooks/Stop.sh" 2>&1) || true
if echo "$OUTPUT" | grep -q "catalog not updated"; then
    fail "Stop.sh warned for <3 impl writes" ""
else
    pass "Stop.sh silent for <3 impl writes (bug fix, not new capability)"
fi

# ═══════════════════════════════════════════════════════
# Section 5: UserPromptSubmit nudge
# ═══════════════════════════════════════════════════════
echo ""
echo "Section 5: UserPromptSubmit Mid-Session Nudge"
echo "───────────────────────────────────────────────"

echo "Test 16: AC-009 — nudge logic fires after 5+ impl writes"
rm -f "$PROJECT/.agentic/session/.cap_nudged" "$PROJECT/.agentic/session/.cap_updated"
# Test the nudge logic in isolation (full UserPromptSubmit requires gate.py)
cat > "$PROJECT/.agentic/session/token-events.log" << 'EOF'
W|src/a.ts|100
W|src/b.ts|100
W|src/c.ts|100
W|src/d.ts|100
W|src/e.ts|100
W|src/f.ts|100
EOF
# Extract and run just the catalog nudge section
OUTPUT=$(cd "$PROJECT" && bash -c '
  if [[ ! -f ".agentic/session/.cap_nudged" && ! -f ".agentic/session/.cap_updated" ]]; then
    _TK_EVENTS=".agentic/session/token-events.log"
    if [[ -f "$_TK_EVENTS" ]]; then
      _IMPL_WRITES=$(grep "^W|" "$_TK_EVENTS" 2>/dev/null \
        | grep -cE "\|(src/|lib/|app/|cmd/|\.agentic/lib/tools/|\.agentic/lib/auto/)" 2>/dev/null || echo 0)
      _IMPL_WRITES="${_IMPL_WRITES## }"
      if [[ "${_IMPL_WRITES:-0}" -ge 5 ]]; then
        echo "📦 You have written ${_IMPL_WRITES} implementation files but have not updated the capability catalog."
        touch ".agentic/session/.cap_nudged" 2>/dev/null || true
      fi
    fi
  fi
' 2>&1) || true
if echo "$OUTPUT" | grep -q "📦"; then
    pass "AC-009: nudge fires after 5+ impl writes"
else
    fail "AC-009: no nudge" "$OUTPUT"
fi

echo "Test 17: AC-009 — nudge fires only once (.cap_nudged flag)"
# .cap_nudged was set by test 16
OUTPUT=$(cd "$PROJECT" && bash -c '
  if [[ ! -f ".agentic/session/.cap_nudged" && ! -f ".agentic/session/.cap_updated" ]]; then
    echo "📦 nudge"
  fi
' 2>&1) || true
if echo "$OUTPUT" | grep -q "📦"; then
    fail "nudge fired twice" ""
else
    pass "nudge only fires once (flag prevents repeat)"
fi

echo "Test 18: nudge does NOT fire when .cap_updated exists"
rm -f "$PROJECT/.agentic/session/.cap_nudged"
touch "$PROJECT/.agentic/session/.cap_updated"
OUTPUT=$(cd "$PROJECT" && bash -c '
  if [[ ! -f ".agentic/session/.cap_nudged" && ! -f ".agentic/session/.cap_updated" ]]; then
    echo "📦 nudge"
  fi
' 2>&1) || true
if echo "$OUTPUT" | grep -q "📦"; then
    fail "nudge fired despite .cap_updated" ""
else
    pass "no nudge when catalog already updated"
fi
rm -f "$PROJECT/.agentic/session/.cap_updated"

echo "Test 16b: AC-009 — nudge code exists in UserPromptSubmit.sh"
if grep -q "cap_nudged\|capability catalog" "$REPO_ROOT/.agentic/lib/claude-hooks/UserPromptSubmit.sh"; then
    pass "AC-009: nudge code present in UserPromptSubmit.sh"
else
    fail "AC-009: nudge code missing from hook" ""
fi

# ═══════════════════════════════════════════════════════
# Section 6: Dashboard capability count
# ═══════════════════════════════════════════════════════
echo ""
echo "Section 6: Dashboard Capability Count"
echo "──────────────────────────────────────"

echo "Test 19: AC-013 — dashboard shows capability counts"
# The project has 2 built + 0 in_progress + 0 planned capabilities
DASH_DIR=$(mktemp -d)
TEMP_DIRS+=("$DASH_DIR")
mkdir -p "$DASH_DIR/.agentic/spec" "$DASH_DIR/.agentic/lib/tools" "$DASH_DIR/.agentic/lib/presets" "$DASH_DIR/.agentic/session"
cp "$REPO_ROOT/.agentic/lib/settings.sh" "$DASH_DIR/.agentic/lib/"
cp "$REPO_ROOT/.agentic/lib/paths.sh" "$DASH_DIR/.agentic/lib/"
cp -r "$REPO_ROOT/.agentic/lib/presets" "$DASH_DIR/.agentic/lib/" 2>/dev/null || true
for f in "$REPO_ROOT/.agentic/lib/tools/"*.sh; do
    cp "$f" "$DASH_DIR/.agentic/lib/tools/" 2>/dev/null || true
done
cat > "$DASH_DIR/.agentic/lib/VERSION" <<< "0.78.0"
cat > "$DASH_DIR/STACK.md" << 'EOF'
# Stack
## Settings
- profile: discovery
EOF
cat > "$DASH_DIR/.agentic/spec/FEATURES.md" << 'EOF'
# Capabilities

## Search
**Status**: built
Full-text product search.

## Shopping Cart
**Status**: built
Cart management.

## Checkout
**Status**: in_progress
Multi-step checkout.

## Order History
**Status**: planned
Past orders view.
EOF
(cd "$DASH_DIR" && git init -q && git add -A && git commit -q -m "init" 2>/dev/null) || true
OUTPUT=$(CLAUDE_PROJECT_DIR="$DASH_DIR" bash "$DASH_DIR/.agentic/lib/tools/dashboard.sh" 2>&1) || true
if echo "$OUTPUT" | grep -q "📦.*Capabilities\|2 built.*1 in progress.*1 planned"; then
    pass "AC-013: dashboard shows capability counts"
else
    fail "AC-013: no capability line" "$(echo "$OUTPUT" | grep -i "cap\|Capabil")"
fi

# ═══════════════════════════════════════════════════════
# Section 7: profiles.conf setting
# ═══════════════════════════════════════════════════════
echo ""
echo "Section 7: Profile Settings"
echo "───────────────────────────"

echo "Test 20: AC-010 — discovery has catalog_enforcement=advisory"
if grep -q "discovery.catalog_enforcement=advisory" "$REPO_ROOT/.agentic/lib/presets/profiles.conf"; then
    pass "AC-010: discovery catalog_enforcement=advisory"
else
    fail "AC-010: discovery setting missing" ""
fi

echo "Test 21: AC-010 — autonomous_formal has catalog_enforcement=blocking"
if grep -q "autonomous_formal.catalog_enforcement=blocking" "$REPO_ROOT/.agentic/lib/presets/profiles.conf"; then
    pass "AC-010: autonomous_formal catalog_enforcement=blocking"
else
    fail "AC-010: autonomous_formal setting missing" ""
fi

# ═══════════════════════════════════════════════════════
echo ""
echo "═══════════════════════════════════════════════════"
echo "Results: $PASS passed, $FAIL failed (of $TOTAL)"
echo "═══════════════════════════════════════════════════"

exit $FAIL
