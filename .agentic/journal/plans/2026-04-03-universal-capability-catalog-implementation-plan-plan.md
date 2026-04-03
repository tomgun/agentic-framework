# Universal Capability Catalog - Implementation Plan

## Problem Summary

The Agentic Framework has FEATURES.md as a capability catalog, but it is gated behind formal mode only (via `state-files.conf` line 15: `formal` profile). Discovery mode projects have no central record of capabilities. Even in formal mode, no enforcement exists to ensure the catalog is updated when new capabilities are built.

## Architecture Analysis

### Current Flow

**Formal mode**: `ag implement F-XXXX` -> checks FEATURES.md -> checks contract -> WIP tracking -> code -> pre-commit check 3c (FEATURES.md freshness when specs change) -> `ag done` -> mark shipped.

**Discovery mode**: `ag work "description"` -> WIP tracking (no feature ID) -> code -> pre-commit (skips checks 2, 3c, 12) -> `ag done` (shows lightweight checklist, no feature gate).

### Key Gating Points

1. **`state-files.conf` line 15**: `FEATURES.md` only created for `formal` profile
2. **`feature.sh` line 20-23**: Exits with error if FEATURES.md missing
3. **`implement.sh` line 22-28**: Blocked when `feature_tracking=no`
4. **`plan.sh` line 39-45**: Blocked when `feature_tracking=no`
5. **`specs.sh` line 48-54**: Blocked when `feature_tracking=no` or `spec_directory=no`
6. **`pre-commit-check.sh` check 12 (line 754)**: Only runs when `.agentic/spec/FEATURES.md` exists
7. **`profiles.conf`**: `discovery.feature_tracking=no`, `discovery.spec_directory=no`

### What Already Works

- `OVERVIEW.md` has a "Core Capabilities" section with checkboxes (template line 22-28) - discovery projects already get this
- `STATUS.md` has "Roadmap (lightweight)" and "Decisions needed" sections
- `BACKLOG.json` works for all profiles (not gated)
- `TODO.md` works for all profiles
- `cerebrum.yaml` has a `decision` type
- `ag work "description"` exists but has no catalog touchpoint
- `formalize.sh` can promote TODO items to FEATURES.md entries (bridge path)

---

## Design: Five Components

### A. Universal Capability Catalog

**Core Insight**: FEATURES.md already supports two format levels (heading format for simple, full contract format for formal). The gap is purely in *creation and gating*, not format.

#### A1. Make FEATURES.md available in ALL profiles

**File**: `/workspace/.agentic/lib/init/state-files.conf`
- Change line 15 from `formal` to `all`:
  ```
  .agentic/spec/FEATURES.md:.agentic/lib/templates/FEATURES.template.md:all
  ```

