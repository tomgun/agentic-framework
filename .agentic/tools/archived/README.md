# Archived Tools

**Archived**: 2026-02-08 (v0.23.0)
**Reason**: Batch 6 of instruction architecture cleanup — low-value or redundant tools removed from active set.

These tools are preserved for reference but are no longer maintained or documented in DEVELOPER_GUIDE.md.

## Archived Tools

| Tool | Why Archived |
|------|-------------|
| `arch_diff.sh` | Limited use — wraps `git diff` on TECH_SPEC.md. Standard `git diff` suffices. |
| `build-stamper.sh` | Specialized build artifact injection. Rarely used by projects. |
| `bulk_update.py` | Mass-update features in FEATURES.md. Only needed at 500+ features (rare). |
| `consistency.sh` | Redundant shell wrapper — `consistency.py` (still active) does the actual work. |
| `pipeline_list.sh` | Lists sequential agent pipelines. Advanced/optional feature most projects don't use. |
| `search.sh` | Basic keyword search across specs. `grep -r` and IDE search are better alternatives. |

## Restoring a Tool

If you need one of these tools:

1. Copy it back to `.agentic/tools/`
2. Re-add documentation to `DEVELOPER_GUIDE.md`
3. Update `list-tools.sh`
