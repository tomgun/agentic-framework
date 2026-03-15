#!/usr/bin/env bash
# S11: Shared AC parser (ac-parse.sh) handles all AC formats correctly
# Verifies: checkbox, bare/legacy, heading, priority groups, mixed formats
set -euo pipefail
source "$(dirname "$0")/../lib/helpers.sh"

section_header "S11: Shared AC parser handles all AC formats"

# Source the parser
source ".agentic/lib/tools/ac-parse.sh"

# --- Test fixtures ---
TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

# Fixture: checkbox format with bold AC IDs
cat > "$TMPDIR/checkbox.md" << 'EOF'
## Acceptance Criteria

- [x] **AC-001**: First criterion
- [ ] **AC-002**: Second criterion
- [x] **AC-003**: Third criterion
EOF

# Fixture: flat checkbox without bold
cat > "$TMPDIR/flat.md" << 'EOF'
## Acceptance Criteria

- [ ] AC1: First criterion
- [ ] AC2: Second criterion
- [ ] AC3: Third criterion
- [ ] AC4: Fourth criterion
EOF

# Fixture: bare/legacy format (no checkboxes)
cat > "$TMPDIR/bare.md" << 'EOF'
## Acceptance Criteria

- AC-001: First criterion
- AC-002: Second criterion
- AC-003: Third criterion
EOF

# Fixture: priority groups
cat > "$TMPDIR/grouped.md" << 'EOF'
## Acceptance Criteria

### Core Behavior (P1 — MVP)
- [x] **AC-001**: First P1
- [x] **AC-002**: Second P1
- [ ] **AC-003**: Third P1

### Enhanced (P2 — optional)
- [ ] **AC-004**: First P2
- [ ] **AC-005**: Second P2
EOF

# Fixture: mixed format (groups + ungrouped)
cat > "$TMPDIR/mixed.md" << 'EOF'
## Acceptance Criteria

- [x] **AC-001**: Ungrouped checked

### Core (P1a — MVP)
- [x] **AC-002**: P1 checked
- [ ] **AC-003**: P1 unchecked

### Nice to Have (P2 — optional)
- [ ] **AC-004**: P2 unchecked
EOF

# Fixture: NFR-tagged ACs
cat > "$TMPDIR/nfr.md" << 'EOF'
## Acceptance Criteria

### Core (P1 — MVP)
- [ ] **AC-001**: Responds within 200ms (NFR-0001)
- [ ] **AC-002**: Has ARIA labels (NFR-0007)
EOF

# --- Tests ---

# Checkbox format
result=$(ac_count_total "$TMPDIR/checkbox.md")
[[ "$result" -eq 3 ]] && pass_test "T-AC01: checkbox total=3" || fail_test "T-AC01: checkbox total=3" "got $result"

result=$(ac_count_checked "$TMPDIR/checkbox.md")
[[ "$result" -eq 2 ]] && pass_test "T-AC02: checkbox checked=2" || fail_test "T-AC02: checkbox checked=2" "got $result"

result=$(ac_count_unchecked "$TMPDIR/checkbox.md")
[[ "$result" -eq 1 ]] && pass_test "T-AC03: checkbox unchecked=1" || fail_test "T-AC03: checkbox unchecked=1" "got $result"

# Flat format (no hyphen in IDs)
result=$(ac_count_total "$TMPDIR/flat.md")
[[ "$result" -eq 4 ]] && pass_test "T-AC04: flat total=4" || fail_test "T-AC04: flat total=4" "got $result"

result=$(ac_count_checked "$TMPDIR/flat.md")
[[ "$result" -eq 0 ]] && pass_test "T-AC05: flat checked=0" || fail_test "T-AC05: flat checked=0" "got $result"

# Bare/legacy format
result=$(ac_count_total "$TMPDIR/bare.md")
[[ "$result" -eq 3 ]] && pass_test "T-AC06: bare total=3" || fail_test "T-AC06: bare total=3" "got $result"

result=$(ac_count_checked "$TMPDIR/bare.md")
[[ "$result" -eq 0 ]] && pass_test "T-AC07: bare checked=0 (legacy=unchecked)" || fail_test "T-AC07: bare checked=0" "got $result"

ac_has_legacy_format "$TMPDIR/bare.md" && pass_test "T-AC08: bare detected as legacy" || fail_test "T-AC08: bare detected as legacy"

# Priority groups
ac_has_priority_groups "$TMPDIR/grouped.md" && pass_test "T-AC09: priority groups detected" || fail_test "T-AC09: priority groups detected"

result=$(ac_count_total_in_group "$TMPDIR/grouped.md" "P1")
[[ "$result" -eq 3 ]] && pass_test "T-AC10: P1 total=3" || fail_test "T-AC10: P1 total=3" "got $result"