**File**: `/workspace/.agentic/lib/templates/FEATURES.template.md`
- Add a discovery-friendly preamble that explains lightweight usage:
  ```markdown
  # FEATURES
  <!-- spec-format: features-v0.5.0 -->

  **Purpose**: Registry of what this product can do. Every capability gets an entry.

  > **Discovery mode**: Entries are lightweight — name, status (built/planned), one-line description.
  > No F-XXXX IDs required. No YAML contracts required. Just document what exists.
  >
  > **Formal mode**: Full ceremony — F-XXXX IDs, YAML contracts, lifecycle states, enforcement gates.

  ## Quick Reference

  **Discovery entries** (copy/paste):
  ```markdown
  ## CapabilityName

  **Status**: built | planned | exploring
  
  One-line description of what this capability does.
  ```

  **Formal entries** (copy/paste):
  ```markdown
  ## F-####: FeatureName

  **Status**: planned | **Category**: domain
  **Contract**: [`spec/contracts/F-####.yaml`](contracts/F-####.yaml)

  Description of what this feature does.
  ```

  ---

  ## Capabilities

  <!-- Add entries below -->
  ```

This means `FEATURES.md` will be created for ALL profiles during `ag init`. Discovery projects get it as a lightweight capability registry; formal projects get it as the full spec-driven catalog.

#### A2. Adapt feature.sh for discovery mode

**File**: `/workspace/.agentic/lib/tools/feature.sh`

Add a new `add-capability` subcommand that does not require F-XXXX IDs:

```bash
# New subcommand: add-capability (discovery mode, no F-XXXX required)
if [[ "${FIELD}" == "add-capability" ]]; then
  CAP_NAME="${VALUE}"
  CAP_STATUS="${4:-built}"  # built | planned | exploring
  
  # Check if capability already exists (by name heading)
  if grep -qE "^## ${CAP_NAME}$" "${FEATURES_FILE}" 2>/dev/null; then
    echo "Error: Capability '${CAP_NAME}' already exists in FEATURES.md"
    exit 1
  fi
  
  cat >> "${FEATURES_FILE}" << EOF

---

## ${CAP_NAME}

**Status**: ${CAP_STATUS}

(TODO: add description)
EOF
  
  echo "✓ Added capability: ${CAP_NAME} (status: ${CAP_STATUS})"
  exit 0
fi
```

Also add `update-capability` for changing status by name:

```bash
if [[ "${FIELD}" == "update-capability" ]]; then
  CAP_NAME="${FEATURE_ID}"  # reuse first positional as name
  NEW_STATUS="${VALUE}"
  # Use awk to find heading and update Status line
  ...
fi
```

#### A3. Adapt ag commands for discovery mode

**File**: `/workspace/.agentic/lib/tools/commands/operations.sh`

Modify `cmd_work` to prompt for capability catalog update:

```bash
# After WIP tracking starts (line ~56), add:
echo ""
echo -e "${BLUE}Capability check:${NC}"
if [[ -f "$FEATURES_FILE" ]]; then
  echo "  Is this a new capability? Update .agentic/spec/FEATURES.md"
  echo "  Quick add: bash .agentic/lib/tools/feature.sh add-capability \"$description\" built"
fi
```

**File**: `/workspace/.agentic/lib/tools/commands/done.sh`

In the discovery path (lines 207-227, when `feature_tracking=no`), add catalog check:

```bash
# After the existing checklist (line 213), add:
echo "  [ ] FEATURES.md updated (new capability? status change?)"
echo ""
# Advisory check: was FEATURES.md modified this session?
if [[ -f "$FEATURES_FILE" ]]; then
  local features_mtime last_commit_time
  features_mtime=$(stat -c %Y "$FEATURES_FILE" 2>/dev/null || echo "0")
  last_commit_time=$(git log -1 --format=%ct 2>/dev/null || echo "0")
  if [[ "$features_mtime" -lt "$last_commit_time" ]]; then
    echo -e "${YELLOW}Note: FEATURES.md hasn't been updated this session.${NC}"
    echo "  If you built something new, add it: bash .agentic/lib/tools/feature.sh add-capability \"Name\" built"
  fi
fi
```

**New ag command**: `ag cap` (alias for capability operations in discovery mode)

**File**: `/workspace/.agentic/lib/tools/ag.sh` (add to dispatch, around line 233)

```bash
cap|capability)
    shift; cmd_capability "$@"
    ;;
```

**File**: `/workspace/.agentic/lib/tools/commands/operations.sh` (add new function)

```bash
cmd_capability() {
    local subcmd="${1:-list}"
    shift 2>/dev/null || true
    
    case "$subcmd" in
        add)
            local name="${1:-}"
            local status="${2:-built}"
            if [[ -z "$name" ]]; then
                echo "Usage: ag cap add \"Capability Name\" [built|planned|exploring]"
                exit 1
            fi
            bash "$SCRIPT_DIR/feature.sh" add-capability "$name" "$status"
            ;;
        status)
            local name="${1:-}"
            local new_status="${2:-}"
            bash "$SCRIPT_DIR/feature.sh" update-capability "$name" "$new_status"
            ;;
        list)
            if [[ -f "$FEATURES_FILE" ]]; then
                echo -e "${BOLD}=== Capabilities ===${NC}"
                grep -E "^## " "$FEATURES_FILE" | while read -r line; do
                    echo "  $line"
                done
                echo ""
                # Count by status
                local built planned
                built=$(grep -c "Status.*built\|Status.*shipped" "$FEATURES_FILE" 2>/dev/null || echo 0)
                planned=$(grep -c "Status.*planned\|Status.*exploring" "$FEATURES_FILE" 2>/dev/null || echo 0)
                echo "  Built: $built | Planned: $planned"
            else
                echo "No FEATURES.md found. Run: ag init"
            fi
            ;;
        *)
            echo "Usage: ag cap [add|status|list]"
            ;;
    esac
}
```

**Key**: When `feature_tracking=yes`, `ag cap add` auto-assigns an F-XXXX ID (delegates to existing `quick_feature.sh`). When `feature_tracking=no`, it creates a heading-only entry without an ID.

---

### B. Catalog Update Enforcement

**Design principle**: Three enforcement layers, severity varies by profile.

#### B1. Pre-commit check (new check 24)

**File**: `/workspace/.agentic/lib/hooks/pre-commit-check.sh`

Add after check 23 (around line 1370):

```bash
# Check 24: Capability catalog freshness — new implementation files without FEATURES.md update
# Discovery: advisory | Formal (already has check 3c): blocking
echo ""
echo "[24] Checking capability catalog freshness..."

# Detect significant new code (not config, not tests, not docs)
NEW_IMPL=$(git diff --cached --name-only --diff-filter=A 2>/dev/null | \
  grep -E '^(src/|lib/|app/|cmd/|pkg/|internal/|\.agentic/lib/tools/|\.agentic/lib/auto/)' | \
  grep -vE '(test|spec|doc|README|\.md$)' || true)

if [[ -n "$NEW_IMPL" ]]; then
  NEW_FILE_COUNT=$(echo "$NEW_IMPL" | wc -l | tr -d ' ')
  
  # Check if FEATURES.md was also modified
  FEATURES_STAGED=$(git diff --cached --name-only 2>/dev/null | grep "FEATURES.md" || true)
  FEATURES_MODIFIED=false
  if [[ -n "$FEATURES_STAGED" ]]; then
    FEATURES_MODIFIED=true
  elif [[ -f "$FEATURES_FILE" ]]; then
    # Check mtime as fallback
    LAST_COMMIT_TIME=${LAST_COMMIT_TIME:-$(git log -1 --format=%ct 2>/dev/null || echo "")}
    if [[ -n "$LAST_COMMIT_TIME" ]]; then
      if command -v stat >/dev/null 2>&1; then
        if [[ "$(uname)" == "Darwin" ]]; then
          F_MTIME=$(stat -f %m "$FEATURES_FILE" 2>/dev/null || echo "0")
        else
          F_MTIME=$(stat -c %Y "$FEATURES_FILE" 2>/dev/null || echo "0")
        fi
        [[ "$F_MTIME" -gt "$LAST_COMMIT_TIME" ]] && FEATURES_MODIFIED=true
      fi
    fi
  fi
  
  if [[ "$FEATURES_MODIFIED" == "false" && "$NEW_FILE_COUNT" -ge 3 ]]; then
    # Threshold: 3+ new implementation files suggests a new capability
    CATALOG_ENFORCEMENT=$(get_setting "catalog_enforcement" "advisory" 2>/dev/null || echo "advisory")
    
    if [[ "$CATALOG_ENFORCEMENT" == "blocking" ]]; then
      echo "❌ BLOCKED: $NEW_FILE_COUNT new implementation files without FEATURES.md update"
      echo "   New files include: $(echo "$NEW_IMPL" | head -3 | tr '\n' ' ')"
      echo ""
      echo "   Update catalog: bash .agentic/lib/tools/feature.sh add-capability \"Name\" built"
      echo "   Or: ag cap add \"Name\""
      echo ""
      echo "   Skip: SKIP_STALENESS=1 git commit ..."
      FAILURES=$((FAILURES + 1))
    else
      echo "⚠️  WARNING: $NEW_FILE_COUNT new implementation files without FEATURES.md update"
      echo "   If this is a new capability, update the catalog:"
      echo "   ag cap add \"Capability Name\""
    fi
  else
    echo "✓ Catalog check passed"
  fi
else
  echo "✓ No new implementation files (catalog check skipped)"
fi
```

#### B2. ag done enforcement

**File**: `/workspace/.agentic/lib/tools/commands/done.sh`

For both discovery AND formal paths, after existing checks:

```bash
# Catalog freshness check (universal — all profiles)
if [[ -f "$FEATURES_FILE" ]]; then
  local catalog_fresh=false
  # Check if FEATURES.md has been modified since last commit
  if git diff --name-only HEAD 2>/dev/null | grep -q "FEATURES.md"; then
    catalog_fresh=true
  elif command -v stat >/dev/null 2>&1; then
    local f_mtime last_ct
    f_mtime=$(stat -c %Y "$FEATURES_FILE" 2>/dev/null || echo "0")
    last_ct=$(git log -1 --format=%ct 2>/dev/null || echo "0")
    [[ "$f_mtime" -gt "$last_ct" ]] && catalog_fresh=true
  fi
  
  if [[ "$catalog_fresh" == "false" ]]; then
    local enforcement
    enforcement=$(get_setting "catalog_enforcement" "advisory")
    if [[ "$enforcement" == "blocking" ]]; then
      echo -e "${RED}BLOCKED: FEATURES.md not updated. New capabilities must be cataloged.${NC}"
      echo "  Update: ag cap add \"Name\" | bash .agentic/lib/tools/feature.sh add-capability \"Name\" built"
      exit 1
    else
      echo -e "${YELLOW}Note: FEATURES.md wasn't updated. If you built something new, catalog it.${NC}"
      echo "  Quick: ag cap add \"Capability Name\""
    fi
  fi
fi
```

#### B3. New setting: catalog_enforcement

**File**: `/workspace/.agentic/lib/presets/profiles.conf`

Add to each profile:
```
discovery.catalog_enforcement=advisory
formal.catalog_enforcement=advisory
autonomous_formal.catalog_enforcement=blocking
```

**File**: `/workspace/.agentic/lib/tools/commands/settings.sh`

Add `catalog_enforcement` to the known enum settings validation.

**File**: `/workspace/.agentic/lib/settings.sh` `show_all_settings()`

Add `"catalog_enforcement"` to the settings array (line 332).

#### B4. Detection heuristic: new capability vs bug fix

The check uses a threshold: **3+ new implementation files** in recognized source directories triggers the check. This avoids false positives on:
- Bug fixes (typically modify existing files, not add new ones)
- Config changes (filtered by directory pattern)
- Test-only changes (filtered by name pattern)
- Documentation (filtered by extension)

The threshold is configurable via a future setting if needed, but 3 is a reasonable default that catches "I built a new feature" without flagging "I fixed a bug."

---

### C. Discovery Design Doc

**Core Insight**: Discovery mode already has `OVERVIEW.md` with a "Core Capabilities" section. The gap is that this is static and disconnected from FEATURES.md. Rather than creating a new file, we make OVERVIEW.md the "design doc" and connect it to the catalog.

#### C1. Enhance OVERVIEW.md template

**File**: `/workspace/.agentic/lib/init/OVERVIEW.template.md`

Replace the "Core Capabilities" section with a richer version:

```markdown
## Core Capabilities

<!-- Capabilities are tracked in .agentic/spec/FEATURES.md -->
<!-- This section summarizes the product design at a high level -->
<!-- Update: ag cap list | ag cap add "Name" -->

### Built
- <!-- What's working today -->

### Planned
- <!-- What we intend to build -->

## Architecture Decisions

<!-- Key design decisions that shape the product -->
<!-- For formal tracking, use ADRs in .agentic/spec/adr/ -->
- <!-- Decision: rationale -->

## Design Constraints

<!-- Hard constraints on the design (performance, compatibility, etc.) -->
-
```

#### C2. Auto-sync section in dashboard

**File**: `/workspace/.agentic/lib/tools/dashboard.sh`

After the backlog display section, add a capabilities summary:

```bash
# CAPABILITIES summary (universal — all profiles)
if [[ -f "${FEATURES_FILE:-}" ]]; then
  D_CAP_BUILT=$(grep -c "Status.*built\|Status.*shipped" "$FEATURES_FILE" 2>/dev/null || echo 0)
  D_CAP_PLANNED=$(grep -c "Status.*planned\|Status.*exploring" "$FEATURES_FILE" 2>/dev/null || echo 0)
  D_CAP_PROGRESS=$(grep -c "Status.*implementing\|Status.*in.progress" "$FEATURES_FILE" 2>/dev/null || echo 0)
fi
```

And in the output section:

```bash
if [[ -n "${D_CAP_BUILT:-}" ]]; then
  echo "Capabilities: ${D_CAP_BUILT} built, ${D_CAP_PROGRESS} in progress, ${D_CAP_PLANNED} planned"
fi
```

This makes capabilities visible at every session start regardless of profile.

---

### D. Decision Log

**Core Insight**: The cerebrum already has a `decision` type, but it is disconnected from capabilities and not surfaced during implementation. The fix is to extend cerebrum entries to optionally reference capabilities, and to surface decisions during `ag work` / `ag implement`.

#### D1. Extend cerebrum decision entries

**File**: `/workspace/.agentic/lib/tools/commands/intel.sh`

In `_intel_remember()`, add optional `--capability` flag:

```bash
# Add to flag parsing (around line 470):
--capability) shift; capability="${1:-}" ;;
```

And when writing the YAML entry, include the capability reference:

```yaml
  - id: C-XXXX
    type: decision
    text: "We chose X over Y because Z"
    context: "While building user authentication"
    capability: "User Authentication"  # NEW: links to FEATURES.md entry
    created: 2026-04-02T12:00:00Z
```

#### D2. Surface decisions during implementation

**File**: `/workspace/.agentic/lib/tools/commands/operations.sh`

In `cmd_work()`, after starting WIP, query cerebrum for relevant decisions:

```bash
# After WIP tracking (line ~56):
if [[ -f "$INTEL_DIR/cerebrum.yaml" ]]; then
  local decisions
  decisions=$(grep -B1 -A3 "type: decision" "$INTEL_DIR/cerebrum.yaml" 2>/dev/null | grep -A2 "text:" | head -6)
  if [[ -n "$decisions" ]]; then
    echo -e "${DIM}Recent design decisions (ag intel cerebrum --type decision):${NC}"
    echo "$decisions" | head -3 | sed 's/^/  /'
  fi
fi
```

Similarly in `cmd_implement()`, surface decisions tagged with the current feature's capability.

#### D3. New journal flag: --decision

**File**: `/workspace/.agentic/lib/tools/journal.sh`

Add `--decision` flag that both logs to journal AND writes to cerebrum:

```bash
# Add to flag parsing:
DECISION=""
...
--decision) DECISION="$2"; shift 2 ;;
```

```bash
# After journal entry is written:
if [[ -n "$DECISION" ]]; then
  bash "$SCRIPT_DIR/../../lib/tools/ag.sh" intel remember "$DECISION" \
    --type decision --context "Session: ${TOPIC}" 2>/dev/null || true
fi
```

This creates a dual-write: the decision appears in the journal (chronological) AND in cerebrum (queryable).

---

### E. Roadmap / "What We Plan to Build"

**Core Insight**: BACKLOG.json already tracks ordered work. FEATURES.md tracks status. The gap is that discovery mode has no way to see "built vs planned" at a glance, and the STATUS.md roadmap is transient.

#### E1. ag cap list with roadmap view

**File**: `/workspace/.agentic/lib/tools/commands/operations.sh`

In `cmd_capability()`, the `list` subcommand already shows capabilities. Enhance with a roadmap view:

```bash
roadmap)
    if [[ -f "$FEATURES_FILE" ]]; then
        echo -e "${BOLD}=== Product Roadmap ===${NC}"
        echo ""
        echo -e "${GREEN}Built:${NC}"
        grep -B1 "Status.*built\|Status.*shipped" "$FEATURES_FILE" 2>/dev/null | \
          grep "^## " | sed 's/^## /  ✓ /'
        echo ""
        echo -e "${YELLOW}In Progress:${NC}"
        grep -B1 "Status.*implementing\|Status.*in.progress" "$FEATURES_FILE" 2>/dev/null | \
          grep "^## " | sed 's/^## /  → /'
        echo ""
        echo -e "${BLUE}Planned:${NC}"
        grep -B1 "Status.*planned\|Status.*exploring" "$FEATURES_FILE" 2>/dev/null | \
          grep "^## " | sed 's/^## /  ○ /'
        
        # Cross-reference with backlog
        if [[ -f "$BACKLOG_FILE" ]]; then
            echo ""
            echo -e "${DIM}Backlog priority order: ag backlog list${NC}"
        fi
    fi
    ;;
```

#### E2. Dashboard roadmap integration

**File**: `/workspace/.agentic/lib/tools/dashboard.sh`

The capabilities count added in C2 already surfaces at session start. For richer display, add after the backlog section:

```bash
# If no backlog but features exist, show capability summary as fallback navigation
if [[ -z "$bl_display" || "$bl_display" == "[]" ]] && [[ -f "${FEATURES_FILE:-}" ]]; then
  echo ""
  echo -e "${BOLD}Product status:${NC} ${D_CAP_BUILT} built, ${D_CAP_PLANNED} planned"
  echo -e "${DIM}  View: ag cap list | ag cap roadmap${NC}"
fi
```

#### E3. Backlog connects to capabilities

The existing BACKLOG.json already supports `--task "description"` entries (non-feature items). For discovery mode, backlog items can reference capability names:

```json
{
  "type": "task",
  "id": "user-auth",
  "description": "Build user authentication",
  "refs": [".agentic/spec/FEATURES.md"]
}
```

No code changes needed here -- `ag backlog add --task "Build user auth"` already works. The connection is documentation: update the skill files and instructions to mention `ag cap` as the way to track what's built.

---

## Implementation Sequence

### Phase 1: Universal Catalog Foundation (4 files)
1. `state-files.conf` — change FEATURES.md from `formal` to `all`
2. `FEATURES.template.md` — add discovery-friendly format
3. `feature.sh` — add `add-capability` / `update-capability` subcommands
4. `ag.sh` — add `cap` command dispatch

### Phase 2: Discovery Commands (2 files)
5. `commands/operations.sh` — add `cmd_capability()`, enhance `cmd_work()` with catalog prompt
6. `commands/done.sh` — add catalog freshness check to discovery path

### Phase 3: Enforcement (3 files)
7. `pre-commit-check.sh` — add check 24 (catalog freshness)
8. `profiles.conf` — add `catalog_enforcement` setting per profile
9. `settings.sh` — add to `show_all_settings()`; `constraints.conf` — no new constraints needed (catalog_enforcement is independent)

### Phase 4: Intelligence Integration (2 files)
10. `commands/intel.sh` — add `--capability` flag to remember
11. `journal.sh` — add `--decision` flag for dual-write

### Phase 5: Visibility (2 files)
12. `dashboard.sh` — add capabilities summary to session start
13. `OVERVIEW.template.md` — enhance with richer structure

### Phase 6: Documentation & Instructions (4 files)
14. Skill files: `implementing-features/SKILL.md`, `completing-work/SKILL.md`, `writing-specs/SKILL.md` — mention `ag cap`
15. `CLAUDE.md` template (`.agentic/lib/agents/claude/CLAUDE.md`) — add `ag cap` to workflow section
16. `DEVELOPER_GUIDE.md` — document universal catalog
17. `HOW_IT_WORKS.md` — update architecture description

### Phase 7: Tests
18. Shell test for feature.sh add-capability
19. Shell test for pre-commit check 24
20. Python test for dashboard capabilities display
21. Integration test: discovery mode end-to-end with catalog

---

## What This Does NOT Change

- **Formal mode is untouched**: F-XXXX IDs, YAML contracts, state machine, enforcement gates all remain exactly as-is
- **BACKLOG.json format unchanged**: still supports both feature and task types
- **No new files created at project root**: FEATURES.md goes in `.agentic/spec/` where it already lives for formal
- **No new Python dependencies**: all new code is bash (consistent with feature.sh, journal.sh, etc.)
- **No migration needed**: existing formal projects already have FEATURES.md; discovery projects will get it on next `ag upgrade`

## Risk Assessment

1. **Discovery users overwhelmed by ceremony**: Mitigated by making catalog entries truly minimal (name + status + one line). No IDs, no contracts, no lifecycle states required.
2. **False positives on check 24**: Mitigated by 3-file threshold and directory filtering. Advisory-only in discovery mode.
3. **Upgrade path for existing discovery projects**: `ag upgrade` already handles adding new files from `state-files.conf`. Adding FEATURES.md to existing discovery projects will create the file with the template on next upgrade.

## Data Formats

### Discovery FEATURES.md entry
```markdown
## User Authentication

**Status**: built

Users can log in with email/password and receive a JWT token.
```

### Formal FEATURES.md entry (unchanged)
```markdown
## F-042: Universal Capability Catalog

**Status**: planned | **Category**: core-workflow | **Since**: v0.73.0
**Contract**: [`spec/contracts/F-042.yaml`](contracts/F-042.yaml)

FEATURES.md works in all profiles. Discovery entries are lightweight; formal entries have full ceremony.
```

### Cerebrum decision with capability link
```yaml
  - id: C-0015
    type: decision
    text: "JWT tokens over session cookies for auth"
    context: "Designing user authentication"
    capability: "User Authentication"
    created: 2026-04-02T12:00:00Z
```
