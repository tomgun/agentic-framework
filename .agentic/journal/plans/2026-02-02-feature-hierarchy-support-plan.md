# Plan: Feature Hierarchy Support - Add `--children` Query

## Objectives

1. Assess current hierarchy support in the framework
2. Determine if enhancement is needed
3. Clarify feature vs task taxonomy
4. Recommend and implement minimal viable improvement

---

## Current State: Basic Structure Exists

| Capability | Status | How |
|------------|--------|-----|
| **Parent field** | ✅ Works | `- Parent: F-0001` in feature |
| **Dependencies** | ✅ Works | `- Dependencies: F-0002, F-0003` |
| **Visualization** | ✅ Works | `feature_graph.py --hierarchy-only` |
| **Filter by parent** | ✅ Works | `query_features.py --parent=F-0001` |

**Gap**: No way to query "show all children of F-XXXX" with status summary.

---

## Recommendation: Option B (Small Improvement)

Add `--children` query to `query_features.py`:

```bash
# Direct children only (default)
python3 .agentic/tools/query_features.py --children=F-0100

# Output:
F-0101: Login UI [shipped]
F-0102: OAuth Integration [planned]
F-0103: Password Reset [in_progress]

Summary: 3 children (1 shipped, 1 in_progress, 1 planned)
```

```bash
# All descendants (recursive)
python3 .agentic/tools/query_features.py --children=F-0100 --recursive

# Output (indented tree):
F-0101: Login UI [shipped]
  F-0110: Login Form [shipped]
  F-0111: Login Button [shipped]
F-0102: OAuth Integration [planned]
  F-0120: Google OAuth [planned]
  F-0121: GitHub OAuth [planned]
F-0103: Password Reset [in_progress]

Summary: 8 descendants (3 shipped, 1 in_progress, 4 planned)
```

**Scope**: Small change to one file - add argument parsing + filtering logic + recursive traversal.

---

## Acceptance Criteria

- [ ] `query_features.py --children=F-XXXX` returns direct children
- [ ] `--recursive` flag shows all descendants with indented tree format
- [ ] Output includes status summary (X shipped, Y in_progress, Z planned)
- [ ] Recursive mode shows "descendants" count, non-recursive shows "children"
- [ ] Returns graceful message when no children exist
- [ ] Shows error when parent F-ID doesn't exist
- [ ] Works with both flat and hierarchical feature layouts

---

## Edge Cases & Error Handling

| Case | Expected Behavior |
|------|-------------------|
| `--children=F-9999` (non-existent) | Error: "Feature F-9999 not found" |
| Parent exists but has no children | "No children found for F-0100" |
| Invalid format `--children=invalid` | Error: "Invalid feature ID format" |
| Combined with other filters | `--children` + `--status` filters children by status |
| `--recursive` with deep nesting | Handles arbitrary depth, indentation increases per level |
| `--recursive` + `--status` | Filters descendants by status, maintains tree structure |

**Note**: Circular references are already handled by `validate_specs.py` - not in scope here. If circular ref exists, recursive traversal will detect and skip already-visited nodes.

---

## Files to Change

| File | Change |
|------|--------|
| `.agentic/tools/query_features.py` | Add `--children=F-XXXX` flag + filtering logic |
| `.agentic/DEVELOPER_GUIDE.md` | Document `--children` usage in query_features section |

### Not Needed
- New files
- Schema changes
- Changes to feature_graph.py

---

## Tests Required

| Test | Purpose |
|------|---------|
| `test_query_children_returns_direct_children()` | Basic functionality |
| `test_query_children_shows_status_summary()` | Summary output format |
| `test_query_children_empty_when_no_children()` | Graceful empty case |
| `test_query_children_invalid_parent_errors()` | Error handling |
| `test_query_children_combined_with_status_filter()` | Filter combination |
| `test_query_children_recursive_returns_all_descendants()` | Recursive traversal |
| `test_query_children_recursive_shows_indented_tree()` | Tree formatting |
| `test_query_children_recursive_with_status_filter()` | Recursive + filter |

**Test file**: `tests/test_query_features.py` (create if doesn't exist)

---

## Verification (Copy-Paste Ready)

```bash
# 1. Basic functionality - list direct children
python3 .agentic/tools/query_features.py --children=F-0100
# Expected: Lists direct children with statuses + summary line

# 2. Recursive - list all descendants
python3 .agentic/tools/query_features.py --children=F-0100 --recursive
# Expected: Indented tree of all descendants + "X descendants" summary

# 3. No children case
python3 .agentic/tools/query_features.py --children=F-0109
# Expected: "No children found for F-0109"

# 4. Invalid parent (doesn't exist)
python3 .agentic/tools/query_features.py --children=F-9999
# Expected: "Error: Feature F-9999 not found"

# 5. Combined with status filter
python3 .agentic/tools/query_features.py --children=F-0100 --status=shipped
# Expected: Only shipped children shown

# 6. Recursive with status filter
python3 .agentic/tools/query_features.py --children=F-0100 --recursive --status=planned
# Expected: Tree showing only planned descendants

# 7. Run tests
python3 -m pytest tests/test_query_features.py -v

# 8. Validate framework
bash tests/validate_framework.sh
```

---

## Next Steps (After Approval)

1. Implement `--children` flag in `query_features.py`
2. Add tests to `tests/test_query_features.py`
3. Update `.agentic/DEVELOPER_GUIDE.md` documentation
4. Run verification commands above
5. Run `bash tests/validate_framework.sh`

---

## Context: Tasks vs Features (Reference)

| Type | File | When to Use |
|------|------|-------------|
| **Feature** | spec/FEATURES.md | Has acceptance criteria, user-visible |
| **Issue** | spec/ISSUES.md | Bug fix, technical problem |
| **Task** | spec/tasks/T-####.md | One-off internal work, no AC needed |

**Rule**: If it has acceptance criteria → Feature/subfeature. Otherwise → Issue or Task.