result=$(ac_count_checked_in_group "$TMPDIR/grouped.md" "P1")
[[ "$result" -eq 2 ]] && pass_test "T-AC11: P1 checked=2" || fail_test "T-AC11: P1 checked=2" "got $result"

result=$(ac_count_total_in_group "$TMPDIR/grouped.md" "P2")
[[ "$result" -eq 2 ]] && pass_test "T-AC12: P2 total=2" || fail_test "T-AC12: P2 total=2" "got $result"

result=$(ac_completion_pct_in_group "$TMPDIR/grouped.md" "P1")
[[ "$result" -eq 66 ]] && pass_test "T-AC13: P1 pct=66%" || fail_test "T-AC13: P1 pct=66%" "got $result"

# Mixed format (ungrouped + groups)
result=$(ac_count_total_in_group "$TMPDIR/mixed.md" "ungrouped")
[[ "$result" -eq 1 ]] && pass_test "T-AC14: ungrouped total=1" || fail_test "T-AC14: ungrouped total=1" "got $result"

result=$(ac_count_checked_in_group "$TMPDIR/mixed.md" "ungrouped")
[[ "$result" -eq 1 ]] && pass_test "T-AC15: ungrouped checked=1" || fail_test "T-AC15: ungrouped checked=1" "got $result"

result=$(ac_count_total_in_group "$TMPDIR/mixed.md" "P1")
[[ "$result" -eq 2 ]] && pass_test "T-AC16: P1 in mixed=2" || fail_test "T-AC16: P1 in mixed=2" "got $result"

# NFR detection
result=$(ac_count_nfr_tagged "$TMPDIR/nfr.md")
[[ "$result" -eq 2 ]] && pass_test "T-AC17: NFR tagged=2" || fail_test "T-AC17: NFR tagged=2" "got $result"

result=$(ac_list_nfr_refs "$TMPDIR/nfr.md" | wc -l)
result="${result//[[:space:]]/}"
[[ "$result" -eq 2 ]] && pass_test "T-AC18: NFR refs=2 unique IDs" || fail_test "T-AC18: NFR refs=2" "got $result"

# Completion percentage
result=$(ac_completion_pct "$TMPDIR/checkbox.md")
[[ "$result" -eq 66 ]] && pass_test "T-AC19: checkbox pct=66%" || fail_test "T-AC19: checkbox pct=66%" "got $result"

result=$(ac_completion_pct "$TMPDIR/flat.md")
[[ "$result" -eq 0 ]] && pass_test "T-AC20: flat pct=0%" || fail_test "T-AC20: flat pct=0%" "got $result"

# Nonexistent file
result=$(ac_count_total "/nonexistent/file.md")
[[ "$result" -eq 0 ]] && pass_test "T-AC21: nonexistent file=0" || fail_test "T-AC21: nonexistent file=0" "got $result"

# ac_list output
result=$(ac_list "$TMPDIR/grouped.md" | wc -l)
result="${result//[[:space:]]/}"
[[ "$result" -eq 5 ]] && pass_test "T-AC22: ac_list returns 5 lines" || fail_test "T-AC22: ac_list returns 5 lines" "got $result"

result=$(ac_list "$TMPDIR/grouped.md" | grep "^checked|P1|" | wc -l)
result="${result//[[:space:]]/}"
[[ "$result" -eq 2 ]] && pass_test "T-AC23: ac_list P1 checked=2" || fail_test "T-AC23: ac_list P1 checked=2" "got $result"

# --- Double-counting regression: mixed checkbox + bare in same file ---
cat > "$TMPDIR/mixed_format.md" << 'EOF'
## Acceptance Criteria

- [x] **AC-001**: Checkbox checked
- [ ] **AC-002**: Checkbox unchecked
- AC-003: Bare format legacy
EOF

result=$(ac_count_total "$TMPDIR/mixed_format.md")
[[ "$result" -eq 3 ]] && pass_test "T-AC24: mixed checkbox+bare total=3 (no double-count)" || fail_test "T-AC24: mixed checkbox+bare total=3" "got $result"

result=$(ac_count_checked "$TMPDIR/mixed_format.md")
[[ "$result" -eq 1 ]] && pass_test "T-AC25: mixed checkbox+bare checked=1" || fail_test "T-AC25: mixed checkbox+bare checked=1" "got $result"

result=$(ac_count_unchecked "$TMPDIR/mixed_format.md")
[[ "$result" -eq 2 ]] && pass_test "T-AC26: mixed checkbox+bare unchecked=2" || fail_test "T-AC26: mixed checkbox+bare unchecked=2" "got $result"

# Verify bare detection excludes checkbox lines
result=$(echo "- [x] AC-001: test" | { _ac_is_bare "- [x] AC-001: test" && echo "bare" || echo "not_bare"; })
[[ "$result" == "not_bare" ]] && pass_test "T-AC27: checkbox line not detected as bare" || fail_test "T-AC27: checkbox line not detected as bare" "got $result"
