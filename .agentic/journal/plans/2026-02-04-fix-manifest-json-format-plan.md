# Plan: Fix manifest.sh JSON Format Mismatch

## Problem

**Critical bug discovered by code review:**

- `drift.sh --docs --manifest F-XXXX` expects: `.agentic-state/manifests/F-XXXX.json`
- `manifest.sh` outputs: `.agentic-state/manifests/F-XXXX.manifest.md` (Markdown)

This breaks the drift.sh ↔ manifest.sh integration.

## Evidence

```bash
# drift.sh expects JSON:
local manifest_file="$manifest_dir/${MANIFEST_FEATURE}.json"
grep -oE '"file":\s*"[^"]+"' "$manifest_file"  # Parses JSON

# manifest.sh outputs Markdown:
OUTPUT_FILE="$MANIFEST_DIR/${VALUE}.manifest.md"
```

## Fix Strategy

**Change manifest.sh to output JSON (matching acceptance criteria)**

The acceptance criteria says "Generates JSON format" - the implementation should match.

---

## Changes Required

### 1. manifest.sh - Output JSON format

**File:** `.agentic/tools/manifest.sh`

Change output from Markdown tables to JSON:

```json
{
  "feature": "F-0117",
  "generated": "2026-02-04T19:30:00Z",
  "commits": [
    {"hash": "abc123", "message": "feat: Add migration.sh", "date": "2026-02-04"}
  ],
  "files": {
    "code": ["src/foo.ts", "src/bar.ts"],
    "tests": ["tests/foo.test.ts"],
    "docs": ["docs/api.md"],
    "config": ["package.json"]
  },
  "stats": {
    "total_files": 4,
    "additions": 150,
    "deletions": 20
  }
}
```

**Key changes:**
- Replace Markdown table generation with JSON output
- Change file extension from `.manifest.md` to `.json`
- Add `--markdown` flag for human-readable output (optional)

### 2. drift.sh - Already correct

drift.sh already expects `.json` format - no changes needed.

### 3. Update acceptance criteria (if needed)

F-0119 acceptance criteria already says "Generates JSON format" - this is correct.

---

## File Changes

| File | Action |
|------|--------|
| `.agentic/tools/manifest.sh` | **MODIFY** - Output JSON instead of Markdown |

---

## Verification

```bash
# Generate manifest
bash .agentic/tools/manifest.sh F-0117

# Check output is JSON
cat .agentic-state/manifests/F-0117.json | jq .

# Verify drift.sh integration works
bash .agentic/tools/drift.sh --docs --manifest F-0117
```

---

## Notes

- F-0117, F-0118, F-0119 are already implemented and shipped
- This is a bug fix, not new feature implementation
- The someclaudeskills comparison was valid - their approach (static ownership) complements ours (dynamic history)
