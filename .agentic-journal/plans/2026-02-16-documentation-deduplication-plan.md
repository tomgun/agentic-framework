# Plan: Documentation Deduplication

## Context

Framework has 9 user/agent-facing docs that grew organically. Content was copied to whichever file was being edited, creating ~20% duplication. The F-0136 routing table work exposed the pattern: we added the same table to 9 files because there's no ownership model. When content drifts, developers get stale info and agents behave inconsistently.

The F-0134 DEVELOPER_GUIDE rewrite made it comprehensive (2147 lines), which rendered USER_WORKFLOWS.md largely redundant — the same feature templates, spec editing guidance, TDD workflow, troubleshooting, and best practices now exist in both files.

**Goal**: Each piece of content lives in ONE canonical file. Other docs cross-reference. No more triple-maintained command tables or duplicated troubleshooting sections.

## Document Ownership Model

| Document | Role | Canonical for |
|----------|------|---------------|
| `START_HERE.md` | Navigation hub — "I need X, go here" | Routing to other docs, "What Files Mean" |
| `DEVELOPER_GUIDE.md` | Comprehensive reference | Setup, workflows, scripts, customization, troubleshooting, best practices |
| `MANUAL_OPERATIONS.md` | Token-free quick commands | grep/cat patterns, dashboard, "look vs ask" |
| `README.md` | Framework overview & philosophy | Profiles, design principles, "what you get" |
| `USER_WORKFLOWS.md` | Redirect → DEVELOPER_GUIDE | *(being retired)* |

## Changes

### 1. Retire USER_WORKFLOWS.md → redirect to DEVELOPER_GUIDE

**Problem**: USER_WORKFLOWS.md (547 lines) was written before F-0134 made DEVELOPER_GUIDE comprehensive. Now it's a Formal-mode subset with heavy overlap:
- "Adding a New Feature" (lines 50-127) ≈ DEVELOPER_GUIDE "Editing Specs Directly → Add a Feature" (lines 453-513) — same template, same acceptance criteria, same prompts
- "Direct Spec Editing" (lines 188-225) ≈ DEVELOPER_GUIDE "Editing Specs Directly"
- "TDD workflow" (lines 307-351) ≈ DEVELOPER_GUIDE "Daily Workflows" + START_HERE "Framework Overview"
- "Sequential Agent Pipeline" (lines 354-417) ≈ DEVELOPER_GUIDE "Advanced Topics"
- "Troubleshooting" (lines 505-531) ≈ DEVELOPER_GUIDE "Troubleshooting"
- "Best Practices" (lines 468-501) ≈ DEVELOPER_GUIDE "Best Practices"

**Unique content** worth saving (move to DEVELOPER_GUIDE before retiring):
- "Accepting a Feature" section (lines 269-303) — not in DEVELOPER_GUIDE
- "Common Questions" FAQ (lines 440-464) — practical Q&A format not elsewhere

**Fix**:
1. Add "Accepting a Feature" subsection to DEVELOPER_GUIDE §Daily Workflows (after "Evening: Wrap Up")
2. Add "Common Questions" to DEVELOPER_GUIDE §Troubleshooting (as a FAQ subsection)
3. Replace USER_WORKFLOWS.md content with a redirect:

```markdown
# User Workflows Guide

This guide has been consolidated into **[`DEVELOPER_GUIDE.md`](DEVELOPER_GUIDE.md)**.

Key sections:
- Adding features: [`DEVELOPER_GUIDE.md#editing-specs-directly`](DEVELOPER_GUIDE.md#editing-specs-directly)
- Accepting features: [`DEVELOPER_GUIDE.md#accepting-a-feature`](DEVELOPER_GUIDE.md#accepting-a-feature)
- TDD workflow: [`DEVELOPER_GUIDE.md#daily-workflows`](DEVELOPER_GUIDE.md#daily-workflows)
- Troubleshooting: [`DEVELOPER_GUIDE.md#troubleshooting`](DEVELOPER_GUIDE.md#troubleshooting)
```

4. Update references in README.md (line 218) and START_HERE.md (line 121)

### 2. DEVELOPER_GUIDE.md — remove Manual Ops duplication

**Problem**: Lines 425-451 ("Quick Information Retrieval") and 559-581 ("Finding Information") duplicate MANUAL_OPERATIONS.md. The file even cross-refs MANUAL_OPERATIONS at line 418 then repeats the content.

**Fix**: Replace both subsections with a single cross-reference. Keep "Editing Specs Directly" (lines 453-557) — unique to DEVELOPER_GUIDE.

Before (§Manual Operations, ~175 lines):
```
### Philosophy ...
### Quick Information Retrieval     ← REMOVE (in MANUAL_OPERATIONS)
### Editing Specs Directly           ← KEEP
### Finding Information              ← REMOVE (in MANUAL_OPERATIONS)
```

After (~130 lines):
```
## Manual Operations

**📖 Quick commands for token-free operations**: [`MANUAL_OPERATIONS.md`](MANUAL_OPERATIONS.md)
— status checks, context gathering, finding information, dashboard script.

### Editing Specs Directly
[keep existing ~100 lines unchanged]
```

### 3. START_HERE.md — slim Common Issues + Quick Command Reference

**Problem**: "Common Issues" (lines 344-374) is a condensed copy of DEVELOPER_GUIDE §Troubleshooting. "Quick Command Reference" (lines 383-405) already cross-refs DEVELOPER_GUIDE but still repeats 15 commands.

**Fix Common Issues** — keep as concise table + link:
```
## Common Issues

| Problem | Quick fix |
|---------|-----------|
| Agent keeps re-reading everything | Update `CONTEXT_PACK.md` with structure summaries |
| Lost track of what we're building | Read `STATUS.md` and `spec/OVERVIEW.md` |
| Agent context reset mid-task | Check `STATUS.md` "Current session state" |

**More issues & detailed solutions**: [`DEVELOPER_GUIDE.md#troubleshooting`](DEVELOPER_GUIDE.md#troubleshooting)
```

**Fix Quick Command Reference** — remove command block, keep cross-refs only:
```
## Quick Command Reference

See [`DEVELOPER_GUIDE.md#quick-reference`](DEVELOPER_GUIDE.md#quick-reference) for the full command table.
See [`MANUAL_OPERATIONS.md`](MANUAL_OPERATIONS.md) for token-free operations.
```

### 4. README.md — slim Tools + Troubleshooting + stale versions

**Problem**: "Tools and automation" (lines 263-306, 43 lines) lists every script — all documented in DEVELOPER_GUIDE. "Troubleshooting" (lines 308-322) repeats DEVELOPER_GUIDE. Version numbers hardcoded as `v0.19.0` in 3 places (stale — framework is at 0.28.0).

**Fix Tools** — compress to categories + link:
```
## Tools and automation

30+ scripts in `.agentic/tools/`. Key categories:
- **Health**: `doctor.sh`, `report.sh`, `verify.sh`
- **Traceability**: `ag trace`, `coverage.sh`, `drift.sh`
- **Analysis**: `feature_graph.sh`, `stale.sh`, `deps.sh`

Run `ag tools` or see [`DEVELOPER_GUIDE.md#automation--scripts`](DEVELOPER_GUIDE.md#automation--scripts) for full documentation.
```

**Fix Troubleshooting** — pointer only:
```
## Troubleshooting

See [`DEVELOPER_GUIDE.md#troubleshooting`](DEVELOPER_GUIDE.md#troubleshooting) for common issues.
Quick navigation: [`START_HERE.md`](START_HERE.md) | Visual overview: [`FRAMEWORK_MAP.md`](FRAMEWORK_MAP.md)
```

**Fix versions** — replace hardcoded `0.19.0` with `<VERSION>` placeholder (3 occurrences).

### 5. MANUAL_OPERATIONS.md — slim script list

**Problem**: Lines 83-116 list 12 scripts with examples, then immediately says "See DEVELOPER_GUIDE.md for detailed documentation." The list itself is the duplication.

**Fix** — keep the 3 most-used scripts, link for rest:
```
## Automated Health Checks

```bash
bash .agentic/tools/doctor.sh       # Check project structure
bash .agentic/tools/doctor.sh --full # Comprehensive verification
bash .agentic/tools/report.sh       # Feature status summary
```

**📖 Full script documentation (30+ scripts)**: [`DEVELOPER_GUIDE.md#automation--scripts`](DEVELOPER_GUIDE.md#automation--scripts)
```

## Files Summary

| File | Change | Net lines |
|------|--------|-----------|
| `.agentic/workflows/USER_WORKFLOWS.md` | Replace with redirect (move unique content first) | -535 |
| `.agentic/DEVELOPER_GUIDE.md` | Remove QIR + FI subsections, add Accepting + FAQ from USER_WORKFLOWS | ~+40 net |
| `.agentic/START_HERE.md` | Slim Common Issues + Quick Command Reference, update USER_WORKFLOWS ref | -30 |
| `.agentic/README.md` | Slim Tools + Troubleshooting, fix stale versions, update USER_WORKFLOWS ref | -40 |
| `.agentic/MANUAL_OPERATIONS.md` | Slim script list to top 3 + cross-ref | -20 |

5 files modified. ~585 lines of duplication removed. Single commit.

**Not doing** (reviewer feedback incorporated):
- Document Roles markers — noise, doesn't prevent duplication
- S10 structural test for markers — over-engineering
- Splitting DEVELOPER_GUIDE into multiple files — creates MORE cross-refs to maintain; it's a comprehensive reference, long is fine

## Verification

1. `bash tests/validate_framework.sh` — all pass (F-0061 check: DEVELOPER_GUIDE exists + is comprehensive)
2. `bash tests/infrastructure/structural/S09_routing_rule_consistency.sh` — 18/18 (routing tables untouched)
3. Grep for broken links: `grep -r "USER_WORKFLOWS" .agentic/` — all updated to DEVELOPER_GUIDE
4. Grep for stale versions: `grep -r "0\.19\.0" .agentic/README.md` — zero hits
5. No identical bash command blocks across DEVELOPER_GUIDE + MANUAL_OPERATIONS + START_HERE
